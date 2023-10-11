---
title: 进程间通信(IPC)
author: Leager
mathjax: true
date: 2023-10-11 11:46:29
summary:
categories:
  - 操作系统
tags:
img:
---

为了保护操作系统中进程互不干扰，需要使用进程隔离技术，以防不同进程能够修改其他进程数据。但进程之间又不能完全隔离，需要一定的通信手段，于是开发出了**进程间通信(IPC, InterProcess Communication)**技术。

<!--more-->

