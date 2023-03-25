---
title: CS144 lab0 Networking Warmup
author: Leager
mathjax: true
date: 2023-03-21 18:28:52
summary:
categories:
  - CS144
tags:
  - lab
img:
---

本 lab 就是拿来配环境+练手的。

<!--more-->

## 环境配置

本课程所有 lab 均需要在 Linux 环境下运行，课程组提供了 4 种运行方式，直接照着 [Instructions](https://stanford.edu/class/cs144/vm_howto/) 来就好了。我这里因为实验室自带 Ubuntu 工作站，所以用了第三种方式，按照清单一个个 `sudo apt-get install` 下来就完事了。

## Get Started!

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
# If you pull / push over HTTPS
$ git clone https://github.com/your_github_name/your_repository_name.git

# If you pull / push over SSH
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
$ ./apps/webget cs144.keithw.org /hello # 可执行文件, host, path
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

```c++
[100%] Testing webget...
Test project .../CS144/build
    Start 31: t_webget
1/1 Test #31: t_webget .........................   Passed    6.05 sec

100% tests passed, 0 tests failed out of 1

Total Test time (real) =   6.05 sec
[100%] Built target check_webget
```

## An in-memory reliable byte stream

lab0 的最后一个任务是实现一个处理字节流的有限容量 buffer，writer 负责将字节流写入 buffer 中，reader 从中读取。文件位于 `libsponge/byte_stream.cc` 以及 `libsponge/byte_stream.hh`。

writer 的工作很简单，写数据(write)、终止写入(end_input)以及获取 buffer 剩余容量(remaining_capacity)，需要注意的是如果写入的数据大小超过了剩余容量，则应尽可能写入，比如剩余容量 3 的情况下要写 `"abcdefg"`，则只写入 `"abc"`。

reader 有三种输出方式，只读(peek_output)，只写(pop_output)以及读写(read_output)，注意后两种方法都意味着增加**已读取的字节数**。

以及一些通用的接口，这些接口的实现需要我们额外添加一些 private 成员变量，不再赘述。此外，考虑到整个 buffer 是一个增删频繁的数据结构，并且还需要顺序遍历，于是采用了 `std::vector<char>` 作为底层数据结构来模拟**循环队列**。其中，`head` 指向队首，`tail` 指向队尾的下一个位置，数组大小应为 `capacity + 1`（留一个位置来判断队列为空还是满）。当 `head == tail` 时为空，`head == (tail + 1) % (capacity + 1)` 时为满，当前缓存的字节数为 `(tail - head + capacity + 1) % (capacity + 1)`。

写完后执行以下命令进行测试：

```bash
$ cd build
$ make format
$ make
$ make check_lab0
```

测试结果如下，通过。

```c++
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