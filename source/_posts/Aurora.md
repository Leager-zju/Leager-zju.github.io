---
title: Aurora 论文阅读
author: Leager
mathjax:
  - true
date: 2022-10-09 19:46:40
summary:
categories: paperReading
tags:
  - MIT 6.824
img:
---

6.824 的第七篇论文是 [**Aurora**](https://pdos.csail.mit.edu/6.824/papers/aurora.pdf)——一个高性能，高可靠的关系数据库服务。在处理事务的速度上，Aurora 宣称比其他数据库快 35 倍。同时，其完全抛弃了通用存储，转而构建了自己**应用定制的存储**。

<!--more-->

## Aurora 产生背景

### EC2(Elastic Cloud 2)

这是 Amazon 最早的云产品。Amazon 有装满了服务器的数据中心，并且每个服务器上都会运行一个 VMM(**Virtual Machine Monitor**)，以及一些 EC2 实例。每个实例在运行一个标准的操作系统的同时，出租给不同的用户。每个 EC2 的操作系统之上运行着 Web 服务或数据库等应用程序。这种方式成本低，且相对容易配置，在早期是一个成功的服务模式。

最早的时候，EC2 使用的都是服务器上的硬盘，每个 EC2 实例都会分到硬盘的一部分空间。

对于无状态的 Web 应用，如果客户数量增加了，可以通过租用更多 EC2 实例来对 Web 服务扩容，尽管服务器崩溃了，只需要在另一台服务器上启动一个新的 EC2 实例就好了。而对于数据库而言，一旦服务器崩溃了，其本地硬盘将无法访问，运行在服务器上的数据库 EC2 实例也将失效——因为数据丢失了。

Amazon 本身有实现块存储的服务，叫 S3。可以定期对数据库做快照，然后存到 S3 上，并基于快照来实现故障恢复。但也有可能失去两次快照之间的数据，

### EBS(Elastic Block Store)

它表现得像个硬盘，具有容错性，且支持持久化存储的服务，其底层是一对互为副本的存储服务器。当用户要使用数据库 EC2 时，可以将一个 EBS 挂载为自己的硬盘。

当数据库执行写操作时，数据会通过网络传输到 EBS 服务器，之后，那一对存储服务器会使用 **Chain Replication** 进行数据复制。

> 第一个服务器处理写，第二个服务器处理读。

虽然 EBS 的出现能够在一定程度上避免因服务器崩溃而导致的数据丢失，但却会产生大量的网络流量，并且容错性并没有得到很好的保障——两个存储服务器会放在同个数据中心（在 paper 中称为 **AZ, Available Zone**）中，也就意味着一旦数据中心崩溃了，那就没辙了。

### RDS(Relational Database Service)

RDS 尝试将数据进行跨 AZ 复制，这样就算整个 AZ 挂了，用户还可以从另一个 AZ 中获取数据。

对于 RDS 而言，有且仅有一个 EC2 实例作为**主数据库**，这个数据库将其 data page 和 WAL log 存在 EBS，EC2 和 EBS 都在同一个 AZ $AZ_1$ 中。每次数据库执行写操作时，RDS 会自动将写操作拷贝到另一个 AZ $AZ_2$ 中的**副数据库** EC2 实例上，这个 EC2 的工作就是执行和主数据库相同的操作，写入成功后，会发一个 ack 给主数据库，主数据库看到了这个 ack 后才会认为真正意义上的写入成功。

但实际上，这样还是会通过网络传输相当大量的数据。

## Aurora

在 Aurora 的架构中，会有 $V$ 个数据副本代替 EBS 的位置，分别存放在 $z$ 个不同的 AZ 中。与此同时，Aurora 通过网络传输的是 **log 条目**而非 data page，这也大大提高了网络性能。当然，这也就导致了 Aurora 的存储系统不再是只能理解 data 的通用存储了，变成了**能够理解 log 的应用定制存储系统**。

### 复制与相关故障

Aurora 采用**基于仲裁的投票协议**来保证容错，即不需要所有副本都确认了读/写操作后才能继续执行。这个协议是这样的：

1. 每次读操作都需要获得 $V_r$ 个确认；
2. 每次写操作都需要获得 $V_w$ 个确认；
3. $V_r + V_w > V$，保证每次读都能知道最近的写入；
4. $V_w > V/2$，保证每次写入必须知道最近的写入从而避免写入冲突；

这样一来，Aurora 可以有更多的副本和 AZ，而不需要付出过大的性能代价——因为它无需等待所有副本，只需要等待最快的 $V_r/V_w$ 个副本就好了。这也容忍了少数副本的 crash 或是偶尔的慢响应。

这里又会出现一个问题，客户端读请求可能会得到 $V_r$ 个不同的结果，却并不知道哪个结果是正确的。解决这一问题的方法就是设置**版本号**，每次写请求都会将新的数值与一个递增的版本号绑定，于是读请求便可以从所有结果中取版本号最高的那个结果。

### 容错目标

在 Aurora 中，我们希望

- 在整个 AZ 和一个额外的副本崩溃后而不丢失数据；
- 整个 AZ 崩溃后不会影响写入数据；

于是设置 $V = 6,\ V_w = 4,\ V_r = 3,\ z = 3$，这样每个 AZ 存放 2 个副本。在这样的设置下，一个 AZ 和一个副本崩溃不会影响读性能，且任意两个副本崩溃后也能保持写入可用性。

### 数据分片(Sharding)

对于 Aurora 而言，每个副本都是一个计算机，其内存是有限的，且尽管我们有 6 个副本，我们并没有得到 6 倍大小的内存——每个副本上存放的数据都是一致的。对于数百 TB 甚至更多的数据，需要找一个明智的策略进行存储。

这一策略是：将数据库的数据，分割到多组(**PG, Protection Group**)存储服务器上，每一个 PG 都包含若干存储服务器作为副本，存该 data page 10GB 的数据。

> 这里的 PG 是个**逻辑概念**。

Sharding 后，如果要进行 log 处理，则会查看 log 所修改的数据，并找到存储该数据的 PG，并将 log 只发送给该 PG 的副本。这也就意味着，每个 PG 只存储部分 data page 和所有与这些 data page 相关的 log 条目。

如果某个副本挂了，希望能尽快生成新的副本。事实上，尽管每个 PG 存了某个数据库的 10GB 数据，但一个副本所拥有的存储容量可能高达 10TB，也就是说该副本可能存了成百上千个 PG 的"10GB"，一旦该副本挂了，会牵连到与之相关的所有数据库。一个简单的策略是找到另一台存储服务器，通过拷贝的形式将该副本的所有数据都通过网络传输到新的副本中，但对于 10Gb/s 的网络来说，需要的时间还是太久了。

Aurora 是这么做的：若某个副本保存了 $PG_1,\ PG_2,\ \dots,\ PG_n$ 的数据，则将这 $n$ 个 PG 的数据并行传输到 $n$ 个新的存储服务器上。也就是说这 $n$ 个存储服务器，每个都会加入到一个新的 PG 中。比起上面的策略，我们获得了 $n$ 倍的性能提升。
