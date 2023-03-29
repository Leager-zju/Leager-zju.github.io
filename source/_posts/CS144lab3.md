---
title: CS144 lab3 TCP Sender
author: Leager
mathjax: true
date: 2023-03-29 13:30:01
summary:
categories:
  - CS144
tags:
  - lab
img:
---

本 lab 需要实现 TCP 协议的发送端。

<!--more-->

<img src="1.png" style="zoom:67%;" />

> 依然是这张图

## 数据结构

一个 TCPSender 应该完成以下事情：

1. 跟踪接收方的窗口（处理传入的 ackno 和窗口大小）；
2. 尽可能填充窗口，方法是从 ByteStream 读取，创建新的 TCP 段（如果需要，包括 SYN 和 FIN 标志），然后发送它们。发送方应继续发送段，直到窗口已满或 ByteStream 为空；
3. 跟踪哪些段已发送但尚未被接收方确认——我们称这些为"未完成"的段；
4. 如果自发送以来经过了足够长的时间且尚未确认，则重新发送最早未完成的段；

这就需要我们添加一系列成员变量，我的数据结构设计如下：

```c++
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

## 定时功能

这是本 lab 的第一个任务。随着时间流逝，如果最早发送的段在一定时间内未得到确认，则需要进行**超时重传**，而定时器的作用就是告诉 sender "超时了"，它应该有以下功能：

1. `start()`，包括设置 rto 以及重置时间进度为 0，并将定时器状态设为 `WORK`；
   
    ```c++
    void Timer::start(unsigned int rto) {
      _rto = rto;
      _current_time = 0;
      _state = TimerState::WORK;
    }
    ```

2. `stop()`，将定时器状态设为 `IDLE`；

    ```c++
    void Timer::stop() {
      _state = TimerState::IDLE;
    }
    ```

3. `tick()`，增加时间进度，并在超过 rto 时向调用者传递信息(true/false)；
   
    ```c++
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

```c++
void TCPSender::tick(const size_t ms_since_last_tick) {
  if (!_outstanding_segments.empty() && _timer.tick(ms_since_last_tick)) {
    segments_out().push(_outstanding_segments.front());
    if (_rws != 0) {
      _retransmission_times++;
      _rto *= 2;
    }
    _timer.start(_rto);
  }
}
```

## 收到确认后要做什么

当收到一个正确的 ackno 时：

1. 将 RTO 设置回其"初始值"（即 `_initial_retransmission_timeout`）；
2. 如果发送方有任何未完成的数据，重启定时器，使其在 RTO 毫秒（对于 RTO 的当前值）后到期；
3. 反之，如果所有未完成的数据都被确认，停止定时器；
4. 将重传次数重置为零；

怎样算正确的 ackno 呢？对于一个段而言，当且仅当下式满足时，该段被成功确认。

$$
\text{abs\_ackno} \geq \text{abs\_seqno} + \text{length\_in\_sequence\_space}
$$

> 也就是说，只有部分确认的段依然被认为是"完全未确认"。

与此同时，还应满足 $\text{abs\_ackno}\leq \text{abs\_next\_seqno}$，否则会被认为是无效确认号。

```c++
void TCPSender::ack_received(const WrappingInt32 ackno,
                             const uint16_t window_size) {
  if (unwrap(ackno, _isn, next_seqno_absolute()) > next_seqno_absolute()) { // 无效确认号
    return;
  }

  bool flag{false}; // 是否有段被完全确认
  // 重置成员变量
  _ackno = unwrap(ackno, _isn, _next_seqno); // abs_ackno
  _rws = window_size;

  while (!_outstanding_segments.empty()) {
    TCPSegment& seg = _outstanding_segments.front();
    size_t seq_length = seg.length_in_sequence_space();
    if (seg.header().seqno + seq_length > ackno) { // 部分确认，退出
      break;
    }
    // 完全确认
    flag = true;
    _outstanding_segments.pop();
  }

  if (flag) {
    _rto = _initial_retransmission_timeout;
    _outstanding_segments.empty() ? _timer.stop() : _timer.start(_rto);
    _retransmission_times = 0;
  }
}
```

