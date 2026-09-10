---
title: "Build Hexo in WSL"
date: "2024-08-31 23:00:00"
slug: "makehexo"
url: "/notes/makehexo/"
draft: false
math: true
categories:
  - "guide"
tags:
---

配了台新机子，不想用 Windows 管理这些东西，遂使用更贴近使用习惯的 WSL。

<!-- more -->

## WSL 安装

```bash
wsl --install
```

然后要求重启，重启后设置 `user` 和 `passwd`。

> 现在每次进去都是 root 身份，可以通过 `wsl config --default-user <username>` 设置默认用户。

### 😏修改默认安装目录到其他盘(Optional)

因为默认装在 C 盘，希望 C 盘纯净一点的可以这么干。

```bash
# 获取 Name 列的值，比如我这里是 "Ubuntu"
wsl -l --all -v

# 导出到 D 盘                     
wsl --export Ubuntu D:/ubuntu.tar

# 注销原来的发行版
wsl --unregister Ubuntu

# 将之前导出的 ubuntu.tar 导入到目录 D:/Ubuntu 下
wsl --import Ubuntu D:/Ubuntu D:/ubuntu.tar --version 2
```

然后用 Vscode 直连即可。

## 相关工具安装

### Git

```bash
sudo apt-get install git

git config --global user.name "your_github_name"

git config --global user.email "your_github_email"

ssh-keygen -t rsa -C "your_github_email"

# 然后将 ~/.ssh/id_rsa.pub 的内容全部拷贝到 Github 中
# 用 ssh -T git@github.com 验证
```

### Node.js & npm

如果直接 `sudo apt install nodejs npm` 的话是无法正常进行后续工作的，因为版本太老了。正确做法是用 `nvm` 这个版本管理器。

```bash
sudo apt install curl

# 这一步如果超时也可以直接进链接把内容拷贝过来运行
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
```

如果用的是 zsh，则在 `~/.zshrc` 中加入下面这段。

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
```

之后用 `nvm -v` 验证是否安装成功。

若安装成功，则用 `nvm install node` 安装最新的 NodeJS 发行版本。

为了防止这一步很慢，可以在 `~/.zshrc` 中加入下面这段，以修改 nvm 源。

```bash
export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node
export NVM_IOJS_ORG_MIRROR=https://npmmirror.com/mirrors/iojs
```

最后用 `node -v` 和 `npm -v` 验证结果。

### hexo

```bash
sudo npm install hexo-cli -g
sudo npm install hexo-deployer-git --save
```

如果很慢，则可以用 `npm config set registry http://mirrors.cloud.tencent.com/npm/` 修改镜像源