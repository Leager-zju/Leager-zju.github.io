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

**Non-Leader**：将消息转发给 Leader;

**Leader**：如果迁移目标 `transferee` 是自己，则什么也不干（已经是 Leader 无需迁移）；反之：
1. 检查其是否有资格上任（即日志是否和自己一样新）;
2. 如果 `transferee` 的日志不是最新的，则 Leader 应该向其发送 `MsgAppend`（并停止进行任何之后的 `Propose`）直到其符合条件——这需要在后续的 `HandleAppendEntriesResponse()` 中进行判断;
3. 一旦满足迁移条件，Leader 应该立即向其发送一条`MsgTimeoutNow`，`transferee` 在收到消息后立即开始新的选举——即 `Step(MsgHup)`——从而依靠最新的 `Term` 和 `LastLog` 当选领导人;
4. 如果 `transferee` 的日志不是最新的，则 Leader 应该向其发送 `MsgAppend`（并停止进行任何之后的 `Propose`）直到其符合条件——这需要在后续的 `HandleAppendEntriesResponse()` 中进行判断;
5. 一旦满足迁移条件，Leader 应该立即向其发送一条`MsgTimeoutNow`，`transferee` 在收到消息后立即开始新的选举——即 `Step(MsgHup)`——从而依靠最新的 `Term` 和 `LastLog` 当选领导人;

#### 2 Membership Change

这里我们仅需修改 `Raft.addNode()` 与 `Raft.removeNode()`。

节点的增减其实就是对 `Raft.Prs` 哈希表的修改：
- 如果待增加节点未出现在 `RaftGroup` 中，则新增一个条目;
- 如果待删除节点出现在 `RaftGroup` 中，则删除一个条目;

对节点的增删会导致“大多数”发送变化：若节点增加，则新节点等待 `AppendEntries` 即可。若节点减少，则需要重新更新 `committed` 并发送;

### Part B Implement Admin Commands

3B 中我们就要正式实现加上**域分裂**(Region Split)在内的所有 Admin Commands 了。需要实现的代码位于 `kv/Raftstore/peer_msg_handler.go` 与 `kv/Raftstore/peer.go` 中。

写 3B 之前我们需要粗略回顾一下整个系统的构成。

在我们之前实现的 Raft 算法中，所有 `Peer` 位于不同存储节点上，对于一个分布式系统而言，这样能保证一个节点挂掉的同时依旧能依靠剩下的节点来提供服务。而在所有节点构成的图中，并非所有节点都两两连通，那么就需要根据不同的连通分量进行划分，这个划分单位就是 `Cluster`。

一个 `Cluster` 中包含了多个存储节点 `Raftstore`，每个 `Raftstore` 存储大量 KV 对，如果只用一个 Raft Group 对其进行管理，则消耗的资源太大——生成一个 Snapshot 可能就会把整个系统搞慢，于是开发者很聪明，将这些 KV 对根据哈希算法划分为不同区间，每个区间各由一个 Raft Group 来管理，这就是 `Region`。可以认为一个 `Region` 本质上就是一个 Raft Group + [StartKey, EndKey)。

当 `Client` 针对某个 Key 进行增删改查操作时，会将该命令发给 `Cluster`。`Cluster` 手上掌握着管辖范围内所有 `Raftstore` 的信息以及所有 `Region` 的信息，保存在一个叫 `Scheduler` 的结构中。有了这些信息，`Cluster` 就可以根据 Key 找到是哪个 `Region` 存着，进一步找到该 `Region` 中 Leader 所在的存储节点，向该节点发送命令，命令除了一些关于操作的信息，命令头 `Header` 中还存有目标 `Region` 的相关信息作为校验码，如 `RegionId`, `RegionEpoch` 以便进行校对。

此外，`Cluster` 还承担自我修正的功能，即 `Cluster` 会通过 `RegionHeartbeat()` 函数不断接收所有 `Region` 发来的**心跳信息**（区别于 Raft 层 Heartbeat），这些心跳信息包含 `Region` 的当前信息，包括 `RegionEpoch`, Leader 等，`Cluster` 根据这些信息决定是否向对应的 `Region` 做出一些调整措施。

