---
title: CMU15445 project#4 Concurrency Control
author: Leager
mathjax:
  - false
date: 2023-01-12 11:56:16
summary:
categories: lab
tags:
  - CMU 15445
img:
---

接下来，需要完善对事务并发的支持。

[>>> LAB 主页传送门 <<<](https://15445.courses.cs.cmu.edu/fall2022/project4/)

<!--more-->

## Task #1 - Lock Manager

LM 负责以五种不同的模式保持 Table 和 Tuple 两个粒度的锁：`IntensionShared(IS)`，`Shared(S)`，`IntensionExclusive(IX)`，`Exclusive(X)`，`SharedIntensionExclusive(SIX)`。LM 将处理来自事务的锁请求，向事务授予锁，并根据事务的隔离级别检查锁是否被适当释放。

先来看看各个类的数据定义。

### LockRequest

锁请求，包含请求事务的标识符 `txn_id`，待上锁 Table 标识符 `oid`，待上锁表行标识符 `rid`，本次请求的上锁类型 `lock_mode`，以及指明该请求是否授予的变量 `granted`。

### LockRequestQueue

将实际队列 `std::list<std::shared_ptr<LockRequest>>` 进行封装，额外添加了一把锁 `latch` 以及条件变量 `cv`，以便锁释放后通知其余等待中的锁。此外还有一个 `upgrading` 用来标识当前锁请求队列是否有锁正在进行升级。

### LockManager

首先是定义了锁类型 `LockMode`，就是上面提到的 5 种。除此之外，还有以下变量：

- `table_lock_map_`：每个 Table 都对应了一个锁请求队列，通过 table oid 获取；
- `row_lock_map_`：每一 Row 同样也有一个锁请求队列，通过 rid 获取；
- `waits_for_`：邻接表，表示某一事务正在等待的所有事务的集合，Task2 中会用到；

还有以上每个变量对应的锁。

### LockTable() / LockRow()

⚠<font color=red>***在实现上锁过程之前，务必反复阅读并理解头文件中的 Lock Note。***</font>

表锁和行锁的上锁过程基本类似，行锁在上锁前多了一个所在表是否正确上锁的判断，其余一致。这里就先讲**表锁**的上锁流程。

首先，判断以下三个变量是否兼容：

1. `txn.TransactionState`

    > GROWING, SHRINKING, ABORTED, COMMITTED

2. `txn.IsolationLevel`

    > Bustub 只规定了 3 个隔离级别：
    >
    > - `READ_UNCOMMITTED`：该隔离级别下，不加 S 锁。会出现**脏读**问题，即会读到其它事务修改但未提交的数据；
    > - `READ_COMMITTED`：该隔离级别下，读操作会加 S 锁，但单次读结束会直接释放 S 锁，并且即便在 SHRINKING 阶段也可以再次加 S 锁。解决脏读，但会出现**不可重复读**问题，即由于中途释放了锁，同一事务的两次读中间可能会出现其它事务的写操作，从而前后读到不同的数据；
    > - `REPEATED_READ`：该隔离级别下，所有操作均遵循 2PL，支持所有上锁，但等到事务 ABORTED/COMMITTED 后才释放所有锁，解决不可重复读，但会出现**幻读**问题，例如第一个事务对一个表中的数据进行了修改，且涉及到表中的全部数据行，同时，第二个事务向该表中插入一行新数据，那么，第一个事务的用户之后就会发现表中还存在没有修改的数据行，仿佛出现幻觉。

3. `lock_mode`

具体规则如下：

1. 如果 State 为 `ABORTED` / `COMMITTED`，则直接返回；
2. 如果 State 为 `GROWING`，IL 为 `READ_COMMITTED` 的事务不能上 S/IS/SIX 锁，否则抛出异常，其余上锁行为通过；
3. 如果 State 为 `SHRINKING`，只有 `READ_UNCOMMITTED` 能在此阶段上 S/IS/SIX 锁，其余所有上锁行为均抛出异常；

接下来，尝试获取锁请求队列，并在获取到后立刻释放 `lock_map` 锁，紧接着尝试获取 `lock_request_queue` 的锁。

接着，遍历队列，检查同一事务是否已经上过锁，若有，则认为这是一次**锁升级尝试**：如果已经有其它事务正在进行锁升级，则抛出异常，否则，如果升级未遵循如下规则，也要抛出异常。

> IS -> [S, X, IX, SIX]
>
> S -> [X, SIX]
>
> IX -> [X, SIX]
>
> SIX -> [X]

检查通过后，需要将原来的锁取出队列，并修改事务维护的相应锁集合，再将新的锁请求插到等待区的最前面。Lock Note 中提到，锁升级是优先级最高的请求，故将其插到所有 `granted = false` 的请求中的第一个位置，以便前面不兼容的锁释放后，其能够最先被授予。

> 原来的锁如果存在请求队列中，则必然已经授予，如若不然，事务不会退出，只会一直等待锁请求授予。

当然，如果本次上锁并非锁升级，则将请求插到队列的末尾。

插入请求后，就进入停等状态。这里就要用到 `lock_request_queue` 中的条件变量了，通过调用 `cv_.wait` 使得当前线程挂起，直到被唤醒，具体用法如下：

```cpp
std::unique_lock<std::mutex> lock(lock_request_queue->latch_);	// 必须为 unique_lock
while(!不满足授予条件) {
    lock_request_queue->cv_.wait(lock);
}
```

每次被唤醒，都会先检查授予条件是否满足，如果满足则直接退出循环，不再 `wait`。这里的授予条件是指，排在前面的所有锁（无论是否授予）的类型与其均兼容。只要有一个不兼容的锁，那就不满足条件。为了简化判断代码，我定义了一个锁兼容矩阵，如下所示：

```cpp
compatibility_matrix_[LockMode::SHARED][LockMode::SHARED] = true;
compatibility_matrix_[LockMode::SHARED][LockMode::INTENTION_SHARED] = true;
compatibility_matrix_[LockMode::SHARED][LockMode::EXCLUSIVE] = false;
compatibility_matrix_[LockMode::SHARED][LockMode::INTENTION_EXCLUSIVE] = false;
compatibility_matrix_[LockMode::SHARED][LockMode::SHARED_INTENTION_EXCLUSIVE] = false;

compatibility_matrix_[LockMode::INTENTION_SHARED][LockMode::SHARED] = true;
compatibility_matrix_[LockMode::INTENTION_SHARED][LockMode::INTENTION_SHARED] = true;
compatibility_matrix_[LockMode::INTENTION_SHARED][LockMode::EXCLUSIVE] = false;
compatibility_matrix_[LockMode::INTENTION_SHARED][LockMode::INTENTION_EXCLUSIVE] = true;
compatibility_matrix_[LockMode::INTENTION_SHARED][LockMode::SHARED_INTENTION_EXCLUSIVE] = true;

compatibility_matrix_[LockMode::EXCLUSIVE][LockMode::SHARED] = false;
compatibility_matrix_[LockMode::EXCLUSIVE][LockMode::INTENTION_SHARED] = false;
compatibility_matrix_[LockMode::EXCLUSIVE][LockMode::EXCLUSIVE] = false;
compatibility_matrix_[LockMode::EXCLUSIVE][LockMode::INTENTION_EXCLUSIVE] = false;
compatibility_matrix_[LockMode::EXCLUSIVE][LockMode::SHARED_INTENTION_EXCLUSIVE] = false;

compatibility_matrix_[LockMode::INTENTION_EXCLUSIVE][LockMode::SHARED] = false;
compatibility_matrix_[LockMode::INTENTION_EXCLUSIVE][LockMode::INTENTION_SHARED] = true;
compatibility_matrix_[LockMode::INTENTION_EXCLUSIVE][LockMode::EXCLUSIVE] = false;
compatibility_matrix_[LockMode::INTENTION_EXCLUSIVE][LockMode::INTENTION_EXCLUSIVE] = true;
compatibility_matrix_[LockMode::INTENTION_EXCLUSIVE][LockMode::SHARED_INTENTION_EXCLUSIVE] = false;
```



> 由于 `wait` 操作实际上是释放锁+挂起两个步骤，所以不用担心请求队列的 latch 出现死锁情况。而唤醒实际上也是执行一次获取锁的操作。

最后就是授予锁了，将对应锁请求的 `granted` 改为 `true`，并修改事务维护的相应锁集合。如果这是一次锁升级请求，则说明升级完成，还需要修改请求队列的 `upgrading` 变量。

### UnlockTable() / UnlockRow()

⚠<font color=red>***在实现解锁过程之前，务必反复阅读并理解头文件中的 Unlock Note。***</font>

解锁过程相比上锁过程简单许多，表锁和行锁的解锁流程也几乎一样，只是表锁在解锁时需要判断表中是否还有未解锁的行锁，其余一致。这里就先讲**表锁**的解锁流程。

首先判断锁是否存在，如果不存在，则抛出异常。

判断表中是否还有未解锁的行锁，如果有，则抛出异常。

接下来就是获取锁请求队列，根据 `txn_id` 找到事务对应的那个锁请求，从队列中移除，修改事务维护的相应锁集合，然后利用 `cv_.notify_all()` 通知所有挂起的线程。由于同一个事务在同一个表/行上最多仅能上一把锁，所以不会出现两个相同 `txn_id` 的请求。

## Task #2 - Deadlock Detection

死锁检测需要我们构建一个事务等待图，然后利用 DFS 算法检测环是否存在环，每次检测需打破所有环，并且 Aborted 环上 `txn_id` 最大的事务。

由于要求我们每次需从 `txn_id` 最小的事务开始执行 DFS，并且在挑选邻居的时候也要按照 `txn_id` 递增的顺序，所以进行 `wait_for` 等待图构建的时候，每次添加边都需要找到合适的位置进行插入。

另外，lab 要求我们在每次检测开始时进行图构建，检测完后再把图销毁，于是 `RunCycleDetection()` 函数就变成了

```cpp
void LockManager::RunCycleDetection() {
  while (enable_cycle_detection_) {
    std::this_thread::sleep_for(cycle_detection_interval);
    {
      waits_for_latch_.lock();
      MakeGraph();
      // cycle detection
      DestoryGraph();
      waits_for_latch_.unlock();
    }
  }
}
```

本 Task 的核心也显而易见，就是环检测算法了。

这里易错点比较多，首先是 Guide 中 `txn_id` 前面的形容词 youngest 和 lowest 就傻傻分不清，实际上 youngest 指的就是 `txn_id` 大，因为 `txn_manager` 中是按照事务 id 递增来生成事务的，所以 `txn_id` 越大必然就越"年轻"嘛~

第二，图上不一定只有一个连通分量，这是要小心的。

第三，图上也不一定只有一个环，而我们需要打破所有环，所以这里要用一个 `while` 循环。

其余的环路径的维护，点访问的去重，需要自己慢慢琢磨。

在选出 youngest transaction 之后，要将其 Abort，并且以 LockManager 的名义通知所有锁等待队列。本来应该只通知该事务相关的队列即可，但我图省事，就直接全部通知一遍。事务在收到通知后，首先检查自身 State，如果变成了 `ABORTED`，则把队列中自己的锁请求给移除，并且再一次通知队列中的其它事务。

> 这是因为排在后面的事务在被唤醒时可能先一步获取锁，检查前面所有锁兼容性失败后继续 wait，但实际上只要被 Aborted 的那个事务移除锁请求，后面事务就能获取锁了。

## Task #3 - Concurrent Query Execution

在 lab3 中实现的 3 个与真实物理页面打交道的算子 SeqScan，Insert，Delete 中加上锁。并且根据上述讨论提到的不同隔离级别的不同表现进行额外的判断，难度不大，略。

## 总结

本 lab 最大的收获就是理解了隔离级别以及锁类型之间的关系，以及死锁检测是如何进行的。
