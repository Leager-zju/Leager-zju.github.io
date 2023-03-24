---
title: CS144 lab1 Stitching Substrings Into a Byte Stream
author: Leager
mathjax: true
date: 2023-03-24 19:34:56
summary:
categories:
  - CS144
tags:
  - lab
img:
---

本 lab 要求在 lab0 的基础上实现一个字节流整合器。

<!--more-->

<img src="1.png" style="zoom:67%;" />

lab1 ~ lab4 均围绕此图进行。在 lab0 中，我们实现了有序字节流，而事实上真实的网络并不会按顺序向我们发送数据包，我们需要利用一个整合器将收到的无序字节流片段以正确顺序拼接并写到 `ByteStream` 中。数据包以 `{data, index}` 的形式被接收，其中 `data` 为 `std::string`，`index` 为 `data` 作为子串在原始字节流中的下标，如

```c++
                     1         2
           01234567890123456789012345
原始字符串: abcdefghijklmnopqrstuvwxyz...

收到的数据包可能为 {"abc", 0}, {"efghij", 4} 等
```

一旦整合器收到了正确的数据包（需要我们维护一个 `next_index`），它就会将其写入 `ByteStream`；而那些顺序错乱的，整合器会将其缓存，但丢弃那些超过 `capacity` 的部分。关于 `capacity`，guide 里有了一个比较明确的介绍：

<img src="2.png" style="zoom:67%;" />

> 即 `ByteStream` 中未读取的部分加上 `Reassembler` 中无序的部分大小不能超过 `capacity`。