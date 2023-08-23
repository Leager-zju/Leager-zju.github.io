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
- 如果待增加节点未出现在 `RaftGroup` 中，则新增一个条目；
- 如果待删除节点出现在 `RaftGroup` 中，则删除一个条目；

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


