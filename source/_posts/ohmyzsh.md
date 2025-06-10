---
title: 使用 oh-my-zsh 美化终端
author: Leager
mathjax:
  - true
date: 2024-09-01 00:00:00
summary:
categories:
tags:
img:
---

比 bash 好看太多

<!-- more -->

> 这里使用的是 Ubuntu

## 安装 zsh

```bash
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install zsh git curl -y
sudo chsh -s ${which zsh}
```

## 安装 oh-my-zsh

```bash
# 国内镜像
sh -c "$(curl -fsSL https://gitee.com/pocmon/ohmyzsh/raw/master/tools/install.sh)"
```

## 安装 powerlevel10k 主题

```bash
# 安装主题与 自动补全、语法高亮 两大插件
git clone --depth=1 https://gitee.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```

在 `~/.zshrc` 如下设置。

```bash
ZSH_THEME="powerlevel10k/powerlevel10k"
...
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
```

接着 `source ~/.zsh`，进入自定义主题配置阶段。

> 后续也可以通过 `p10k configure` 重新配置。