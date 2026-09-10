---
title: "MIT6.824 学习总结"
date: "2022-11-28 00:48:07"
slug: "6-824"
url: "/notes/6-824/"
draft: false
math: false
categories:
  - "lab"
tags:
---

磨蹭 3 个月，神课分布式系统 [MIT 6.824](https://pdos.csail.mit.edu/6.824/) 终于完结了。学习这门课的起因是被同年 6 月份 pingCAP 训练营橄榄了，虽然同为 raft 算法，但工业级的实现显然要比教学级难更多。我对分布式的理解还是太浅，于是决心从基础打起，好好体会一下这门神课的洗礼。

<!--more-->

## 课程架构

[👉课程主页传送门👈](https://pdos.csail.mit.edu/6.824/)

本课程设计了 4 个 lab。分别为

- [MapReduce](https://pdos.csail.mit.edu/6.824/labs/lab-mr.html)
- [Raft](https://pdos.csail.mit.edu/6.824/labs/lab-raft.html)
- [Fault-tolerant Key/Value Service](https://pdos.csail.mit.edu/6.824/labs/lab-kvraft.html)
- [Sharded Key/Value Service](https://pdos.csail.mit.edu/6.824/labs/lab-shard.html)

我的实现通过所有 test，将代码 push 在了我的 [github 仓库](https://github.com/Leager-zju/MIT6.824)中，并写了说明文档：

- [Lab1 doc](/notes/6-824lab1/)
- [Lab2 doc](/notes/6-824lab2/)
- [Lab3 doc](/notes/6-824lab3/)
- [Lab4 doc](/notes/6-824lab4/)

## 学习感悟

每节课看一篇论文对我而言还是比较硬的，但确实能够从中学到许多知识，复制、容错、一致、性能优化……这些无一不是分布式领域中的人类思想的精华。在进一步经历了 4 个 lab 的虐待后，无论是对 go 还是对整个分布式系统的实现都有了更深的认识。这也难怪 MIT 的学生一直以来都是各大互联网企业争相抢夺的人才资源，能够把这门课完整的学下来已经能让一个人进步非常多了。
