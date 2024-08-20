---
title: Gameplay in Unreal Engine(1):人物与视角
author: Leager
mathjax: true
date: 2024-08-15 12:00:00
summary:
categories:
  - unreal
tags:
  - unreal
  - gameplay
img:
---

试图学习 Gameplay with UE 基本设计。

<!-- more -->

参考资料：

- [还不错的视频资料：bilibili](https://www.bilibili.com/video/BV1Rt421V7r2/?p=2&spm_id_from=pageDriver&vd_source=6c9ee957ce4e9589cb06ddc343edf771)
- [官方文档](https://www.unrealengine.com/zh-CN)

## 准备工作

### 下载 Unreal Engine 与 Visual Studio

[这是 Unreal Engine 的下载链接](https://www.unrealengine.com/zh-CN/download)。

> 最终得到的是 Epic Games，可以用 steam 登录，之后下载最新版虚幻引擎。此时是 **5.4.3** 版本。

[这是 Visual Studio 的下载链接](https://visualstudio.microsoft.com/zh-hans/vs/)。

> 下载 Community 2022 版。

根据[这个教程](https://dev.epicgames.com/documentation/zh-cn/unreal-engine/setting-up-visual-studio-development-environment-for-cplusplus-projects-in-unreal-engine)进行 VS 相关组件的安装。

同时去虚幻商城搜索并安装「Visual Studio Tools」。

> 🍕可选：安装 [Visual Assist 破解版](https://zhuanlan.zhihu.com/p/661815368)。

### 创建新项目

打开引擎后会出现这个界面。选择「空白项目」，在项目默认设置中选择「C++」，并取消勾选「初学者内容包」，选择项目位置和项目名称，如下图所示：