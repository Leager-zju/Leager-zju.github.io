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
- 如果迁移目标 `transferee` 是自己，则直接触发 `MsgTimeoutNow`，尝试成为 Leader;

**Leader**：
- 如果迁移目标 `transferee` 是自己，则什么也不干（已经是 Leader 无需迁移）;
- 反之
  1. 需检查其是否有资格上任（即日志是否和自己一样新）;
  2. 如果 `transferee` 的日志不是最新的，则 Leader 应该向其发送 `MsgAppend`（并停止进行任何之后的 `Propose`）直到其符合条件——这需要在后续的 `HandleAppendEntriesResponse()` 中进行判断;
  3. 一旦满足迁移条件，Leader 应该立即向其发送一条`MsgTimeoutNow`，`transferee` 在收到消息后立即开始新的选举——即 `Step(MsgHup)`——从而依靠最新的 `Term` 和 `LastLog` 当选领导人;

#### 2 Membership Change

这里我们仅需修改 `Raft.addNode()` 与 `Raft.removeNode()`。

节点的增减其实就是对 `Raft.Prs` 哈希表的修改：
- 如果待增加节点未出现在 `RaftGroup` 中，则新增一个条目；
- 如果待删除节点出现在 `RaftGroup` 中，则删除一个条目；

对节点的增删会导致“大多数”发送变化：若节点增加，则新节点等待 `AppendEntries` 即可。若节点减少，则需要重新更新 `committed` 并发送;

### Part B Implement Admin Commands

3B 中我们就要正式实现加上**域分裂**(Region Split)在内的所有 Admin Commands 了。需要实现的代码位于 `kv/raftstore/peer_msg_handler.go` 与 `kv/raftstore/peer.go` 中。

#### 1 TransferLeader

因为领导迁移仅仅是一个操作，无需所有节点进行复制，所以收到该类型的 `AdminRequest` 时，直接调用 `RawNode.TransferLeader()` 即可。

#### 2 ChangePeer

一次完整的节点增删流程如下：

1. 上层收到命令，向下 push 一条 `ChangePeer` 类型的 `AdminRequest`;
2. `handler` 优先检测是否为该类型的命令，若是，则调用 `RawNode.ProposeConfChange()` 给 Leader Propose 一条 `EntryConfChange` **特殊类型**日志;
3. apply 这条**特殊类型**的命令时：
   - 首先调用 `util.CheckRegionEpoch()` 检查该命令是否为 stale command;
      > 任务书中明确提到，可能在某条 changePeer 被 apply 之前多次发送相同命令直到第一条被 apply（防止因网络问题而导致的消息丢失，这种做法也尽可能保证能收到）。每一条 changePeer/split 被 apply 时都会修改 `regionEpoch`——其作用相当于 Raft 层的 `Term`，只接收相同 epoch 的消息。所以一旦收到与该 epoch 不同的消息时就返回一个 `EpochNotMatch` 以避免破坏一致性。
      > ```go
      > // refuse stale command
	    > if err, ok := util.CheckRegionEpoch(msg, d.Region(), true).(*util.ErrEpochNotMatch); ok {
      >   response.Header.Error.EpochNotMatch.CurrentRegions = err.Regions
      >   d.SendResponse(response, entry.GetIndex(), entry.GetTerm(), false)
		  >   return
	    > }
      > ```
   - 修改 `storeMeta` 中的 `region` 与 `regionRanges`，并调用 `storeMeta.SetRegion()`;
   - 修改 `peer` 中的 `peerCache`;
   - 将 `RegionLocalState` 写入 badger;
   - 调用 `rawnode.ApplyConfChange()`，然后根据命令类型进行 `Raft` 层的节点变动;
   - 如果是 Leader，则给出回复，并调用 `HeartbeatScheduler(schedulerTaskSender)` 发送心跳消息来驱动新建节点执行 `maybeCreatePeer()`;
4. Raft 层调用 `AddNode()` 增加一个节点时，其 `Match/Next` 应被初始化为 0，以便触发 `next <= truncatedIndex` 从而发送 snapshot;
5. snapshot 中包含 Region 信息，当新节点收到数据并在 PeerStorage 层通过 `SaveReadyState()` 进行 `ApplySnapshot()` 时，会得到一个包含 `PrevRegion` 和 `Region` 的 `ApplySnapResult`，之后需要拿着这个去修改 `storeMeta` 的相关变量;

至此，节点变更完成。

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
> ```
>
> 并且由于 `RaftGroup` 随时可能变化，故对于不在组内的节点而言，任何消息都是无效的——即便收到消息，也不能做任何事。对于新加入组的节点而言，Raft 层的 `Prs` 可能未被正确初始化，所以如果收到一条 peer 的消息而该 peer 又不在 `Prs` 中时，将其加入。

有一点不能理解的是，虽然任务书中表示 `RegionEpoch.ConfVer` 会在 confchange 中改变，但并没有说 `RegionEpoch.Version` 也会改，只说了在 split 中改变。然而测试用例会不通过“只修改了 confver 而不修改 version”的代码。

#### 3 RegionSplit

不同 RaftGroup 负责不同 Region，随着时间推进必然会有一些 Region 会超出一个值 `RegionSplitSize`，为了负载均衡，必须将这些过大的 Region 一分为二。

一次完整的 Region 分裂流程如下：

1. handler 定期触发 `onSplitRegionCheckTick()`，执行 `SplitCheckTask`，检查 Region 大小;
2. 如果需要分裂，则给 handler 发送 `MsgTypeSplitRegion` 消息，携带该 Region 的 `RegionEpoch` 信息以便判断是否过时，以及新 Region 的第一个 Key;
3. handler 收到消息后执行 `onPrepareSplitRegion()`，检查消息携带的数据是否合理。若检查通过，则向调度器 scheduler 发送 `SchedulerAskSplitTask`，告知待分裂的 Region;
4. scheduler 随后向 handler 发送 `AdminCmdType_Split` 类型的 `AdminRequest`，告知新 Region 的 `newRegionId` 以及 `newPeerIds`;
5. handler 收到请求后，向下 propose，等待 apply;
6. apply 这条命令时：
   - 分裂出的两个 Region1, Region2 分别覆盖了 `[startKey, splitKey)` 与 `[splitKey, endKey)` 这两个范围，并且 `RegionEpoch` 均在原 Region 基础上增加;
   - Region1 继承原 Region 的所有数据（除了 `endKey` 字段），别忘了和 changePeer 一样修改 `storeMeta` 并持久化到 badger;
   - Region2 根据请求中所持有的 `newRegionId` 以及 `newPeerIds` 来初始化;
     > 初始化 `Peers` 时根据 peer id 新建 `metapb.Peer` 变量，而不是通过 `peer.getPeerFromCache()`。这可能会导致之前不在原 Region 中的 peer id 被加进去。
   - 调用 `router.register()` 将其注册，使其能够进行消息收发;