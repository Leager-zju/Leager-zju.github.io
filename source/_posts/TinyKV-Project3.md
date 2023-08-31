---
title: TinyKV-Project3
author: Leager
mathjax: true
date: 2023-08-20 23:37:12
summary:
categories:
  - TinyKV
tags:
  - lab
img:
---

## 思路

### Part A Leadership/Membership Change in Raft

需要修改的代码位于 `raft/raft.go`。

在 3A 中我们仅需修改 Raft 层的逻辑，而完整的 Change 流程将在 3B 中实现。

#### 1 Leadership Change

Raft 层首先会 `Step` 一条 `MsgTransferLeader`。由于任何节点都有可能收到该消息，故需根据身份分类讨论：

**Non-Leader**：
- 如果迁移目标 `transferee` 是自己，则直接触发 `MsgTimeoutNow`，尝试成为 `Leader`;

**Leader**：
- 如果迁移目标 `transferee` 是自己，则什么也不干（已经是 `Leader` 无需迁移）;
- 反之
  1. 需检查其是否有资格上任（即日志是否和自己一样新）;
  2. 如果 `transferee` 的日志不是最新的，则 `Leader` 应该向其发送 `MsgAppend`（并停止进行任何之后的 `Propose`）直到其符合条件——这需要在后续的 `HandleAppendEntriesResponse()` 中进行判断;
  3. 一旦满足迁移条件，`Leader` 应该立即向其发送一条`MsgTimeoutNow`，`transferee` 在收到消息后立即开始新的选举——即 `Step(MsgHup)`——从而依靠最新的 `Term` 和 `LastLog` 当选领导人;

#### 2 Membership Change

这里我们仅需修改 `Raft.addNode()` 与 `Raft.removeNode()`。

节点的增减其实就是对 `Raft.Prs` 哈希表的修改：
- 如果待增加节点未出现在 `RaftGroup` 中，则新增一个条目;
- 如果待删除节点出现在 `RaftGroup` 中，则删除一个条目;

对节点的增删会导致“大多数”发送变化：若节点增加，则新节点等待 `AppendEntries` 即可。若节点减少，则需要重新更新 `committed` 并发送;

### Part B Implement Admin Commands

3B 中我们就要正式实现加上**域分裂**(Region Split)在内的所有 Admin Commands 了。需要实现的代码位于 `kv/raftstore/peer_msg_handler.go` 与 `kv/raftstore/peer.go` 中。

#### 1 TransferLeader

因为领导迁移仅仅是一个操作，无需所有节点进行复制，所以收到该类型的 `AdminRequest` 时，直接调用 `RawNode.TransferLeader()` 即可。

#### 2 ChangePeer

一次完整的节点增删流程如下

1. 上层收到命令，向下 push 一条 `ChangePeer` 类型的 `AdminRequest`;
2. `handler` 优先检测是否为该类型的命令，若是，则调用 `RawNode.ProposeConfChange()` 给 `Leader` Propose 一条 `EntryConfChange` **特殊类型**日志;
3. `Leader` apply 这条**特殊类型**的命令时：
   - 修改 `RegionLocalState`，包括 `RegionEpoch` 与 `Peers`;
   - 调用 `rawnode.ApplyConfChange()`，然后根据命令类型进行 `Raft` 层的节点变动;

> 值得一提的是，同一时间只能存在至多一个未被 apply 的 `EntryConfChange` 日志，这一点是通过变量 `Raft.PendingConfIndex` 实现的，即，如果上层要求 propose 一条该类型日志，而上一条 `EntryConfChange` 日志未被 apply（表现为 `Raft.PendingConfIndex < Raft.RaftLog.applied`），就放弃该日志的 propose。
>
> ```go
> switch req.CmdType {
>   ...
>   case raft_cmdpb.AdminCmdType_ChangePeer:
> 	  if d.peer.RaftGroup.Raft.PendingConfIndex <= d.peer.RaftGroup.Raft.RaftLog.Applied() {
> 			d.peer.RaftGroup.ProposeConfChange(eraftpb.ConfChange{...})
> 		}
>   ...
> }
> 
> ```
>
> 并且由于 `RaftGroup` 随时可能变化，故对于不在组内的节点而言，任何消息都是无效的——即便收到消息，也不能做任何事。


### Part C Scheduler

需要修改的代码位于 `scheduler/server/cluster.go` 与 `scheduler/server/schedulers/balance_region.go`，分别需要实现 `processRegionHeartbeat()` 函数与 `Schedule()` 函数。总体来讲比 3B 简单许多，根据任务书一步步来即可，仅有少量小bug需要根据测试的打印结果来调整。

#### 1 Collect region heartbeat

根据 3B 中描述的整体系统流程，每个集群 `Cluster` 所持有的总调度器 `Scheduler` 会根据 `Region` 发来的心跳信息为其分配任务（`ConfChange`, `RegionSplit` 等）。在真实网络下，心跳信息会以不可预知的速度到达 `Scheduler`，同时也可能因为网络分区而收到来自同个 `Region` 不同 Leader 的信息——这就需要我们记录下每个 `Region` 的重要信息（用 `RegionInfo` 这个数据结构来表示），以防收到 stale heartbeat。

先来介绍一下整体流程，其实和 3B 中的 Mock 差不多：