> 在 MockClient 里，测试用例做出的操作会被缓存，等到下次 `RegionHeartbeat()` 时，判断对应 `Region` 是否有未执行完毕的操作，如果有，则在 Response 中告知。
>
> ```go
> func (r *SchedulerTaskHandler) Handle(t worker.Task) {
> 	switch task := t.(type) {
> 	...
> 	case *SchedulerRegionHeartbeatTask:
> 		r.onHeartbeat(task) // 调用 RegionHeartbeat
> 	...
> 	}
> }
> 
> func (m *MockSchedulerClient) RegionHeartbeat(req *schedulerpb.RegionHeartbeatRequest) error {
>   // check if BootStrap
>
>   // update pending peers and leader of region
>
>   // check region epoch
>
>   resp := makeResp(req)
>   if op := m.operators[regionID]; op != nil {
>  	  if m.tryFinished(op, req.Region, req.Leader) {
>   		delete(m.operators, regionID)
>   	} else {
>   		m.makeRegionHeartbeatResponse(op, resp)
>   	}
>   }
> 
>   // send response to store where the leader is located
>   return nil
> }
> ```
>
> 而在 3C 中则要实现真实的 Scheduler。

以 Mock 版本为例，每个 `Peer` 都有一个 `PeerMsgHandler`，用于接收从 `Cluster` 发来的消息，见 `HandleMsg()`。在 Part B 中，我们主要谈以下 3 个 Admin Commands。

这 3 种 Commands 所位于的 Message Type 均为 `MsgTypeRaftCmd`，那么首先会来到 `proposeRaftCommand()` 函数中。

#### 1 Propose transfer leader

因为领导迁移仅仅是一个操作，无需所有节点进行复制，所以收到该类型的 Command 时，直接调用 `RawNode.TransferLeader()` 即可。

#### 2 Implement conf change in Raftstore

一次完整的 conf change 流程如下

1. 调用 `RawNode.ProposeConfChange()` 给 Leader Propose 一条 `EntryConfChange` 的**特殊类型**日志;
2. apply 到这条命令时，首先检查该命令是否有效，即 `RegionId` 与 `RegionEpoch` 是否匹配，若不匹配，说明在收到消息之前已经进行过 Peer Change 或 Region Split，返回一个 `error`;
3. 令当前 `RegionEpoch` 中的 `confVersion` 字段自增 `1`;
4. 根据 `ChangeType` 执行新 `Peer` 的添加 or 已有 `Peer` 的删除，表现为：修改 `Region` 中的 `Peers`，以及调用 `insertPeerCache()`/`removePeerCache()`;
> 注意，如果删除自身节点，则要执行 `destroyPeer()`，会删除包括 `RegionRanges` 在内的诸多字段，故后续步骤无需再管，直接 return 即可，此时完成当前 entry apply 后应直接退出，不能将数据写到 badger 里。
>
> 如果待添加的 `Peer` 已在 Group 中则啥也不做，同理，如果待删除的 `Peer` 不在了也啥也不做，而不是返回 `error`。
1. 更新 `storeMeta`，注意这是个临界变量，在真实并发场景下对其的修改需要**加锁**;
2. 调用 `rawnode.ApplyConfChange()`，然后根据命令类型进行 `Raft` 层的节点变动;
3. 如果当前节点在 `Raft` 层是 Leader 的身份，则需要返回 Response，并且给 `Scheduler` 发一则心跳信息，表示该操作已完成;

接下来我们不禁心生疑惑：**对于 `AddPeer` 而言，新加入的 `Peer` 所在 `Raftstore` 是怎么知道他需要创建一个 `Peer`？这个 `Peer` 又是怎么知道他在哪个 `Region` 中的呢？`Region` 中原来的那些 `Peer` 是怎么知道新的 `Peer` 已经加入了呢？**

首先要了解的是，测试代码里所使用的只是模拟的 `Cluster`，不妨称它为 `MockCluster`（当然代码里面它就叫 `Cluster`，在文件 `kv/test_raftstore/cluster.go` 中）。

