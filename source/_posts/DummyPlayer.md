---
title: 从零开始 の 练手项目
author: Leager
mathjax: true
date: 2024-04-25 10:28:13
summary:
categories: c++
tags:
  - Project
img:
---

运行环境：VScode + WSL(Ubuntu 22.04 LTS)

[>>> Github 仓库<<<](https://github.com/Leager-zju/DummyPlayer)

<!--more-->

> 实现一个命令行工具模拟游戏玩家。每个玩家存储数据结构
> - 昵称
> - 金币
> - 道具背包（支持多个道具, 用 `itemid` 代表道具类型，`itemcnt` 代表数量）
>
> 支持以下命令
>
> - login <用户账号 id> 如存在，从磁盘读取数据，如果不存，创建用户
> - set-name <name>
> - add-money 增加金币
> - add-item <item-id> <item-cnt> 增加道具
> - sub-item <item-id> <item-cnt> 减少道具
> - logout 登出，并把数据写入磁盘
>
> 要求
>
> - 使用 git 进行源代码管理
> - 使用 c++ 语言
> - 代码在 linux 上运行通过
> - 使用 protobuf
>   - 内存数据结构，使用 protobuf 生成的代码
>   - 保存到磁盘使用 protobuf 序列化后的数据
> - 使用 cmake 构建
> - 使用 gdb 调试、查看运行中的数据
> - 日志输出操作记录
> - 书写脚本，通过日志统计一下信息
>   - 登录的人数、次数
>   - 每个道具的增加和减少的总数


## 环境搭建

### 安装 WSL

windows 下 `以管理员身份运行` 命令行，键入 `wsl --install` 等待安装完成。

设置用户 `id` 与 `passwd` 后用 VScode `连接到 WSL`。

### Github public-key

```bash
$ ssh-keygen -t rsa -C "your@email.name"
```

一路回车，会在 `~/.ssh/` 下创建一个名为 `id_rsa.pub` 的文件，将里面的内容拷贝到 `Github -> Settings -> SSH and GPG keys -> New SSH key` 里，之后就可以实现**免密**操作。

### 更改镜像源

默认的源访问速度过慢，可以用国内镜像源代替加速 `apt-get install`。

```bash
$ sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak ## 备份
$ sudo vim /etc/apt/sources.list
```

键入 `gg`（光标移到首行）+ `d`（删除选中内容）+ `G`（光标移到最后一行）进行**全选删除**。

键入 `i` 进入编辑模式，将下面内容拷贝粘贴后，键入 `Esc` + `:wq` 保存退出。

```bash
## 清华源
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal main restricted universe multiverse
## deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates main restricted universe multiverse
## deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-backports main restricted universe multiverse
## deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-security main restricted universe multiverse
## deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-security main restricted universe multiverse
```

最后更新 `apt-get`

```bash
$ sudo apt-get update
$ sudo apt-get upgrade
```

### 工具安装

```bash
$ sudo apt-get install g++
$ sudo apt-get install cmake
$ sudo apt-get install build-essential
```

> 这一步可能会出现因换源导致的如下报错。
>
> ```bash
> $ GPG error: The following signatures couldn't be verified because the public key is not available: NO_PUBKEY (一个 16 位十六进制数)
> ```
>
> 解决方案为添加相应的 PUBKEY。
>
> ```bash
> $ sudo gpg --keyserver keyserver.ubuntu.com --recv (上面的那个 PUBKEY)
> $ sudo gpg --export --armor (上面的那个 PUBKEY) | sudo tee
> ```
>
> 之后再进行 `apt-get` 的 `update`/`upgrade`。


### 建仓

在 Github 上 `Repositories -> New` 一个空仓库，执行下面的语句。

```bash
$ git clone git@github.com:Your/Repository.git foo
$ cd foo
$ code .
```

## 项目编写

在 VScode 下键入 `ctrl + shift + p`，输入 `cmake`，选择 `CMake: Quick Start`，指定之前安装好的 `g++`，输入项目名，选择 `C++` 与 `Executable`（因人而异），就会在当前目录下生成以下文件：

```bash
├── build
│    └── ...
├── main.cpp
└── CMakeLists.txt
```

至此一个基本的结构就已经完成了。

### 修改 CMakeLists.txt

对于一个项目而言，我们会希望在根目录下设置两个文件夹 `src/` 和 `include/`，分别用于存放 `.cpp` 文件和 `.h` 文件，那么修改后的目录结构应该长这样：

```bash
├── build
│    └── ...
├── include
│    └── ...
├── src
│    ├── main.cpp
│    └── ...
└── CMakeLists.txt
```

此时再 `cd build && cmake ..` 会报错，这是因为 `CMakeLists.txt` 找不到相应文件了。默认生成的 `CMakeLists.txt` 长下面这样：

```bash
cmake_minimum_required(VERSION 3.0.0)       ## 指定 cmake 最低版本
project(test VERSION 0.1.0 LANGUAGES C CXX) ## 指定项目名与语言

include(CTest)
enable_testing()

add_executable(test main.cpp)

set(CPACK_PROJECT_NAME ${PROJECT_NAME})
set(CPACK_PROJECT_VERSION ${PROJECT_VERSION})
include(CPack)
```


#### 设置链接文件目录

只需要关注 `add_executable(test main.cpp)` 这一行即可，这句话的意思是将 `main.cpp` 生成的目标文件 `main.o` 链接到最终的可执行文件 `test` 里，默认是在 `CMakeLists.txt` 同级目录下查找，因为我们修改了项目的文件结构，CMakeLists 找不到就报错了。

并且由于这里加了其它的 `.cpp`/`.h` 文件，也需要将其纳入可执行文件的链接范围内。

应当改为

```cpp
set(SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)
file(GLOB_RECURSE SRC_FILES
    "${SRC_DIR}/*/*.c*"
    "${SRC_DIR}/*.c*"

    "${SRC_DIR}/*/*.h*"
    "${SRC_DIR}/*.h*"
)
add_executable(test ${SRC_FILES})
```

其中

- `CMAKE_CURRENT_SOURCE_DIR` 宏是当前 `CMakeLists.txt` 所在目录；
- `file(GLOB_RECURSE SRC_FILES ...)` 是指遍历目录下所有正则匹配的文件，并将其加到 `SRC_FILES` 集合中；

#### 设置头文件目录

还不够，还要让编译器知道 `#include` 中的 `.h` 文件在哪，这就要用到其 `include_directories()` 命令，设置头文件所在（根）路径，所有 `#include` 预处理命令都会在这个路径下查找。

#### 编译选项

```cpp
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_BUILD_TYPE Release)
target_compile_options(dummyplayer PUBLIC -Wall -Werror -g)
```

#### 可执行文件输出路径

```cpp
set(EXECUTABLE_OUTPUT_PATH ${CMAKE_CURRENT_SOURCE_DIR}/build/bin)
```

### 引入 protobuf

#### 安装 protoc 编译器

在[这个页面](https://github.com/protocolbuffers/protobuf/releases/latest)查看最新版本

> 此时此刻为 `https://github.com/protocolbuffers/protobuf/releases/download/v26.1/protoc-26.1-linux-x86_64.zip`。

```bash
$ wget https://github.com/protocolbuffers/protobuf/releases/download/v26.1/protoc-26.1-linux-x86_64.zip
$ unzip protoc-26.1-linux-x86_64.zip
$ sudo cp path/to/protoc/bin/protoc /usr/bin/
$ sudo cp -r path/to/protoc/include/ /usr/include/
```

通过 `protoc --version` 检查是否成功。

#### 引入 Protocol Buffers 库

通过如下命令安装

```bash
$ sudo apt-get install protobuf-compiler libprotobuf-dev
```

然后在 `CMakeLists.txt` 中进行如下修改

```cpp
find_package(Protobuf REQUIRED)
include_directories(
    ...
    ${PROTOBUF_INCLUDE_DIRS}
)
target_link_libraries(
    ...
    ${PROTOBUF_LIBRARIES}
)
```

#### 编写 .proto

```protobuf
syntax = "proto3"; // 表示用 protobuf 3 的语法

package test;      // 被编译成 .cpp 后就是下面各个结构体的 namespace

message Users {
    repeated string id = 1; // repeated 表示字段可重复，用于实现数组
}

message Player {
    string id = 1;               // 等号后面为该字段的唯一标识符，同一 message 中不能重复
    string name = 2;
    int32 money = 3;
    map<int32, int32> items = 4; // 键值对类型
}
```

#### 编译 .proto

使用之前下载好的 `protoc` 来编译 `.proto` 文件

```bash
$ protoc -I=$SRC_DIR --cpp_out=$DST_DIR $SRC_DIR/xx.proto
```

其中，`$SRC_DIR` 是 `.proto` 所在目录，`$DST_DIR` 是生成代码的目标目录。会在 `$DST_DIR` 下生成两个文件 `xx.pb.cc` 和 `xx.pb.h`，为了调用相应数据结构，需要将 `$DST_DIR` 在 CMake 里加到 `include_directories` 里。


### 利用 protobuf 进行序列化/反序列化与文件读写

编译得到的 C++ 源码里为我们提供了以下两个函数

```cpp
bool ParseFromIstream(std::istream* input);
std::string SerializeAsString() const;
```

配合 C++ 库 `<fstream>` 中的 `ifstream`/`ofstream` 就能实现 protobuf 与磁盘的交互。

```cpp
// 读取文本并反序列化为结构体
std::ifstream fread("file/name", std::ios::in);
player_.ParseFromIstream(&fread);
fread.close();

// 将结构体序列化到文件中
std::ofstream fwrite("file/name", std::ios::trunc);
fwrite << player_.SerializeAsString();
fwrite.close();
```

### 日志输出

基本思路是在程序启动时用 `std::ofstream` 打开日志文件，每次调用 `log()` 时以 `std::ios::app` 方式追加写入。为了提高泛用性，可以用参数包来作为输入。

```cpp
template<class T, class ...Args>
void log(T&& first, Args&& ...args) {
    logWrite << first << " ";
    log(args...);
}

template<class T>
void log(T&& arg) {
    logWrite << arg << std::endl;
}
```

用宏可以在不降低开发效率的同时，输出更多可用信息

```cpp
#define LOG_ENABLED 1
#define HEADER header(__FILE__, __LINE__)

#if LOG_ENABLED
#define LOG(...) log(HEADER, __VA_ARGS__)
#else
#define LOG(...)
#endif

inline std::string extractFileName(const std::string& filePath) {
    return filePath.substr(filePath.find_last_of("/\\") + 1);
}

inline std::string header(const std::string& filename, int line) {
    return "[" + extractFileName(filename) + ":" + std::to_string(line) + "]";
}
```

### 脚本统计信息

这里用了 `awk` 这个大杀器，用下来感觉它是为这一需求量身定制的。通过 `pattern { command }` 的语法，可以对于符合 `pattern` 的文本行，应用相应的操作。

比如我的日志输出内容是这样的

```cpp
10:26:30 [controller.cpp:114] log-in with account 123
10:26:30 [controller.cpp:122] set-name to user
10:26:30 [controller.cpp:141] add-money for count 10
10:26:30 [controller.cpp:149] get-money
10:26:30 [controller.cpp:163] add-item 1 for count 1
10:26:30 [controller.cpp:163] add-item 2 for count 1
10:26:30 [controller.cpp:163] add-item 3 for count 1
10:26:30 [controller.cpp:177] sub-item 1 for count 1
10:26:30 [controller.cpp:196] log-out
10:26:30 [controller.cpp:208] quit
```

则可以用以下 awk 脚本来处理

```awk
$3 ~ /log-in/ {     ## $3 表示对每一行用空格（也可以用 -F 指定分隔符）进行 split 后的第三列（awk 的列索引从 1 开始），~ 表示匹配，!~ 表示不匹配，模式用两个 / 包裹
    ids[$6] += 1    ## 全局有效
}
$3 ~ /add-item/ {
    count[$4] += $7
}
$3 ~ /sub-item/ {
    count[$4] -= $7
}
END { ## 表示将之后的命令在所有匹配项检查完后执行
    for (id in ids) {
        print "user", id, "log in", ids[id], "times"
    }
    for (item in count) {
        c = count[item]
        if (c > 0) {
            print "item", item, "added", c, "times"
        } else if (c < 0) {
            print "item", item, "decreased", c, "times"
        }
    }
}
```

执行下面语句，得到相应输出

```bash
$ awk -f path/to/awk path/to/log ## -f 指定脚本所在文件，然后单独跟待处理的文件

## output:
## user 123 log in 1 times
## item 2 added 1 times
## item 3 added 1 times
```

## 提高开发效率

### 使用 Clangd 代替 C++ Intellisense

> 后者就是一坨屎。

首先 `sudo apt-get install clangd`，会在 `/usr/bin/` 下进行程序的安装。

接着在 VScode 的应用市场搜索 `clangd` 插件并安装。

键入 `ctrl + ,` 进入用户设置，右上角 `打开设置(json)`，添加如下设置：

```json
{
    ...
    "clangd.path": "/usr/bin/clangd",
    "clangd.arguments": [
        "--all-scopes-completion",
        "--background-index",
        "--clang-tidy",
        "--completion-parse=auto",
        "--completion-style=bundled",
        "--enable-config",
        "--fallback-style=Google",
        "--function-arg-placeholders=false",
        "--header-insertion-decorators",
        "--header-insertion=never",
        "--log=verbose",
        "--pch-storage=memory",
        "--pretty",
        "--ranking-model=decision_forest",
        "-j=12",
        "--compile-commands-dir=${workspaceFolder}/build"
    ],
    ...
}
```

并禁用 `C/C++` 插件的 `Intellisense`，具体做法是 `ctrl + ,` 搜索 `intelli sense`，将 `C_Cpp: Intelli Sense Engine` 项改为 `disabled`。

`clangd` 是根据一个叫 `compile_commands.json` 的文件来进行代码提示的，这个文件的生成需要在 `CMakeLists.txt` 中加入这一行：

```cpp
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
```

这样在 `build` 目录下执行 `cmake ..` 就能看到生成 `compile_commands.json` 文件了。

> 也可以用 `cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON/OFF ..` 的方式手动控制是否生成。

这一切就绪后，就可以通过键入 `ctrl + shift + p`，输入 `clangd`，选择 `clangd: Restart language server` 来更新 `clangd` 运行环境了。此时可以看到代码提示 work。