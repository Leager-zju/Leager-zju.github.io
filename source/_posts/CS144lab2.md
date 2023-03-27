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

## Task 1: Translate between 64-bit indexes and 32-bit seqnos

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

> 有一个坑点在于，头文件中对 `WrappintInt32 - WrappingInt32` 的重载返回值为 `int64_t` 而非 `uint_64t`，这就导致上面的 `res` 在 `n = UINT32_MAX, isn = 0` 的时候出现计算错误，需要修改头文件。

执行以下命令进行测试

```bash
$ cd build
$ make format
$ make
$ ctest -R wrap
```

输出结果如下，通过测试

```c++
Test project .../CS144/build
    Start 1: t_wrapping_ints_cmp
1/4 Test #1: t_wrapping_ints_cmp ..............   Passed    0.00 sec
    Start 2: t_wrapping_ints_unwrap
2/4 Test #2: t_wrapping_ints_unwrap ...........   Passed    0.00 sec
    Start 3: t_wrapping_ints_wrap
3/4 Test #3: t_wrapping_ints_wrap .............   Passed    0.00 sec
    Start 4: t_wrapping_ints_roundtrip
4/4 Test #4: t_wrapping_ints_roundtrip ........   Passed    0.16 sec

100% tests passed, 0 tests failed out of 4

Total Test time (real) =   0.17 sec
```

## Task 2:  Implenting the TCP receiver

该 task 主要完成三件事

1. 从其对等方接收 TCPsegment；
2. 使用 `StreamReassembler` 重新整合字节流；
3. 计算确认号(ackno)和窗口大小，ackno 和窗口大小最终将在 TCPsegment 中传回对等方；

窗口大小很好理解，就是 lab1 中的 `capacity - ByteStream.buffer_size()`。

对于确认号而言，则对应的是"下一个希望接收到的 seqno"。已知标志位 `SYN` 和 `FIN` 也各占一个 seqno，则根据下面那张转换图，不难发现有

$$
\text{ackno} = wrap(\text{next\_index},\ \text{isn}) + 1 + \text{ByteStream.input\_ended()}
$$

<img src="2.png" style="zoom:67%;" />

其中，`ByteStream.input_ended()` 表示 `FIN=1` 的 segment 已完全写入 `ByteStream`。

> 需要注意的是，在收到第一个 `SYN=1` 的 segment 之前，ackno 应返回空值，表现为 `return std::optional<WrappintInt32>{}`。由于 isn 仅在 `SYN=1` 的 segment 到来时才会被正确初始化，故需要一个变量来表示 isn 是否被赋值。

最后就是接收 segment 的 api `segment_received(TCPsegment)` 了，该 api 主要工作就是将 segment 中的 IP 层数据包写入 Reassembler 中，难点在于流索引的计算。根据转换图可以得知

$$
\text{stream\_index} =
\begin{cases}
\qquad\qquad\qquad\qquad 0 \qquad\qquad\qquad\qquad \text{SYN}=1
\\[2ex]
unwrap(\text{seqno}, \text{isn}, \text{next\_index}) - 1 \qquad \text{else}
\end{cases}
$$

而写入的子串可通过 `segment.payload().copy()` 获取。其中 `payload()` 其实就是 IP 层数据包部分。

> 需要考虑的 corner case 比较多，比如仅仅 `SYN=1` / `FIN=1` 或两个标志位同时为 `1` 但无数据的情况。

执行以下命令进行测试

```bash
$ cd build
$ make format
$ make
$ make check_lab2
```

输出结果如下，通过测试

```c++
[100%] Testing the TCP receiver...
Test project .../CS144/build
      Start  1: t_wrapping_ints_cmp
 1/26 Test  #1: t_wrapping_ints_cmp ..............   Passed    0.00 sec
      Start  2: t_wrapping_ints_unwrap
 2/26 Test  #2: t_wrapping_ints_unwrap ...........   Passed    0.00 sec
      Start  3: t_wrapping_ints_wrap
 3/26 Test  #3: t_wrapping_ints_wrap .............   Passed    0.00 sec
      Start  4: t_wrapping_ints_roundtrip
 4/26 Test  #4: t_wrapping_ints_roundtrip ........   Passed    0.15 sec
      Start  5: t_recv_connect
 5/26 Test  #5: t_recv_connect ...................   Passed    0.00 sec
      Start  6: t_recv_transmit
 6/26 Test  #6: t_recv_transmit ..................   Passed    0.05 sec
      Start  7: t_recv_window
 7/26 Test  #7: t_recv_window ....................   Passed    0.00 sec
      Start  8: t_recv_reorder
 8/26 Test  #8: t_recv_reorder ...................   Passed    0.00 sec
      Start  9: t_recv_close
 9/26 Test  #9: t_recv_close .....................   Passed    0.00 sec
      Start 10: t_recv_special
10/26 Test #10: t_recv_special ...................   Passed    0.00 sec
      Start 18: t_strm_reassem_single
11/26 Test #18: t_strm_reassem_single ............   Passed    0.00 sec
      Start 19: t_strm_reassem_seq
12/26 Test #19: t_strm_reassem_seq ...............   Passed    0.00 sec
      Start 20: t_strm_reassem_dup
13/26 Test #20: t_strm_reassem_dup ...............   Passed    0.01 sec
      Start 21: t_strm_reassem_holes
14/26 Test #21: t_strm_reassem_holes .............   Passed    0.00 sec
      Start 22: t_strm_reassem_many
15/26 Test #22: t_strm_reassem_many ..............   Passed    0.21 sec
      Start 23: t_strm_reassem_overlapping
16/26 Test #23: t_strm_reassem_overlapping .......   Passed    0.00 sec
      Start 24: t_strm_reassem_win
17/26 Test #24: t_strm_reassem_win ...............   Passed    0.22 sec
      Start 25: t_strm_reassem_cap
18/26 Test #25: t_strm_reassem_cap ...............   Passed    0.08 sec
      Start 26: t_byte_stream_construction
19/26 Test #26: t_byte_stream_construction .......   Passed    0.00 sec
      Start 27: t_byte_stream_one_write
20/26 Test #27: t_byte_stream_one_write ..........   Passed    0.00 sec
      Start 28: t_byte_stream_two_writes
21/26 Test #28: t_byte_stream_two_writes .........   Passed    0.00 sec
      Start 29: t_byte_stream_capacity
22/26 Test #29: t_byte_stream_capacity ...........   Passed    0.38 sec
      Start 30: t_byte_stream_many_writes
23/26 Test #30: t_byte_stream_many_writes ........   Passed    0.01 sec
      Start 53: t_address_dt
24/26 Test #53: t_address_dt .....................   Passed    0.00 sec
      Start 54: t_parser_dt
25/26 Test #54: t_parser_dt ......................   Passed    0.00 sec
      Start 55: t_socket_dt
26/26 Test #55: t_socket_dt ......................   Passed    0.01 sec

100% tests passed, 0 tests failed out of 26

Total Test time (real) =   1.18 sec
[100%] Built target check_lab2
```