这个 `MockCluster` 持有一个 `NodeSimulator` 来模拟大型分布式集群的节点间通信，以及 C/S 之间的通信。所有的测试用操作，包括 `MustPut()`/`MustGet()`/`MustDelete()` 等都会一步步通过 `MockCluster.CallCommandOnLeader()` 到 `MockCluster.CallCommand()` 再到 `NodeSimulator.CallCommandOnStore()`，最后通过目标 `Raftstore` 对应的 `RaftstoreRouter` 的结构进行发送。

之前 `HandleRaftReady()` 时调用 `send()` 函数将 `Ready` 中的 Msgs 发出去，本质上就是通过 `RaftstoreRouter.SendRaftMessage()` 执行发送操作。

> 因为这里都是在本地模拟，所以不用考虑远程调用、网络流之类的问题。

`SendRaftMessage()` 函数做的事其实很简单——先调用 `send()` 发 `MsgTypeRaftMessage` 类型的消息（通过 `peerSender` 这个管道进行传递），如果出现错误，再调用 `sendStore()` 发 `MsgTypeStoreRaftMessage` 类型的消息（通过 `storeSender` 这个管道进行传递）。

消息进了这两个管道，最后会从哪里被接受呢？

首先，`RaftstoreRouter` 会在 `Raftstore` 生成时一并创建，见函数 `CreateRaftstore()`。本质上一个 `Raftstore` 内所有部分都共享同一个 `router`，无论是 `Raftstore.router` 还是 `ctx.router`，都指向同一个数据结构。下面都叫它 `router` 了。

每个 `Raftstore` 在启动时都会调用 `startWorkers()`，然后启动 `raftWorker` 和 `storeWorker` 这俩 GoRoutine，它们均接收从 `router` 中传来的消息，前者用的是 `router.peerSender` 这个管道，后者从 `router.storeSender` 这个管道取消息。问题得到了解答。

同时我们也发现，在 `send()` 函数中，如果发现当前 `Raftstore` 并没有目标 `Region` 存在，则返回一个 `error`，消息也会直接送到 `storeWorker` 手上。`storeWorker` 拿到后发现是一条 `MsgTypeStoreRaftMessage`，便调用 `onRaftMessage()` 进行后续处理。走到这里，我们又有新发现了，那就是任务书中也提到了的 `maybeCreatePeer()` 函数，其注释是这么写的：*If target peer doesn't exist, create it.*

> 这里新建 `Peer` 的操作我们也应认真看看，包括：修改 `StoreMeta`，调用 `router.register()` 进行**注册**，以及发送一条 `MsgTypeStart` 消息**唤醒**其启动 `ticker` 正式开始工作。

再来看之前的疑惑，第一个问题其实得到解答了：随着上述步骤 4, 6 的执行，新 `Peer` 的信息已经加载到 `PeerCache` 中了，Raft 层也将新的 `Peer` 加载到 `Prs` 表中。当 Leader 下一次群发 heartbeat 或 append 时，会给新 `Peer` 也发一份 RaftMessage，目标 `Raftstore` 收到后发现没有目标 `Region` 存在，也就开始了后续的创建操作。

对于第二个问题，在创建 `Peer` 之前，`Raftstore`收到的消息就含有 `Region` 相关信息。

第三个问题，Follwers/Candidates 在 apply conf change 时仅仅是将其加到了 `Prs` 中，如果网络一切良好，其实不用做出任何操作。而 Leader 不一样，在添加 `Prs` 时，`Match`/`Next` 字段其实都应该赋 **0**——因为该 `Peer` 尚未初始化——这样一来，一旦发送 append 消息中遍历到新 `Peer` 时，发现其 `Next=0`，无论如何都会小于 `truncatedIndex`，Leader 会立刻发送 snapshot 过去。由于是通过 `replicatePeer()` 的方式进行创建，我们会发现这种方式创建的 `Peer`，其 Raft 层的 `Prs` 最开始是空的，甚至不包含自身，在这种状态下可以认为其属于一个“**待机**”状态，只允许处理 `MsgSnapshot`，其余消息一律作废。

只有收到了 snapshot 并更细状态后，`Prs` 也被正确赋值，其才知道了其他节点的存在，此时脱离“**待机**”状态。