首先，`Region` 的 Leader 发送心跳，`Server` 通过 `RegionHeartbeat()` 不断收取心跳信息，并从中提取出发送方的 `RegionInfo`，然后下放到 `Cluster`，通过 `HandleRegionHeartbeat()` 根据当前 `RegionInfo` 进行处理：

```go
func (s *Server) RegionHeartbeat(stream schedulerpb.Scheduler_RegionHeartbeatServer) error {
	for {
    ...
		request, err := server.Recv()
    ...
		region := core.RegionFromHeartbeat(request)
    ...
		err = cluster.HandleRegionHeartbeat(region)
    ...
	}
}
```

在处理的过程中，`Cluster` 首先调用 `processRegionHeartbeat()` 更新信息，若成功且该 `Region` 拥有至少一个 `Peer`，就调用 `Dispatch(Heartbeat)` 检查是否有对该 `Region` 待执行的命令 `Operator`：

```go
func (c *RaftCluster) HandleRegionHeartbeat(region *core.RegionInfo) error {
	if err := c.processRegionHeartbeat(region); err != nil {
		return err
	}

	c.RLock()
	co := c.coordinator
	c.RUnlock()
	co.opController.Dispatch(region, schedule.DispatchFromHeartBeat)
	return nil
}
```

对于该 `Operator`：

1. 如果尚未执行完毕（每个 `Operator` 集成了多个步骤 `OpStep`，可能只执行到中间的某一步）且未超时，检查该 `Region` 的 `ConfVersion` 是否完全由该 `Operator` 修改：若是，则调用 `SendScheduleCommand()` 执行下一步命令——发送相应 `RegionHeartbeatResponse`，当 `Region` 收到后便会 propose 相应命令；反之，说明该 `Operator` 已过时，将其移除，并将状态设置为 `OperatorStatus_CANCEL`;
2. 如果已执行完毕，将其移除，并将状态设置为 `OperatorStatus_SUCCESS`;
3. 如果超时，将其移除，并将状态设置为 `OperatorStatus_TIMEOUT`;

```go
func (oc *OperatorController) Dispatch(region *core.RegionInfo, source string) {
	if op := oc.GetOperator(region.GetID()); op != nil {
		timeout := op.IsTimeout()
		if step := op.Check(region); step != nil && !timeout {
			origin := op.RegionEpoch()
			latest := region.GetRegionEpoch()
			changes := latest.GetConfVer() - origin.GetConfVer()
			if source == DispatchFromHeartBeat &&
				changes > uint64(op.ConfVerChanged(region)) {
				if oc.RemoveOperator(op) {
					oc.opRecords.Put(op, schedulerpb.OperatorStatus_CANCEL)
				}
				return
			}
			oc.SendScheduleCommand(region, step, source)
			return
		}
		if op.IsFinish() && oc.RemoveOperator(op) {
			oc.opRecords.Put(op, schedulerpb.OperatorStatus_SUCCESS)
		} else if timeout && oc.RemoveOperator(op) {
			oc.opRecords.Put(op, schedulerpb.OperatorStatus_TIMEOUT)
		}
	}
}
```

我们只需要实现函数 `processRegionHeartbeat()`。

首先检查该 `RegionInfo` 的可信度：

1. 如果在已有的表中记录过同一 `RegionId` 的 info，并且新 info 的 `RegionEpoch` 中的两个字段 `ConfVersion`, `Version` 只要有一个比已有的小，就认为不可信，返回 `ErrRegionIsState`;
2. 如果存在那些与新 info 对应的 Key 区间有重合的 info（这种情况发生于 Region Split 操作），并且新 info 的 `RegionEpoch` 中的两个字段 `ConfVersion`, `Version` 只要有一个比已有的小，就认为不可信，返回 `ErrRegionIsState`;

检查通过后，调用 `putRegion()` 将该 info 插入表中，并删除原有 info（如果有的话）。

最后，调用 `updateStoreStatusLocked()` 更新集群中所有存储节点状态。

此处没有什么疑难杂症，很快就能完成。

#### 2 Implement region balance scheduler

上面提到的 `Operator` 是怎么来的呢？有一部分就是 `Scheduler` 产生的。

`Cluster` 一经创建便持有一个 `Coordinator`，其会通过 `runScheduler()` 来调用 `scheduler.Schedule()`，定期检查是否有存储节点超载，就需要找到该节点的一个**合适**的 `Region`，将位于该节点的 `Peer` 转移到某个**合适**的节点，从而达成负载均衡，并通过函数返回的 `MovePeerOperator` 加到该 `Region` 对应的“待执行命令”中，等待下一次该 `Region` 发来心跳信息时执行。 

> 一个 `MovePeerOperator` 包含三个步骤：删除原节点的 `Peer`（即 `RemovePeer` 操作），在新节点分配一个位置容纳新 `Peer`，创建新 `Peer`（即 `AddPeer` 操作）。最后等待该新 `Peer` 收到消息正式加入 Group。
>
> 其实都是 3B 中实现好了的。

上文提到**合适**，那么究竟何谓**合适**？

对于迁出节点而言，首先寻找 Pending Region，即新加入的 Peer 所在的 Region

首先我们需根据 Region Size 对所有 **Suitable** 的存储节点降序排列。

> 任务书指出：In short, a suitable store should be up and the down time cannot be longer than `MaxStoreDownTime` of the cluster, which you can get through `cluster.GetMaxStoreDownTime()`.