---
title: Linux 常用命令 の Note
author: Leager
mathjax:
  - false
date: 2023-09-23 18:23:04
summary:
categories:
  - linux
tags:
img:
---

记录常用命令及对应的常用 option，方便查。

<!--more-->

## 切换用户当前工作目录 - cd

全称为 `change directory`

```bash
### example:
## 绝对路径
cd /usr/bin

## 相对路径
cd ./foo/bar/dir
```

## 打印当前工作目录 - pwd

全称为 `print working directory`

## 新建目录 - mkdir

全称为 `make directory`

```bash
mkdir [-mp] dirname
## -m: 指定目录权限
## -p: 若父级目录不存在，则一并新建
```

## 删除空目录 - rmdir

全称为 `remove directory`

```bash
rmdir [p] dirname
## -p: 若父级目录为空，则一并删除
```

## 显示目录内容列表 - ls

全称为 `list`

```bash
ls [-al] [path]
## -a: 列出所有文件，包括以 '.' 开头的隐藏文件
## -l: 列出详细信息，包括文件属性、修改日期等

## path: 若为目录，啧列出指定目录下内容；反之，打印 path
```

## 拷贝文件或目录 - cp

全称为 `copy`

```bash
cp [-filprs] src dst
## -f: 强制执行
## -i: 询问是否拷贝
## -l: 改为建立 hard link
## -p: 保留原权限，而非使用默认权限
## -r: 递归拷贝
## -s: 改为建立 soft link
```

> 拷贝得到的新文件/目录，其 user:group 为命令执行者

## 移动文件或目录 - mv

全称为 `move`

```bash
mv [-fi] src dst
## -f: 强制执行
## -i: 询问是否移动
```

## 删除文件或目录 - rm

全称为 `remove`

```bash
rm [-fir] 文件或目录
## -f: 强制删除
## -i: 询问是否删除
## -r: 递归删除
```

## 修改文件拥有者 - chown

全称为 `change owner`

```bash
chown [-R] username[:groupname] dirname/filename
## -R/--recursive: 递归处理
## 若附带 :groupname 则会将所属群组一并修改
```

## 修改文件所属群组 - chgrp

全称为 `change group`

```bash
chgrp [-R] dirname/filename ...
## -R/--recursive: 递归处理
```

## 修改文件权限 - chmod

全称为 `change group`

```bash
### 数字类型
chmod [-R] xyz 文件或目录
## -R: 进行递归(recursive)的持续变更，亦即连同次目录下的所有文件都会变更
## xyz: 数字类型的权限属性，为 rwx 属性数值的相加。

### 符号类型
chmod [-R] [ugoa][+-=][rwx] 文件或目录
## u: user     +: 加上    r: 可读
## g: group    -: 减去    w: 可写
## o: other    =: 赋予    x: 可执行
## a: all
```
## 连接多个文件并打印到标准输出 - cat

全称为 `concatenate`

```bash
cat [-ns] file1 file2 ...
## -n: 显示行号，等同于 nl
## -s: 压缩连续的空行为一行
```

## 翻页显示文件内容 - more/less

## 打包、压缩与解压缩 - tar

```bash
tar [-j|-z] [-cv] [-f dst] filename... ## 将 filename 打包为 dst
tar [-j|-z] [-tv] [-f src]             ## 查看档名
tar [-j|-z] [-xv] [-f src] [-C dir]    ## 解压缩 src 至指定目录
## -j: 以 bzip2 方式压缩/解压，后缀最好为 tar.bz2
## -z: 以 gzip 方式压缩/解压，后缀最好为 tar.gz

## -c: 创建压缩文件
## -t: 查看压缩文件内容
## -x: 解压

## -C: 解压文件存放的位置，不加就放到当前目录
```

> -c, -t, -x 三者不共存

## 查看磁盘使用情况 - df

全称为 `disk free`

## 显示文件或目录占用磁盘空间大小 - du

全称为 `disk usage`

```bash
du [-schbkm] /path/to/dir/or/file
## -s: 仅显示占用量之和
## -c: 不仅显示单个占用量，也显示总和
## -h: 以 K, M, G 为单位，提高可读性
## -b: 以 Byte 为单位
## -k: 以 KB 为单位
## -m: 以 MB 为单位
```

## 查看内存使用情况 - free

```bash
free [-thbkmg]
## -t: 显示总和
## -h: 以 K, M, G 为单位，提高可读性
## -b: 以 Byte 为单位
## -k: 以 KB 为单位
## -m: 以 MB 为单位
## -g: 以 GB 为单位
```

## 实时显示内存使用情况 - top

## 查看当前进程状态 - ps

全称为 `process status`

通常搭配 `aux` 选项，意思是查看当前**所有终端(x)**上**所有用户(a)**的进程状态，并输出**用户标识符列(u)**。

## 杀掉进程 - kill

它发送信号给指定的进程，让进程执行相应的操作。

```bash
kill [-ls] <PID>
## -l 列出可用的信号列表，常用的有：
##     1 (SIGHUP)：挂起信号，通常用于重新加载配置文件。
##     2 (SIGINT)：中断信号，通常由 Ctrl+C 发送，用于终止进程。
##     9 (SIGKILL)：强制终止信号，立即终止进程，不允许进程做清理工作。
##     15 (SIGTERM)：终止信号，通常用于优雅地终止进程。
## -s <SIGNAL>: 指定要发送的信号名，默认为 15
```

## 显示网卡参数 - ifconfig

## 查看网络系统状态信息 - netstat