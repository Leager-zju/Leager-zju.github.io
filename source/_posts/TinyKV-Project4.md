---
title: TinyKV-Project4 Transaction
author: Leager
mathjax: true
date: 2023-08-20 23:37:15
summary:
categories: TinyKV
tags: lab
img:
---

本 Project 需要我们实现基于 MVCC 的事务模块。

<!--more-->

## 思路

### Part A Mvcc Txn

需要实现的代码在文件夹 `kv/transaction/mvcc` 下。

这一 part 需要我们实现支持 MVCC(多版本并发控制, Multiversion Concurrency Control) 的事务 api。

一个事务在时间点 `t` 处新建时，会被赋予当前存储的 `Reader` 以及时间戳 `StartTS = t`。所有的 api 相关操作都是基于时间线来进行处理。

> 另外还有一个隐性的规则是：两个不同事务的 `StartTS` 一定不相等。

TinyKV 存储使用 3 个 CF 来存放不同类型数据，分别为：

|CF|Key|Value|
|:-:|:-:|:-:|
|default|UserKey_StartTs|Value|
|lock|UserKey|Lock Data Structure To Byte|
|Write|UserKey_CommitTs|Write Data Structure To Byte|

> 存储按 key 字母序递增排序。同个 key 按存储时间戳降序排序，即越新的在越前面。

#### 1 Put/Delete

所有写操作都只需要为事务的 `writes` 切片添加新的 `Modify` 即可。注意使用实现好的 `EncodeKey()` 函数将 Key 重新编码为正确格式，以及使用 `engine_util` 包下的三个 CF 常量: `CfDefault`, `CfLock`, `CfWrite`。

#### 2 Get

对于 `Lock` 的读取是简单的，因为任意一个 `UserKey` 只会对于一个 `Lock` 变量，调用 `txn.Reader.GetCF()` 后进行 `ParseLock()` 即可。

对于 `Value` 的读取返回在当前时间戳**有效**的值，则需要考虑在当前事务之前最后一个提交的 `Write`：

- 如果不存在符合要求的 `Write`，说明该 `Value` 尚未被任何一个事务 commit，这种数据是禁止读取的，否则可能破坏一致性;
- 如果最后一个 `Write` 类型是 `Delete`，说明该 Key 在最近的一次事务提交时被删除，那么当前时间点的读取是得不到任何数据的;
- 如果最后一个 `Write` 类型是 `Put`，说明在时间戳 `Write.StartTs` 处修改的值是有效的，且一定有 `Write.StartTs <= txn.StartTs`，即键 `EncodeKey(UserKey, Write.StartTs)` 对应的 `Value` 就是我们想要的;

> 即数据在 `LastCommitWrite` 有效且类型为 `Put` 时可读。

对于 `Write` 则有 2 种不同的 Get

- `CurrentWrite`：读取当前事务对给定 Key 施加的 `Write` 及其 `CommitTs`，即满足 `StartTs == txn.StartTs` 的 `Write`;

- `MostRecentWrite`：读取给定 Key 的最后一次 `Write` 及其 `CommitTs`，

> 用 `IterCF()` 获取迭代器，因为排序方法的限制，不能用 `iter.Seek()`，这只会得到 `commit <= txn.StartTs` 的 `Write`（即前文提到的 `LastCommitWrite`）。需要遍历 `CfWrite` 下的所有 K/V。

### Part B TinyKV Server 1

需要实现的代码在文件夹 `kv/server` 下。

这一 Part 需要我们实现 TinyKV Server 的三大基本 RPC api。

#### 1 KvGet

`KvGet` 实现单键读取。对于一个给定的 `Key` 以及当前时间戳 `Version`，首先需要检查当前是否被上锁，如果是，则说明必然有某个事务正在对其进行写操作，需要向客户端报告错误。

> 一把锁的有效时间范围在 `[lock.Ts, lock.Ts + lock.Ttl]` 中（如果 `lock.Ttl = 0` 则表明永久有效，直到被删除）。

```go
lock := getLock(txn, key)
if lock.IsLockedAt(Version) {
  // err: the key has been locked
  response.Error = &kvrpcpb.KeyError{
    Locked: lock.Info(Key),
  }
  return response, nil
}
```

如果未上锁，则正式读取，调用 `txn.GetValue()` 即可。如果返回值为 `nil` 则修改 `response.NotFound = true`。

#### 2 KvPreWrite

`kvPreWrite` 对应 2PC 的上升阶段。

在执行过程中首先需要对每个 Key 判断是否被上锁，如果上锁了就跟 `KvGet` 一样报告错误。

其次检查该 Key 的最后一次修改是否与当前事务冲突，即获取 `MostRecentWrite` 并检查区间 `[StartTs, CommitTs]` 是否与当前请求时间戳重合，若是则说明存在其他客户端已经发起请求并对数据进行了修改，报告错误。（要保证对同一个 Key 所有修改的时间区间 `[StartTs, CommitTs]` 不发生重叠）