等到 Leader 收到回复后，新 `Peer` 才算正式加入 Group。

> 当然，如果网络很差，snapshot 并没有收到，反而 Leader 早早挂了，那么新 `Peer` 并未被初始化，也无法参与原有节点在 election timeout 后发起的选举，可能会导致该 Group 彻底死掉——只有两个 `Peer` 时，Candidate 无论如何也无法从另一个未初始化的 `Peer` 处得到选票，也就无法成为 Leader。
> 
> 但是在 apply snapshot 之前又不能回应其余消息——谁知道 apply snapshot 后会不会拒绝呢？
>
> 3B 的最后几个测试中概率出现这种情况，我的做法是：算我过了。

由于 conf change 和后面的 region split 会导致 `RegionEpoch` 发生变化，所有 apply 之前都应当检查 `Request.Header` 中的校验字段是否匹配，除了 `RegionId` 是否一致、`RegionEpoch` 是否匹配，对于根据 `Key` 进行的操作，还要检查 `Key` 是否在 `Region` 中。很典型的例子就是目标 `Key` 因之前进行了 region split 跑到另一个 `Region` 里去了，此时再执行操作必然破坏一致性。

#### Implement split region in Raftstore

一次完整的 region split 流程如下：

1. `ticker` 定期通过 `onSplitRegionCheckTick()` 向 `splitChecker` 发送 `SplitCheckTask` 检查是否需要进行 split，如果需要则通过 `router` 发送一条 `MsgTypeSplitRegion` 消息;
2. 收到该消息后，`Peer` 执行 `onPrepareSplitRegion()`，首先校验该 split 是否合理，若是，则给 `Scheduler` 发送一则 `SchedulerAskSplitTask`;
3. 随后 `Scheduler` 生成新的 `RegionId` 以及新的 `PeerId`，包裹在 `Split` 的 Admin Command 中，通过 `router` 发松;
4. handler 收到消息，给 Leader propose 一条命令;
5. apply 到这条命令时，首先检查该命令是否有效，即 `RegionId` 与 `RegionEpoch` 是否匹配，若不匹配，说明在收到消息之前已经进行过 Peer Change 或 Region Split，返回一个 `error`;
6. 根据命令中包含的 `splitKey` 划分为两个 `Region`，值区间分别为 `[startKey, splitKey)` 与 `[splitKey, endKey)`，且 `RegionEpoch` 中的 `Version` 字段均在原基础上加 `1`;
   > 其中前者为原 `Region`，后者为新 `Region`
7. 根据命令中的 `NewPeerIds`，为新 `Region` 的 `Peers` 修改 `PeerId`，`StoreId` 不变;
8. 调用 `createPeer()` 在当前 `Raftstore` 上创建 `Peer`，并如同 `maybeCreatePeer()` 的那样进行注册与唤醒等操作;
9.  更新 `storeMeta`，分裂出的两个 `Region` 都要更新;
10. 如果当前节点在 `Raft` 层是 Leader 的身份，则需要返回 Response，并且给 `Scheduler` 发一则心跳信息，表示该操作已完成;

region split 中并没有很难处理的疑难杂症。

### Part C Scheduler

需要修改的代码位于 `scheduler/server/cluster.go` 与 `scheduler/server/schedulers/balance_region.go`，分别需要实现 `processRegionHeartbeat()` 函数与 `Schedule()` 函数。总体来讲比 3B 简单许多，根据任务书一步步来即可，仅有少量小bug需要根据测试的打印结果来调整。

#### 1 Collect region heartbeat

根据 3B 中描述的整体系统流程，每个集群 `Cluster` 所持有的总调度器 `Scheduler` 会根据 `Region` 发来的心跳信息为其分配任务（PeerChange、RegionSplit 等）。在真实网络下，心跳信息会以不可预知的速度到达 `Scheduler`，同时也可能因为网络分区而收到来自同个 `Region` 不同 Leader 的信息——这就需要我们记录下每个 `Region` 的重要信息（用 `RegionInfo` 这个数据结构来表示），以防收到 stale heartbeat。

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

