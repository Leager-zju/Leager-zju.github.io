---
title: TinyKV Project1 StandaloneKV
author: Leager
mathjax:
  - false
date: 2023-08-13 20:30:13
summary:
categories: lab
tags:
  - lab
img:
---

本 Project 需要我们基于 badger 实现一个独立存储引擎。

<!--more-->

## 思路

### Part A Implement standalone storage engine

需要实现的代码在 `kv/storage/standalone_storage/standalone_storage.go`。

`NewStandAloneStorage(conf *config.Config)` 是工厂函数，返回一个 `StandAloneStorage` 指针。在这里需要了解 `Config` 数据结构，里面存放了数据库文件路径等重要信息，并且在其他方法中也要用到，所以在 `StandAloneStorage` 结构体中需存放传入的 `Config` 信息，以及其包装的 badger DB 实例。

`Start()` 函数驱动存储引擎运行，调用 `engine_util.CreateDB()` 并将返回值存在结构体中即可；同样的，`Stop()` 调用 `badger.DB.Close()` 即完成存储引擎的关闭。

`Write()` 传入一个 `Modify` 切片。`Modify` 表示实现了 `Cf()/Key()/Value()` 三个函数的接口，可以是 `Put/Delete`（见 `kv/storage/modify.go`）。通过遍历该切片，执行类型转换，调用 `engine_util.PutCF()/engine_util.DeleteCF()` 方法即可。

`Reader()` 需要返回一个 `StorageReader`。这是一个已经为我们定义好了的接口，我们要做的就是实现该接口，即定义一个 `StandAloneStorageReader` 及 `GetCF()/IterCF()/Close()` 三个函数，这样就能在调用 `Reader()` 时返回了。

> 这三个函数其实分别对应了 util_engine 包中为我们实现好的 `GetCFFromTxn()/NewCFIterator()` 以及 `badger.Txn.Commit()`。所以新建结构体的时候还得包裹 `badger.Txn` 变量。

### Part B Implement service handlers

需要实现的代码在 `kv/server/raw_api.go`.

这里需要实现的 4 个函数，其实就是获取传入的 `Request` 中的各种字段，调用 `Storage` 的 `Write`（对应 Put/Delete 请求）/`Reader`（对应 Get/Scan 请求），最后 return 一个 `Response` 即可。

> 甚至给了我们 Hint，我哭死。

需要注意的是 `RawScanRequest` 有一个 `Limit` 字段，在迭代器遍历过程中还要注意不要超限。

```go
limit := req.GetLimit()
for iter.Seek(req.GetStartKey()); iter.Valid() && limit > 0; iter.Next() {
  // response.Kvs = append(response.Kvs, "the data we get")
  limit--
}
```

> 其实符合 SQL 语句中的 limit 关键字。