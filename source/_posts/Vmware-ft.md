---
title: VMware-FT 论文阅读
author: Leager
mathjax: true
date: 2022-10-03 15:31:03
summary:
categories: paperReading
tags: MIT 6.824
img:
---

6.824 的第三篇论文是 **[VMware-FT](https://pdos.csail.mit.edu/6.824/papers/vm-ft.pdf)**(VMware-FaultTolerance)，其描述了一个提供容错虚拟机的商业企业级系统——如果主服务器(**primary**)发生故障，备份服务器(**backup**)始终可以接管。backup 的状态必须始终保持与 primary 几乎相同，以便在其发生故障时，backup 可以立即接管，并且外部客户端看来并未发生故障且没有数据丢失。

<!--more-->

## 两种容错方式

### 状态转移

在 backup 上复制状态的一种方法是每次同步时，primary 将其**所有状态**（包括 CPU、内存和 I/O 设备）**变化**进行完整地拷贝，并发送到 backup。但发送此状态所需的带宽会非常大。为了提升效率，可以优化为：每次同步只发送上次同步之后改变了的状态。

### 操作转移

将服务器建模为**确定性状态机**，并实现以下两个条件：

1. 从相同的初始状态开始；
2. 以相同的顺序执行相同的操作；

如果能确保以上两个条件，那么它们会一直互为副本，并且一直保持一致。由于大多数服务器或服务都有一些不确定的操作，因此必须使用额外的协调来确保 primary 和 backup 保持同步，而这一协调所需的额外信息量远远少于 primary 中正在更改的状态量。

## 总结

操作 Log 的复制与状态机的思路给后续以启迪。