`Cluster` 一经创建便持有一个 `Coordinator`，其会通过 `runScheduler()` 来调用 `scheduler.Schedule()`，定期检查是否有存储节点超载，就需要找到该节点 `src` 的一个**合适**的 `Region`，将位于 `src` 中从属于该 `Region` 的 `Peer` 转移到某个**合适**的目标节点 `dst`，从而达成负载均衡，并通过函数返回的 `MovePeerOperator` 加到该 `Region` 对应的“待执行命令”中，等待下一次该 `Region` 发来心跳信息时执行。 

> 一个 `MovePeerOperator` 包含以下步骤：
> 
> 1. 删除原节点的 `Peer`（即 `RemovePeer` 操作）;
> 2. 如果必要则还要进行 `transferLeader`;
> 3. 将新 `Peer` 加入 `Region`（即 `AddPeer` 操作）;
> 
> 最后等待该新 `Peer` 收到消息正式加入 Group。

上文提到**合适**，那么究竟何谓**合适**？

首先是**合适**的 `Region`，任务书指出：

1. First, it will try to select a `pending region` because pending may mean the disk is overloaded;
2. If there isn’t a pending region, it will try to find a `follower region`;
3. If it still cannot pick out one region, it will try to pick `leader regions`;

> 可以利用框架提供的三个函数 `GetPendingRegionsWithLock()`, `GetFollowersWithLock()` and `GetLeadersWithLock()` 进行挑选。

`dst` 的确定原则也很简单：在所有满足 src.RegionSize - dst.RegionSize > 2 * region.ApproximateSize 中选出那个 `RegionSize` 最小的节点。如果 `RegionSize` 差值不够大，那么在迁移后很可能重新迁移回去。

> 当然，目标节点必须不包含同一 `Region`，原因不言而喻，需要在 coding 中特别注意。

确定下来后，我们就可以在 `dst` 上调用 `AllocPeer()` 分配空间了，然后根据已有信息创建一个 `MovePeerOperator` 并返回。

值得注意的是，我们进行检查的所有节点必须为 **suitable**，即：a suitable store should be `up` and the `down time` cannot be longer than `MaxStoreDownTime` of the cluster, which you can get through `cluster.GetMaxStoreDownTime()`.

整个代码如下：

```go
  var originalRegion *core.RegionInfo
	var originalStore *core.StoreInfo
  var targetStore *core.StoreInfo
	stores := GetAllSortedSuitableStores(cluster)
	
  // find original region and original store
	cb := func(container core.RegionsContainer) {
		originalRegion = container.RandomRegion([]byte{}, []byte{})
	}
	for i, store := range stores {
		if originalRegion = SelectSuitableRegion(cb); originalRegion != nil {
      originalStore = stores[i]
      break
    }
	}
	if originalStore == nil {
		return nil
	}

  // find target store
	for target := len(stores) - 1; target >= 0; target-- {
		regionInTargetStore := RegionIsInStore(originalRegion, stores[target])
		if !regionInTargetStore && isDifferenceBigEnough(stores[original], stores[target], originalRegion) {
      targetStore = stores[target]
			break
		}
	}
	if targetStore == nil {
		return nil
	}

	newPeer := AllocPeer(cluster, stores[target].GetID())
	return CreateMovePeerOperator(s.GetName(), cluster, originalRegion, operator.OpBalance, stores[original].GetID(), stores[target].GetID(), newPeer.GetId())
```
> 并且由于 `RaftGroup` 随时可能变化，故对于不在组内的节点而言，任何消息都是无效的——即便收到消息，也不能做任何事。对于新加入组的节点而言，Raft 层的 `Prs` 可能未被正确初始化，所以如果收到一条 peer 的消息而该 peer 又不在 `Prs` 中时，将其加入。

有一点不能理解的是，虽然任务书中表示 `RegionEpoch.ConfVer` 会在 confchange 中改变，但并没有说 `RegionEpoch.Version` 也会改，只说了在 split 中改变。然而测试用例会不通过“只修改了 confver 而不修改 version”的代码。

#### 3 RegionSplit

不同 RaftGroup 负责不同 Region，随着时间推进必然会有一些 Region 会超出一个值 `RegionSplitSize`，为了负载均衡，必须将这些过大的 Region 一分为二。