```go
mostRecentWrite, commitTs, err := txn.MostRecentWrite(key)
if mostRecentWrite != nil && mostRecentWrite.StartTS < StartVersion && commitTs >= StartVersion {
  // err: conflict with another transaction
  response.Errors = append(response.Errors, &kvrpcpb.KeyError{
    Conflict: &kvrpcpb.WriteConflict{...},
  })
  return response, err
}
```

如果安全，则上锁，并根据修改类型对 `CfDefault` 中的数据进行修改。最后调用 `server.storage.Write()` 将修改落实到数据库中。

> 如果中途报错，会直接返回，也就不会走到 server.storage.Write 这一步，更不会对数据库进行修改。

#### 3 KvCommit

`KvCommit` 对应 2PC 的下降阶段。提交操作并不修改 `CfDefault` 中的数据，而是通过修改 `CfLock` 与 `CfWrite` 来标志该数据已提交。

对于每个 Key，首先检查是否重复 commit，即是否存在 `CurrentWrite`，若有则说明后续所有 Key 都确定被提交，直接返回即可。当然如果这个 `Write` 是 `Rollback`，那么还需要修改 `Retryable` 并报错。

再检查是否由**当前事务上锁**，即

```go
lock := getLock(txn, key)
if !lock.IsLockedAt(req.GetStartVersion()) {
  response.Error = &kvrpcpb.KeyError{
    Retryable: "Unlocked",
  }
  return response, nil
}
if lock.Ts != req.GetStartVersion() {
  response.Error = &kvrpcpb.KeyError{
    Retryable: "Locked By Another Txn",
  }
  return response, nil
}
```

如果能够安全提交，则删除之前上的锁，并在 `CfWrite` 下添加相应条目。最后调用 `server.storage.Write()` 将修改落实到数据库中。

### Part C TinyKV Server 2

#### 1 KvScan

`KvScan` 获取当前时间戳下所有有效的值。任务书建议我们用 `Scanner` 来包装操作，相关文件为 `kv/transaction/mvcc/scan.go`。

`Scanner` 应内置一个迭代器，并在创建时初始化至给定的`StartKey` 位置处。执行时不断遍历 `CfDefault` 并检查当前值是否有效。由于排列方式，我们对同一个 Key 最早遍历到的肯定是最新的版本，并且同一个 Key 一定会连续出现，如果

1. 该 Key 之前已经被返回过（故 `Scanner` 还需内置一个 `LastKey` 变量来记录最后一个成功返回的 Key）;
2. 该 Key 版本晚于当前事务;
3. 对应的 `LastCommitWrite` 为 nil，说明尚未提交，或类型非 `Put`;

则跳到下一个，否则返回当前 K/V。

#### 2 KvCheckTxnStatus

`KvCheckTxnStatus` 检查给定 PrimaryKey 的当前状态，并执行可能的改动。

1. 如果存在 `CurrentWrite`，则无需进行改动。如果该类型非 `Rollback` 则还需告知 `CommitTs`;
2. 检查是否存在 `Lock`，若无则回滚;
3. 检查 `Lock` 是否超时，若超时则删除原有 `Value` 与 `Lock` 并回滚;

```go
lock := getLock(txn, PrimaryKey)
if !lock.ExistAt(CurrentTs) {
  response.Action = Action_LockNotExistRollback
  txn.PutWrite(PrimaryKey, LockTs, &mvcc.Write{...})
} else if lock.IsExpiredAt(CurrentTs) {
  response.Action = Action_TTLExpireRollback
  txn.DeleteValue(PrimaryKey)
  txn.DeleteLock(PrimaryKey)
  txn.PutWrite(PrimaryKey, LockTs, &mvcc.Write{...})
}
```

#### 3 KvBatchRollback

`KvBatchRollback` 实现多键批量回滚操作。

1. 如果该 Key 已被回滚，则跳过后续操作，检查下一个 Key;
2. 如果该 Key 已被提交，则报错并返回;
3. 如果该 Key 之前被本事务上锁，则删除原有 `Value` 与 `Lock`;
4. 添加一条 `Rollback` 条目;
5. 最后调用 `server.storage.Write()` 将修改落实到数据库中。

#### 4 KvResolveLock

`KvResolveLock` 需收集由本事务上锁的所有 Key，并根据请求中的 `CommitVersion` 字段执行不同操作。

1. `CommitVersion = 0`: 执行 `BatchRollback`;
2. `CommitVersion != 0`: 执行 `Commit`;

```go
func (server *Server) KvResolveLock(_ context.Context, req *kvrpcpb.ResolveLockRequest) (*kvrpcpb.ResolveLockResponse, error) {
  ...
  if CommitVersion > 0 {
    commitResponse, err := server.KvCommit(context.TODO(), &kvrpcpb.CommitRequest{...})
    response.RegionError, response.Error = commitResponse.GetRegionError(), commitResponse.GetError()
    return response, err
  }
  // else
  rollbackResponse, err := server.KvBatchRollback(context.TODO(), &kvrpcpb.BatchRollbackRequest{...})

  response.RegionError, response.Error = rollbackResponse.GetRegionError(), rollbackResponse.GetError()
  return response, err
}
```