## 如何发送段

可以简单地认为，将 segment 插入 `_segments_out` 队列中就算将它发出去了。

但事实上，原始代码里并没有修改 segment 首部和负载字段的 api，需要修改头文件，加上几个 `set_syn()`，`set_fin()` 之类的，方便正确创建段。

最开始(abs_next_seqno=0)的时候，由于尚未建立连接，`_rws` 字段会被初始化为 1 而非 0，此时要发送的段仅仅为 `{SYN=1, data=""}` 的同步请求段。在收到确认之后，`_rws` 字段会被重置，我们就需要发送数据以尽可能填满该窗口，同时数据大小又不能超过 `TCPConfig::MAX_PAYLOAD_SIZE`。

已经发过的数据部分在未超时的情况下不用重复发送，那么理论上 `ackno` 会小于等于 `next_seqno`，而我们之后要发的数据部分应从 `next_seqno` 部分开始，于是乎这里就有了**发送窗口**的概念，即

$$
\text{send\_window\_size} = \text{abs\_ackno} + \text{\_rws} - \text{abs\_next\_seqno}
$$

这里需要注意的点是，`send_window_size` 指的是还可以发送多少序列号，而 `TCPConfig::MAX_PAYLOAD_SIZE` 指明了数据部分的字符数量，这两者的区别影响了是否需要在发送端的 `ByteStream` 数据读完后将 `FIN` 设置为 `1`。

> 如果 `ByteStream` 已经 eof 且 `data.length() < send_window_size`，说明还能容纳一个 `FIN` 的序列号，此时应当将 `FIN` 设为 `1`。很可能的一个情况是剩下的数据刚好有 `TCPConfig::MAX_PAYLOAD_SIZE` 这么多，而 `send_window_size` 恰好为 `TCPConfig::MAX_PAYLOAD_SIZE+1` 甚至更多，那么不加 `FIN` 是不合适的，违背了**尽可能填满**的规则。

关于 `FIN` 还有个坑点，就是收到对 `{FIN=1}` 段的确认后，很可能依然满足发 `FIN` 段的要求，从而源源不断地发送，这就需要有一个变量来记录是否已经发过 `FIN` 段了，也就是上文中提到的 `TCPSender::close` 变量。

由于数据有大小上限，那么极有可能出现 `ByteStream` 还有大量数据，`_rws` 也还很大的情况，单独发一个 `TCPConfig::MAX_PAYLOAD_SIZE` 的段远远不够"填满"，此时要利用循环来不断尝试直至只能生成空段。

最后实现如下：

```c++
void TCPSender::fill_window() {
  if (_timer.state() == TimerState::IDLE) {
    _timer.start(_rto);
  }

  while (true) {
    TCPSegment seg;

    if (next_seqno_absolute() == 0) {
      seg.header().set_syn(); // 自定义 api
    } else {
      size_t read_size = min(send_window_size(), TCPConfig::MAX_PAYLOAD_SIZE);
      std::string data = stream_in().read(read_size);

      if (!closed && stream_in().eof() && data.length() < send_window_size()) {
        seg.header().set_fin(); // 自定义 api
        closed = true;
      }
      seg.payload().set_storage(std::move(data)); // 自定义 api
    }

    size_t seq_length = seg.length_in_sequence_space();
    if (seq_length > 0) {
      seg.header().set_seqno(next_seqno()); // 自定义 api
      _segments_out.push(seg);
      _outstanding_segments.push(seg);
      _next_seqno += seq_length;
    } else { // 遇到空段，说明没有能发的了，退出
      break;
    }
  }
}
```

## 测试结果

执行以下命令进行测试：

```bash
$ cd build
$ make format
$ make
$ make check_lab3
```

测试结果如下，通过。

```c++
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