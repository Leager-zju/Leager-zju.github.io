---
title: CS144 lab2 TCP Receiver
author: Leager
mathjax: true
date: 2023-03-26 17:24:22
summary:
categories:
  - CS144
tags:
  - lab
img:
---

本 lab 需要实现 TCP 协议的接收端。

<!--more-->

<img src="1.png" style="zoom:67%;" />

> 依然是这张图

此时接受端收到的就是 `{TCP Header, IP Datagram}` 组成的报文段(TCP segment)了，该数据结构定义在 `/libsponge/tcp_helpers/tcp_segment.hh` 中，其中首部(TCP header)字段定义在 `/libsponge/tcp_helpers/tcp_header.hh` 中。

本 lab 的难点在于如何进行序列号和流索引的转换，guide 中其实已经说的比较详细了

<img src="2.png" style="zoom:67%;" />

## Task 1

第一个任务是编写用于 `seqno` 与 `absolute seqno` 互相转换的 `wrap()` 与 `unwrap()` 函数。

### wrap(n, isn)

给定 `isn` 和绝对序列号 `n`，求相应的序列号，易得

$$
seqno = (isn + n\ \&\ \text{uint32\_max})\ \%\ \text{uint32\_max}
$$

### unwrap(n, isn, checkpoint)

给定序列号 `n` 和 `isn`，以及用于消除多义性的检查点 `checkpoint`，求距离 `checkpoint` 最近的绝对序列号。显然，最后的结果应该为

$$
abs\_seqno = n - isn + i\times offset,\quad offset = 2^{32}, \ i \in [0, 2^{32}-1]
$$

如果将 `checkpoint` 分为高 32 位与低 32 位，那么 `checkpoint` 必然能表示为 $\text{high32}\times offset + \text{low32}$

从而存在三种绝对序列号可能，分别为 `i = high32-1, high32, high32+1`

1. 如果 `n-isn < low32`，则 `i` 取 `high32-1, high32`；
2. 如果 `n-isn == low32`，则 `i` 取 `high32`；
3. 如果 `n-isn > low32`，则 `i` 取 `high32, high32+1`；

不难发现，令 `i = high32` 一定是可能的选择之一，但还有一些边界条件需要考虑：

1. 如果 `high32 == 0`，那么 case1 下 `high32-1` 无法取得；
2. 如果 `high32 == 11..11`，那么 case3 下 `high32+1` 无法取得；

故得到

```c++
uint64_t unwrap(WrappingInt32 n, WrappingInt32 isn, uint64_t checkpoint) {
  uint64_t c_high32 = checkpoint >> 32;
  uint64_t offset = 1ul << 32;
  uint64_t lower_bound = 1ul << 32;
  uint64_t upper_bound = (lower_bound-1) << 32;
  uint64_t res = static_cast<uint64_t>(n - isn) + (c_high32 << 32);

  if (res > checkpoint) {
    if (res > lower_bound && res - checkpoint >= offset >> 1) {
      res -= offset;
    }
  } else if (res < checkpoint){
    if (res < upper_bound && checkpoint - res >= offset >> 1) {
      res += offset;
    }
  }

  return res;
}
```