---
title: "Fossildle"
slug: "fossildle"
date: 2026-09-28
summary: "每天发现一枚像素化石：逐行揭晓随机图案，发现隐藏结构，收集图鉴并分享你的发现。"
status: "PLAYABLE"
engine: "WEB GAME"
stack: ["React", "TypeScript", "Vite", "SVG"]
play_url: "https://leager-zju.github.io/Fossildle/"
repo_url: "https://github.com/Leager-zju/Fossildle"
---

Fossildle 是一款每日像素化石收藏游戏。敲开一块岩石，看着 8×8 的图案逐行显现，再从中发现对称、连通、空洞等结构，把偶然留下的形状收进自己的小小博物馆。

## 开始游戏

[打开 Fossildle](https://leager-zju.github.io/Fossildle/)

- 每天发现一枚化石，UTC 00:00 更新，即北京时间 08:00。
- 每个像素独立以 1/2 概率成为化石或留白，没有对称保底，也不因结果普通而重抽。
- 全部像素揭晓后，结构得分依次出现，最后公布整体得分与稀有度。点击条目可突出相关格子。
- 图鉴共 16 项结构，未发现条目的名称和条件保持隐藏。
- 支持藏馆珍藏、搜索筛选、只读链接及图片分享。

它不是一道必须解出的谜题。稀有值得惊喜，喜欢的形状也值得收藏。

## 保存你的发现

游戏无需注册，收藏保存在当前浏览器，不会自动跨设备同步。清除网站数据前，请在「关于」中导出备份；恢复备份会替换当前藏馆。

## 源码

[查看 GitHub 仓库](https://github.com/Leager-zju/Fossildle)

[阅读项目说明与本地运行指南](https://github.com/Leager-zju/Fossildle/blob/main/readme.md)

游戏源码与主站分开维护，使用 React、TypeScript、Vite 和 SVG 构建，通过 GitHub Pages 独立发布。
