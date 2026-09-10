---
title: "TinyKV 分布式键值存储"
slug: "tinykv"
date: 2023-08-20
summary: "从独立存储引擎、Raft、多 Raft 到 MVCC 事务，记录 TinyKV 四个阶段的实现过程。"
status: "ARCHIVED"
code: "TINYKV"
stack: ["Go", "Badger", "Raft", "MVCC"]
---

TinyKV 是一个以 Go 实现的分布式键值存储课程项目。项目笔记按四个阶段组织：

- [Project 1 — StandaloneKV](/notes/tinykvproject1/)
- [Project 2 — RaftKV](/notes/tinykvproject2/)
- [Project 3 — Multi-Raft](/notes/tinykvproject3/)
- [Project 4 — Transaction](/notes/tinykvproject4/)

这个项目入口保留项目级概览，具体实现细节继续放在文章库中，便于从作品集和知识库两个方向进入。
