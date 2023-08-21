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

### Part A Leadership/Membership Change

需要修改的代码位于 `raft/raft.go`，`raft/rawnode.go` 与 `kv/raftstore/peer_msg_handler.go`。

#### 1 Leadership Change

一次完整的领导人转移的流程如下：

1. 上层收到命令，向下 push 一条 `TransferLeader` 类型的 `AdminRequest`;
2. `Leader` apply 这条命令时，调用 `rawnode.TransferLeader()`，即收到一条本地 `MsgTransferLeader` 消息;
3. 如果迁移目标 `transferee` 不是 `Leader` 本身时，检查 `transferee` 是否有资格上任（如日志是否最新）;
4. 如果 `transferee` 的日志不是最新的，则 `Leader` 应该向其发送 `MsgAppend`（并停止进行 `Propose`）直到其符合条件;
5. 一旦满足迁移条件，`Leader` 应该立即向其发送一条`MsgTimeoutNow`，`transferee` 在收到消息后立即开始新的选举——即 `Step(MsgHup)`——从而依靠最新的 `Term` 和 `LastLog` 当选领导人;

> 如果触发上述步骤 4，则需要在后续的 `HandleAppendEntriesResponse()` 中进行判断。

#### 2 Membership Change

**注意**：这里的成员变化并不像 Raft Paper 中提到的那样一次可以增/删若干个成员，而是只能一个一个来。

一次完整的成员关系变化的流程如下：

1. 上层收到命令，向下 push 一条 `ChangePeer` 类型的 `AdminRequest`;
2. `handler` 优先检测是否为该类型的命令，若是，则调用 `RawNode.ProposeConfChange()` 给 `Leader` Propose 一条 `EntryConfChange` **特殊类型**日志;
3. `Leader` apply 这条**特殊类型**的命令时，调用 `rawnode.ApplyConfChange()`，然后根据命令类型——增添成员还是移除成员——调用 `Raft.addNode()` 或 `Raft.removeNode()`;
   
> 值得一提的是，同一时间只能存在至多一个未被 apply 的 `EntryConfChange` 日志，这一点是通过变量 `Raft.PendingConfIndex` 实现的，即，如果上层要求 propose 一条该类型日志，而上一条 `EntryConfChange` 日志未被 apply（表现为 `Raft.PendingConfIndex < Raft.RaftLog.applied`），就放弃该日志的 propose。