---
title: CS144 lab Note
author: Leager
mathjax:
  - true
date: 2023-03-21 18:28:52
summary:
categories: lab
tags:
  - CS144
img:
---

CS144 lab 记录过程。

<!--more-->

## 环境配置

本课程所有 lab 均需要在 Linux 环境下运行，课程组提供了 4 种运行方式，直接照着 [Instructions](https://stanford.edu/class/cs144/vm_howto/) 来就好了。我这里因为实验室自带 Ubuntu 工作站，所以用了第三种方式，按照清单一个个 `sudo apt-get install` 下来就完事了。

## lab0 Networking Warmup

之前有用 http 访问某网站并获取文本、用 smtp 发邮件的一些小操作，跟着走一遍基本没啥问题，就是熟悉一下基本的命令。现在要真正上手敲 C++ 了。

### 准备工作

首先是把代码拉下来，我先在自己的 github 下[新建](https://github.com/new)了一个仓库，命名为 **CS144**，为了尊重课程协议，我设为了 `private`。拉代码就直接 `git clone --bare https://github.com/CS144/sponge.git`，后面所有的 lab 都是在这一套文件下实现的。

随后，执行

```bash
$ cd your_repository_name
$ git push git@github.com:your_github_name/your_repository_name.git --all
```

此时课程代码及其所有分支已经移植到我们自己的仓库里了，接着 `cd .. && rm -rf sponge` 将课程仓库删除，最后把我们自己的仓库拉下来即可。

```bash
## If you pull / push over HTTPS
$ git clone https://github.com/your_github_name/your_repository_name.git

## If you pull / push over SSH
$ git clone git@github.com:your_github_name/your_repository_name.git
```

可以输入 `git remote -v` 查看本地与远程是否对应。ok，现在可以将所有更改 push 到自己的代码仓库里了。

### coding

> 课程 lab 代码仓库一共有 8 个分支，每个 lab 前都需要 `git merge lab?-startercode` 来合并分支。

执行如下命令构建项目

```bash
$ mkdir build
$ cd build
$ cmake ..
$ make
```

我们的代码要写在 `/apps/webget.cc` 里的 `Your code here` 处。写之前要认真看看 `socket.hh`，`address.hh`，`file_descriptor.hh` 这三个头文件，尽管本 lab 要用到的类只有 `TCPSocket` 和 `Address` 这俩。

`Address` 类决定了连接的目标 host 以及协议类型，这里应为 `Address(host, "http")`。

`TCPSocket` 提供了 `write(string)` 方法，等效于在 terminal 输入相应的命令；`read()` 方法则返回获取到的字节流；`eof()` 方法判断是否抵达字节流末尾。

> 注意，每一行末尾都要加上 `'\r\n'`，最后的 `Connection: close` 后要加两个这玩意。
>
> 注意，请用 while(!socket.eof()) 来循环读字节流，而非 single call to read。

写完代码后，可以执行如下命令来检查输出结果：

``` bash
$ cd build
$ ./apps/webget cs144.keithw.org /hello ## 可执行文件, host, path
```

如果看到结果如下，则输出正确。

```
HTTP/1.1 200 OK
Date: Tue, 21 Mar 2023 10:16:57 GMT
Server: Apache
Last-Modified: Thu, 13 Dec 2018 15:45:29 GMT
ETag: "e-57ce93446cb64"
Accept-Ranges: bytes
Content-Length: 14
Connection: close
Content-Type: text/plain

Hello, CS144!
```

最后用课程组给的测试代码进行跑分:

``` bash
$ cd build
$ make check_webget
```

看到如下输出，则通过。

```bash
[100%] Testing webget...
Test project .../CS144/build
    Start 31: t_webget
1/1 Test #31: t_webget .........................   Passed    6.05 sec

100% tests passed, 0 tests failed out of 1

Total Test time (real) =   6.05 sec
[100%] Built target check_webget
```

### An in-memory reliable byte stream

lab0 的最后一个任务是实现一个处理字节流的有限容量 buffer，writer 负责将字节流写入 buffer 中，reader 从中读取。文件位于 `libsponge/byte_stream.cc` 以及 `libsponge/byte_stream.hh`。

writer 的工作很简单，写数据(write)、终止写入(end_input)以及获取 buffer 剩余容量(remaining_capacity)，需要注意的是如果写入的数据大小超过了剩余容量，则应尽可能写入，比如剩余容量 3 的情况下要写 `"abcdefg"`，则只写入 `"abc"`。

reader 有三种输出方式，只读(peek_output)，只写(pop_output)以及读写(read_output)，注意后两种方法都意味着增加**已读取的字节数**。

以及一些通用的接口，这些接口的实现需要我们额外添加一些 private 成员变量，不再赘述。这里课程组已经为我们提供了一个名为 `BufferList` 的数据结构

执行以下命令进行测试：

```bash
$ cd build
$ make format
$ make
$ make check_lab0
```

测试结果如下。

```bash
[100%] Testing Lab 0...
Test project .../CS144/build
    Start 26: t_byte_stream_construction
1/9 Test #26: t_byte_stream_construction .......   Passed    0.00 sec
    Start 27: t_byte_stream_one_write
2/9 Test #27: t_byte_stream_one_write ..........   Passed    0.00 sec
    Start 28: t_byte_stream_two_writes
3/9 Test #28: t_byte_stream_two_writes .........   Passed    0.00 sec
    Start 29: t_byte_stream_capacity
4/9 Test #29: t_byte_stream_capacity ...........   Passed    0.36 sec
    Start 30: t_byte_stream_many_writes
5/9 Test #30: t_byte_stream_many_writes ........   Passed    0.02 sec
    Start 31: t_webget
6/9 Test #31: t_webget .........................   Passed    3.45 sec
    Start 53: t_address_dt
7/9 Test #53: t_address_dt .....................   Passed    0.01 sec
    Start 54: t_parser_dt
8/9 Test #54: t_parser_dt ......................   Passed    0.00 sec
    Start 55: t_socket_dt
9/9 Test #55: t_socket_dt ......................   Passed    0.01 sec

100% tests passed, 0 tests failed out of 9

Total Test time (real) =   3.86 sec
[100%] Built target check_lab0
```

## lab1 Stream Reassembler

本 lab 要求在 lab0 的基础上实现一个字节流整合器。

<img src="1.png" style="zoom:67%;" />

lab1 ~ lab4 均围绕此图进行。在 lab0 中，我们实现了有序字节流，而事实上真实的网络并不会按顺序向我们发送数据包，我们需要利用一个整合器将收到的无序字节流片段以正确顺序拼接并写到 `ByteStream` 中。数据包以 `{data, index}` 的形式被接收，其中 `data` 为 `std::string`，`index` 为 `data` 作为子串在原始字节流中的下标，如

```cpp
                     1         2
           01234567890123456789012345
原始字符串: abcdefghijklmnopqrstuvwxyz...

收到的数据包可能为 {"abc", 0}, {"efghij", 4} 等
```

一旦整合器收到了正确的数据包（需要我们维护一个 `next_index`），它就会将其写入 `ByteStream`；而那些顺序错乱的，整合器会将其缓存，但丢弃那些超过 `capacity` 的部分。关于 `capacity`，guide 里有了一个比较明确的介绍：

<img src="2.png" style="zoom:67%;" />

> 即 `ByteStream` 中未读取的部分加上 `Reassembler` 中无序的部分大小不能超过 `capacity`。

一些注意事项都写在 FAQ 里了：

### 数据结构设计

本来想用 `std::vector<char>` 模拟循环队列的，但实际操作起来发现开销奇高，后来决定用 `std::map<uint32_t, std::string>` 的索引表的方式，记录每个字符串及其索引，并做好去重工作。每次收到一个 `{index, data}` 对时，遍历索引表，如果有重复的部分，则修改 `data` 的有效字节区间，并进行适当插入。完成插入操作后，不断判断 `table.find(next_index)` 是否有效，若有效则删除条目并将对应字符串拼接至返回结果末尾。

> 有点像 `map reduce`，然后我的函数签名就是 map 和 reduce 了。

需要注意的是，收到的子串并非每个字符都要写入，我们要写入的部分应为

`[max(index, next_index), min(next_index + capacity - ByteStream.buffer_size(), index + data.length())]`

这样就能忽略已写入 `ByteStream` 的部分以及超出 `capacity` 的部分。

> 上面的索引为流索引，还需要转换为数组下标。

需要注意的是，当收到一个 `eof = true` 的 `{index, data}` 对时，可能并不会立刻 `end_input`，而是在后续的 reduce 阶段收集到所有字节流再 `end_input`，这就需要我们存一个 `eof_index` 变量，当 `next_index == eof_index` 时进行 `end_input`。

部分代码如下所示：

```cpp libsponge/stream_reassembler.cc
void StreamReassembler::map(const std::string &data, const uint64_t index) {
  if (data.empty()) {
    return;
  }
  // 只取 data 的 [start_index, last_index) 区间
  size_t start_index = max(index, _next_index);
  size_t last_index = min(_next_index + _capacity - _output.buffer_size(), index + data.length());

  for (auto &&entry : _buffer) {
    if (start_index >= last_index) {
      return;
    }
    size_t end_index = entry.first + entry.second.length();
    if (entry.first > start_index) {
      if (last_index <= entry.first) {
        _buffer.emplace(make_pair(start_index, data.substr(start_index - index, last_index - start_index)));
        start_index = last_index;
        break;
      } else {
        _buffer.emplace(make_pair(start_index, data.substr(start_index - index, entry.first - start_index)));
        start_index = end_index;
      }
    } else {
      start_index = max(start_index, end_index);
    }
  }
  // 仍有有效部分
  if (start_index < last_index) {
    _buffer.emplace(make_pair(start_index, data.substr(start_index - index, last_index - start_index)));
  }
}

void StreamReassembler::reduce() {
  std::string res;
  while (_buffer.count(_next_index)) {
    auto entry = _buffer.find(_next_index);
    res.append(entry->second);
    _next_index += entry->second.length();
    _size -= entry->second.length();
    _buffer.erase(entry);
  }
  if (!res.empty()) {
    _output.write(res);
  }
  if (_next_index == _eof_index) {
    _output.end_input();
  }
}
```

测试结果如下。

```bash
[100%] Testing the stream reassembler...
Test project .../CS144/build
      Start 18: t_strm_reassem_single
 1/16 Test #18: t_strm_reassem_single ............   Passed    0.00 sec
      Start 19: t_strm_reassem_seq
 2/16 Test #19: t_strm_reassem_seq ...............   Passed    0.00 sec
      Start 20: t_strm_reassem_dup
 3/16 Test #20: t_strm_reassem_dup ...............   Passed    0.01 sec
      Start 21: t_strm_reassem_holes
 4/16 Test #21: t_strm_reassem_holes .............   Passed    0.00 sec
      Start 22: t_strm_reassem_many
 5/16 Test #22: t_strm_reassem_many ..............   Passed    0.20 sec
      Start 23: t_strm_reassem_overlapping
 6/16 Test #23: t_strm_reassem_overlapping .......   Passed    0.00 sec
      Start 24: t_strm_reassem_win
 7/16 Test #24: t_strm_reassem_win ...............   Passed    0.20 sec
      Start 25: t_strm_reassem_cap
 8/16 Test #25: t_strm_reassem_cap ...............   Passed    0.08 sec

...

100% tests passed, 0 tests failed out of 16

Total Test time (real) =   1.77 sec
[100%] Built target check_lab1
```

## lab2 TCP Receiver

本 lab 需要实现 TCP 协议的接收端。

此时接受端收到的就是 `{TCP Header, IP Datagram}` 组成的报文段(TCP segment)了，该数据结构定义在 `/libsponge/tcp_helpers/tcp_segment.hh` 中，其中首部(TCP header)字段定义在 `/libsponge/tcp_helpers/tcp_header.hh` 中。

### Task 1: Translate between 64-bit indexes and 32-bit seqnos

第一个任务是编写用于 `seqno` 与 `absolute seqno` 互相转换的 `wrap()` 与 `unwrap()` 函数。guide 中其实已经说的比较详细了。

<img src="3.png" style="zoom:67%;" />

#### wrap(n, isn)

给定 `isn` 和绝对序列号 `n`，求相应的序列号，易得

$$
seqno = (isn + n\ \&\ \text{uint32_max})\ \%\ \text{uint32_max}
$$

#### unwrap(n, isn, checkpoint)

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

```cpp libsponge/wrapping_integers.cc
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

### Task 2:  Implenting the TCP receiver

该 task 主要完成三件事

1. 从其对等方接收 TCPsegment；
2. 使用 `StreamReassembler` 重新整合字节流；
3. 计算确认号(ackno)和窗口大小，ackno 和窗口大小最终将在 TCPsegment 中传回对等方；

窗口大小很好理解，就是 lab1 中的 `capacity - ByteStream.buffer_size()`。

对于确认号而言，则对应的是"下一个希望接收到的 seqno"。已知标志位 `SYN` 和 `FIN` 也各占一个 seqno，则根据下面那张转换图，不难发现有

$$
\text{ackno} = wrap(\text{next\_index},\ \text{isn}) + 1 + \text{ByteStream.input\_ended()}
$$

<img src="3.png" style="zoom:67%;" />

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

测试结果如下。

```bash
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

...

100% tests passed, 0 tests failed out of 26

Total Test time (real) =   1.18 sec
[100%] Built target check_lab2
```

## lab3 TCP Sender

本 lab 需要实现 TCP 协议的发送端。

### 数据结构

一个 TCPSender 应该完成以下事情：

1. 跟踪接收方的窗口（处理传入的 ackno 和窗口大小）；
2. 尽可能填充窗口，方法是从 ByteStream 读取，创建新的 TCP 段（如果需要，包括 SYN 和 FIN 标志），然后发送它们。发送方应继续发送段，直到窗口已满或 ByteStream 为空；
3. 跟踪哪些段已发送但尚未被接收方确认——我们称这些为"未完成"的段；
4. 如果自发送以来经过了足够长的时间且尚未确认，则重新发送最早未完成的段；

这就需要我们添加一系列成员变量，我的数据结构设计如下：

```cpp libsponge/tcp_sender.cc
class TCPSender {
 private:
  // (new!) 定时器
  Timer _timer{};
  //! our initial sequence number, the number for our SYN.
  WrappingInt32 _isn;
  //! outbound queue of segments that the TCPSender wants sent
  std::queue<TCPSegment> _segments_out{};
  // (new!) 发送但尚未被确认的段队列，每发送一个段，都会将其副本添加到该队列中
  // 每收到一个正确的确认，都会将队首弹出
  std::queue<TCPSegment> _outstanding_segments{};
  //! retransmission timer for the connection
  unsigned int _initial_retransmission_timeout;
  // (new!) 重传时限
  unsigned int _rto;
  // (new!) 重传次数
  uint16_t _retransmission_times{0};
  //! outgoing stream of bytes that have not yet been sent
  ByteStream _stream;
  //! the (absolute) sequence number for the next byte to be sent
  uint64_t _next_seqno{0};
  // (new!) 确认号(绝对序列号)
  uint64_t _ackno{0};
  // (new!) 接收侧的窗口大小
  uint64_t _rws{1};
  // (new!) 是否已发送 FIN=1 的段
  bool closed{false};
}
```

### 定时功能

这是本 lab 的第一个任务。随着时间流逝，如果最早发送的段在一定时间内未得到确认，则需要进行**超时重传**，而定时器的作用就是告诉 sender "超时了"，它应该有以下功能：

1. `start()`，包括设置 rto 以及重置时间进度为 0，并将定时器状态设为 `WORK`；

  ```cpp libsponge/tcp_sender.cc
  void Timer::start(unsigned int rto) {
    _rto = rto;
    _current_time = 0;
    _state = TimerState::WORK;
  }
  ```

2. `stop()`，将定时器状态设为 `IDLE`；

  ```cpp libsponge/tcp_sender.cc
  void Timer::stop() {
    _state = TimerState::IDLE;
  }
  ```

3. `tick()`，增加时间进度，并在超过 rto 时向调用者传递信息(true/false)；

  ```cpp libsponge/tcp_sender.cc
  bool Timer::tick(unsigned int interval) { // true for timeout, false else
    _current_time += interval;
    return _current_time >= _rto;
  }
  ```

根据 guide，`TCPSender::tick()` 会被自动调用，其传入参数为距离上一次调用该方法经过的时长，那么在 `TCPSender::tick()` 中，我们就需要调用 `Timer::tick()` 并根据返回值判断是否需要重传。重传时需要做的事有：

1. 重传尚未被 TCP 接收方**完全确认**的最早的段（如果没有的话后面啥也不用做）；
2. 如果窗口大小不为零：
   - **增加连续重传的次数**：因为重传次数对应的就是最早未确认的段，故无需建立 `序列号->重传次数` 的映射;
   - **指数退避**：将 RTO 翻倍，从而减慢糟糕网络上的重传速度，以避免进一步破坏工作；
3. 重启定时器，使其在 RTO 后到期；

故 `TCPSender::tick()` 部分代码很容易能写出来

```cpp libsponge/tcp_sender.cc
void TCPSender::tick(const size_t ms_since_last_tick) {
  if (!_outstanding_segments.empty() && _timer.tick(ms_since_last_tick)) {
    if (_rws != 0) {
      _retransmission_times++;
      _rto *= 2;
    }
    if (_retransmission_times <= TCPConfig::MAX_RETX_ATTEMPTS) {
      segments_out().push(_outstanding_segments.front());
      _timer.start(_rto);
    }
  }
}
```

### 收到确认后要做什么

当收到一个正确的 ackno 时：

1. 将 RTO 设置回其"初始值"（即 `_initial_retransmission_timeout`）；
2. 如果发送方有任何未完成的数据，重启定时器，使其在 RTO 毫秒（对于 RTO 的当前值）后到期；
3. 反之，如果所有未完成的数据都被确认，停止定时器；
4. 将重传次数重置为零；

怎样算正确的 ackno 呢？对于一个段而言，当且仅当下式满足时，该段被成功确认。

$$
\text{abs_ackno} \geq \text{abs_seqno} + \text{length_in_sequence_space}
$$

> 也就是说，只有部分确认的段依然被认为是"完全未确认"。

与此同时，还应满足 $\text{abs_ackno}\leq \text{abs_next_seqno}$，否则会被认为是无效确认号。

```cpp libsponge/tcp_sender.cc
bool TCPSender::ack_received(const WrappingInt32 ackno, const uint16_t window_size) {
  uint64_t abs_ackno = unwrap(ackno, _isn, _next_seqno);
  if (abs_ackno > _next_seqno || abs_ackno < _ackno) {
    return false;
  }
  bool flag{false};
  _ackno = abs_ackno;  // abs ackno
  _rws = window_size;
  while (!_outstanding_segments.empty()) {
    TCPSegment &seg = _outstanding_segments.front();
    size_t seq_length = seg.length_in_sequence_space();
    if (seg.header().seqno + seq_length > ackno) {
      break;
    }
    flag = true;
    _outstanding_segments.pop();
  }

  if (flag) {
    _rto = _initial_retransmission_timeout;
    _outstanding_segments.empty() ? _timer.stop() : _timer.start(_rto);
    _retransmission_times = 0;
  }

  return flag;
}
```

### 如何发送段

可以简单地认为，将 segment 插入 `_segments_out` 队列中就算将它发出去了。

但事实上，原始代码里并没有修改 segment 首部和负载字段的 api，需要修改头文件，加上几个 `set_syn()`，`set_fin()` 之类的，方便正确创建段。

最开始(abs_next_seqno=0)的时候，由于尚未建立连接，`_rws` 字段会被初始化为 1 而非 0，此时要发送的段仅仅为 `{SYN=1, data=""}` 的同步请求段。在收到确认之后，`_rws` 字段会被重置，我们就需要发送数据以尽可能填满该窗口，同时数据大小又不能超过 `TCPConfig::MAX_PAYLOAD_SIZE`。

已经发过的数据部分在未超时的情况下不用重复发送，那么理论上 `ackno` 会小于等于 `next_seqno`，而我们之后要发的数据部分应从 `next_seqno` 部分开始，于是乎这里就有了**发送窗口**的概念，即

$$
\text{send_window_size} = \text{abs_ackno} + \text{_rws} - \text{abs_next_seqno}
$$

这里需要注意的点是，`send_window_size` 指的是还可以发送多少序列号，而 `TCPConfig::MAX_PAYLOAD_SIZE` 指明了数据部分的字符数量，这两者的区别影响了是否需要在发送端的 `ByteStream` 数据读完后将 `FIN` 设置为 `1`。

> 如果 `ByteStream` 已经 eof 且 `data.length() < send_window_size`，说明还能容纳一个 `FIN` 的序列号，此时应当将 `FIN` 设为 `1`。很可能的一个情况是剩下的数据刚好有 `TCPConfig::MAX_PAYLOAD_SIZE` 这么多，而 `send_window_size` 恰好为 `TCPConfig::MAX_PAYLOAD_SIZE+1` 甚至更多，那么不加 `FIN` 是不合适的，违背了**尽可能填满**的规则。

关于 `FIN` 还有个坑点，就是收到对 `{FIN=1}` 段的确认后，很可能依然满足发 `FIN` 段的要求，从而源源不断地发送，这就需要有一个变量来记录是否已经发过 `FIN` 段了，也就是上文中提到的 `TCPSender::close` 变量。

由于数据有大小上限，那么极有可能出现 `ByteStream` 还有大量数据，`_rws` 也还很大的情况，单独发一个 `TCPConfig::MAX_PAYLOAD_SIZE` 的段远远不够"填满"，此时要利用循环来不断尝试直至只能生成空段。

最后实现如下：

```cpp libsponge/tcp_sender.cc
void TCPSender::fill_window() {
  if (_timer.state() == TimerState::IDLE) {
    _timer.start(_rto);
  }

  while (true) {
    bool syn{false};
    bool fin{false};
    std::string data;

    if (in_closed()) { // 尚未发过 seg
      syn = true;
    } else {
      size_t read_size = min(send_window_size(), TCPConfig::MAX_PAYLOAD_SIZE);
      data = stream_in().read(read_size);

      if (!fin_sent && stream_in().eof() && data.length() < send_window_size()) {
        fin = true;
        fin_sent = true;
      }
    }

    TCPSegment seg = TCPSegment{}.with_syn(syn).with_fin(fin).with_data(std::move(data)).with_seqno(next_seqno());
    size_t seq_length = seg.length_in_sequence_space();
    if (seq_length == 0) {
      break;
    }
    _segments_out.push(seg);
    _outstanding_segments.push(seg);
    _next_seqno += seq_length;
  }
}
```

测试结果如下。

```bash
[100%] Testing the TCP sender...
Test project .../CS144/build

...

      Start 11: t_send_connect
11/33 Test #11: t_send_connect ...................   Passed    0.00 sec
      Start 12: t_send_transmit
12/33 Test #12: t_send_transmit ..................   Passed    0.09 sec
      Start 13: t_send_retx
13/33 Test #13: t_send_retx ......................   Passed    0.00 sec
      Start 14: t_send_window
14/33 Test #14: t_send_window ....................   Passed    0.06 sec
      Start 15: t_send_ack
15/33 Test #15: t_send_ack .......................   Passed    0.00 sec
      Start 16: t_send_close
16/33 Test #16: t_send_close .....................   Passed    0.00 sec
      Start 17: t_send_extra
17/33 Test #17: t_send_extra .....................   Passed    0.00 sec

...

100% tests passed, 0 tests failed out of 33

Total Test time (real) =   1.30 sec
[100%] Built target check_lab3
```

## lab4 TCP Connection

本 lab 可以说是最难搞的一个了，我们需要结合 lab2 和 lab3 来实现一个真实的 TCP 协议，协调 sender 和 receiver 的所有操作，并完成三次握手和四次挥手。

## 发送

什么时候要发送报文段？这是值得思考的一个问题，总的来说有以下几种情况是需要发送的：

1. 主动向服务器发起连接请求。此时会发送一个 `SYN=1` 的段；
2. 收到一个至少占据一个序列号的段。此时我们**应尽可能**发送一个 ack 段，即便是不占序列号的空段；
3. 调用 `tick()` 引发超时重传。此时如果超过最大重传次数，则转而发送一个 `RST=1` 的段；
4. 上层写入字节流。此时接收窗口可能足够大，只是没数据，一旦数据到了，就应立即调用 `sender.fill_window()` 并发送段；
5. 上层停止写入，即调用 `end_input_stream()`。此时可能还有空闲窗口让我们能够发送 `FIN=1` 的段，毕竟结束符也占一个序列号；
6. 对象调用析构函数，但连接仍未终止。此时也需要发送一个 `RST=1` 的段；

发送操作很简单，`sender` 调用相应函数然后从 `segment_out` 中取出来再插到发送队列即可。

```cpp libsponge/tcp_connection.cc
while (!_sender.segments_out().empty()) {
  TCPSegment &seg = _sender.segments_out().front();
  auto ackno = _receiver.ackno();
  if (ackno.has_value()) { // 说明 receiver 至少进入了 SYN_RECV 阶段
    seg.with_ack(true).with_ackno(ackno.value());
  }
  seg.with_win(_receiver.window_size());
  if (seg.header().ack || seg.length_in_sequence_space() != 0) {
    segments_out().push(seg);
  }
  _sender.segments_out().pop();
}
```

## 接收

接收是一个比较麻烦的事情，有一个细节是连接处于 `LISTEN` 阶段时只处理 `SYN=1` 的段，也就是会忽略 `RST=1` 段。

```cpp libsponge/tcp_connection.cc
if (_receiver.in_listen() && _sender.in_closed()) {
  if (!seg.header().syn) {
    return;
  }
  _receiver.segment_received(seg);
  connect();
  return;
}
```

其他时候，如果收到（或发送） `RST=1` 段后，会引发 `unclean_shutdown`。

```cpp libsponge/tcp_connection.cc
void TCPConnection::unclean_shutdown() {
  if (_active) {
    // cerr << "[unclean_shutdown]\n\n";
    _sender.stream_in().set_error();
    _receiver.stream_out().set_error();
    _active = false;
  }
}
```

除了上面这两种情况，剩下的时候都是正常对段进行接收处理，如果是 ack 段（事实上大部分都是 ack 段）还需要更新 sender。receiver 在收到段后，状态很有可能发生改变，一旦输入流结束，但是输出流尚未到达 eof，说明这一方是被动关闭，后续输出流结束，发出 `FIN=1` 并收到 ack 后可以直接关闭，因为这必然能确保另一方已经收到了 `FIN=1`（但不能保证对方知道自己收到了 ack）。

反之，说明输出流先结束，是主动结束连接的一方，此时在后续收到对方的 `FIN=1` 并发出 ack 后，不能立刻关闭连接，而是需要等待 10 倍的重传时限后才关闭连接，因为一旦对方没收到 ack，会对 `FIN=1` 进行重传，如果 `10*timeout` 内再也没收到 `FIN=1`，则可以视为对方收到，此时才能进行关闭。

变量 `_linger_after_streams_finish` 就是用于标识哪一方需要等待 `10*timeout` 才关闭。

```cpp libsponge/tcp_connection.cc
// after receive a segment
if (_receiver.stream_out().input_ended() && !_sender.stream_in().eof()) {
  _linger_after_streams_finish = false;
}
...
// anytime need check if shutdown
if (_receiver.in_fin_recv() && _sender.in_fin_acked() &&
  (!_linger_after_streams_finish || _time_since_last_segment_received >= 10 * _cfg.rt_timeout)) {
  clean_shutdown();
}
```

总的来说难度在于许多测试并没有给出具体的测试样例，而是模拟了真实的网络环境。唯一一个让我 de 了好多天 bug 的是 timeout 我一开始写成了默认时限，也就是 1s，而测试的时限是 10s，就导致了绝大多数测试 **TimeOut**，后来改成 `cfg.rt_timeout` 才过。

另外不知道什么原因，在到 `t_ipv4_client_send` 这样的测试之后都因为服务器网络不可达的原因收不到任何回复，所以后面基本都 Failed 了，这也是一个比较遗憾的地方。

> 如果遇到像 `... neq ... or ...` 这样的报错，需要把所有 `cerr` 注释掉才正常通过。因为这里是将输出结果写到文件里，然后和标准结果文件进行哈希值比较。

## lab5 Network Interface

本 lab 要求我们实现路由器的接口部分，负责维护目的 IP 地址到 MAC 地址的映射，并将 IP 层数据包转发到下一跳。

> lab5 lab6 都很简单，一下午就都搞定了。

### 发送

当转发数据包时，目的 IP 地址是已知的（就是**下一跳**），但对于链路层的 MAC 地址则可能未知，这就需要我们广播一个目的 MAC 地址为 `ff:ff:ff:ff:ff:ff` 的 ARP 请求来获取位于目的 IP 地址的设备的 MAC 地址。发送后，`{datagram, next_hop}` 会被缓存直至收到 ARP 答复。如果对目的 IP 地址的请求在 5s 内已经被发过一次，则只需等待答复即可，不用再发一遍。如果目的 MAC 地址已知，那事情就简单很多，直接将数据包包装成链路层帧发送即可。复杂点在于各个字段要完全设置好。

> 包装操作应使用 `serialize()` 方法转换为 `string`，再隐式转换为 `Buffer`。

```cpp libsponge/network_interface.cc
void NetworkInterface::send_datagram(const InternetDatagram &dgram, const Address &next_hop) {
  const uint32_t next_hop_ip = next_hop.ipv4_numeric();
  uint32_t next_ipv4_addr = next_hop.ipv4_numeric();

  EthernetFrame frame;
  if (_mp.count(next_ipv4_addr)) { // 目的 MAC 地址已知
    EthernetAddress next_ethernet_addr = _mp[next_ipv4_addr];
    // make frame
  } else {
    // 广播 ARP
    if (_time_since_last_send.count(next_hop_ip) && _time_since_last_send[next_hop_ip] <= 5000) {
      return;
    }
    _time_since_last_send[next_hop_ip] = 0;
    // make frame
    // 这里有一个坑点，ARPMessage 的目的 MAC 地址为空，因为帧头处已经设置为广播地址 ff:ff:ff:ff:ff:ff

    _waiting_for_arp_reply.push(make_pair(dgram, next_hop));
  }

  _frames_out.push(frame);
}
```

### 接收

当收到帧时，首先判断这是否为正常的数据交互，若是，则将其有效负载解析为数据包，作为返回值交付给调用者。

反之，检查这是一个 ARP 请求还是 ARP 答复。如果是前者，并其目的 IP 地址是否与自身一致，则发回一个 ARP 答复；反之，发送等待答复的数据包。同时，还要根据发送方的信息更新 IP/MAC 映射表，对应条目保持 30s，时间到后删除条目。

```cpp libsponge/network_interface.cc
optional<InternetDatagram> NetworkInterface::recv_frame(const EthernetFrame &frame) {
  const EthernetHeader &f_header = frame.header();
  if (f_header.dst != _ethernet_address && f_header.dst != ETHERNET_BROADCAST) {
    // 说明发错人了，直接不处理
  } else if (f_header.type == EthernetHeader::TYPE_IPv4) {
    InternetDatagram dgram;
    ParseResult parse_res = dgram.parse(frame.payload());
    if (parse_res == ParseResult::NoError) {
      // 成功解析则返回，否则丢弃
      return optional<InternetDatagram>{dgram};
    }
  } else if (f_header.type == EthernetHeader::TYPE_ARP) {
    ARPMessage msg;
    ParseResult parse_res = msg.parse(frame.payload());
    if (parse_res == ParseResult::NoError) {
      _mp.emplace(make_pair(msg.sender_ip_address, msg.sender_ethernet_address));
      _holding_time.emplace(make_pair(msg.sender_ip_address, 0));

      if (msg.target_ip_address == _ip_address.ipv4_numeric()) {
        if (msg.opcode == ARPMessage::OPCODE_REQUEST) {
          EthernetFrame reply;
          // make reply
          _frames_out.push(reply);
        } else if (msg.opcode == ARPMessage::OPCODE_REPLY) {
          send_datagram(_waiting_for_arp_reply.front().first, _waiting_for_arp_reply.front().second);
          _waiting_for_arp_reply.pop();
        }
      }
    }
  }

  return {};
}
```

测试结果如下。

```bash
Testing Lab 5...
Test project .../CS144/build
    Start 31: t_webget
1/2 Test #31: t_webget .........................   Passed    1.22 sec
    Start 32: arp_network_interface
2/2 Test #32: arp_network_interface ............   Passed    0.01 sec

100% tests passed, 0 tests failed out of 2

Total Test time (real) =   1.24 sec
Built target check_lab5
```

## lab6 Router

本 lab 要求我们实现路由表中的最长前缀匹配。路由表我采用的是 `std::unordered_map<uint32_t, std::tuple<uint8_t, std::optional<Address>, size_t>>`，存储 `route_prefix -> {prefix_length, next_hop, interface_num}` 的映射对。

有以下注意点：

1. 当需要转发的数据包的 `ttl <= 1` 时，丢弃，反之，将其减一；
2. 一般有一个默认网关为 `0.0.0.0/0`，如果将一个 32 位整数移位 32 位是未定义行为，需要考虑到这种情况；
3. 数据包必然是能发出去的，实在没有匹配到的也会发至默认网关，如果有其他匹配的网段可能是 direct 直达的，此时 `next_hop` 不一定有值，此时将发送的下一跳设置为数据包的 `dst ip_addr` 即可；

```cpp libsponge/router.cc
void Router::route_one_datagram(InternetDatagram &dgram) {
  if (dgram.header().ttl-- <= 1) {
    return;
  }

  uint8_t longest_match_length{0};
  uint32_t ipv4_addr = dgram.header().dst;
  optional<Address> next_hop{};
  size_t interface_num{0};

  for (auto &&entry : _route_table) {
    // find Longest-Match Prefix
  }

  if (next_hop.has_value()) {
    _interfaces[interface_num].send_datagram(dgram, next_hop.value());
  } else {
    // 可直接发送至目的 IP 地址
    _interfaces[interface_num].send_datagram(dgram, Address::from_ipv4_numeric(ipv4_addr));
  }
}
```

测试结果如下。

```bash
[100%] Testing Lab 6...
Test project .../CS144/build
    Start 32: arp_network_interface
1/2 Test #32: arp_network_interface ............   Passed    0.00 sec
    Start 33: router_test
2/2 Test #33: router_test ......................   Passed    0.02 sec

100% tests passed, 0 tests failed out of 2

Total Test time (real) =   0.03 sec
[100%] Built target check_lab6
```