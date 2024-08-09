---
title: CMU15445 Project#0 C++ Primer
author: Leager
mathjax: true
date: 2022-12-06 10:16:12
summary:
categories: lab
tags:
  - CMU 15445
img:
---

本项目与课程教学内容无关，仅作 C++ 水平检验用，但我在 code 过程中发现还是涉及到部分比较重要的知识点，故作记录。

[>>> LAB 主页传送门 <<<](https://15445.courses.cs.cmu.edu/fall2022/project0/)

<!--more-->

此项目要求我们实现一个基于并发 Trie 的 k/v 存储，支持 Insert, Remove, GetValue 三种操作。

> 有关 Trie 这种数据结构可以参考[维基百科](https://en.wikipedia.org/wiki/Trie)。

为了简化，这里假设 Key 都是非空的可变长度字符串，即 `std::string`。Value 存储在该键最后一个字符所处的节点（**Terminal Node**）中。例如，考虑将 kv 对 `("ab", 1)` 和 `("ac", "val")` 插入到 Trie 中，将如下所示。

<img src="graph.png" style="zoom: 80%;" />

## Task #1 - templated trie

### TrieNode

> 该类定义了 Trie 中的单个节点。`TrieNode` 保存单个字符，`is_end_` 标志表示它是否为 Terminal Node。可以根据字符通过 `map<char, unique_ptr<TrieNode>> children` 访问子节点。

其它成员函数实现都很简单，这里需要关注类的移动构造函数 `TrieNode(TrieNode&& )` 和插入子节点函数 `InsertChildNode(char , std::unique_ptr<TrieNode> )`。这里涉及到智能指针和左值右值，以及移动语义。

> 这里**智能指针**只涉及 **unique_ptr**，我的理解是将裸指针封装成类以保证析构释放资源，同时独占该指针的使用权，既能防止其它指针指向该地址导致错误释放，也能在不生成副本的情况下访问数据。
>
> 具体可参考[这篇文章](https://xhy3054.github.io/cpp-unique-ptr/)。

> **左值**简单来说是指有名的、可通过地址访问的变量，一般在等号左侧；相反，**右值**就是字面量，一般在等号右侧。**左值引用**只能绑定到左值，**右值引用**只能绑定到右值。然而，**右值引用**既可以是左值（函数形参）也可以是右值（函数返回值）。
>
> 具体可参考[这篇文章](https://zhuanlan.zhihu.com/p/335994370)。

> 与深拷贝不同，**移动语义**直接移动数据的所有权。与 **unique_ptr** 结合就变成了转移指针的所有权。
>
> 具体可参考[这篇文章](https://www.cnblogs.com/zhangyi1357/p/16018810.html)。

再来看这两个函数。移动构造函数需要接管所有数据，基本类型变量直接赋值即可，对 **unique_ptr** 而言需使用 `std::move()` 转移所有权。如果参数声明为 `const Type&` 则无法使用移动语义。

### TrieNodeWithValue

> 继承自 `TrieNode`，并代表一个可以保存任意类型值的 Terminal Node，它的 `is_end_` 总为 true。

该类会在 Insert 一个 Key 的最后一个字符时从 TrieNode 变化而来，由于 TrieNode 没有无参构造函数，所以在 TrieNodeWithValue 构造函数中需显式声明父类构造。

这里构造函数参数中的 `TrieNode &&trieNode` 虽然是右值引用，但是左值，故利用它执行父类构造时需使用 `std::move()` 将左值强转为右值。

### Trie

> 根节点是所有键的起始节点，它本身不存储任何字符。

#### 插入

如果待插入的 key 已存在，即 key 的所有字符都在 Trie 中存在且最后一个字符所处节点为 Terminal Node，则插入失败。

反之，对于不存在的字符，调用 `TrieNode.InsertChildNode()` 方法。当遍历至最后一个字符时，需将该节点转为 `TrieNodeWithValue`，我的方法是维护父节点指针 `prev`，届时对 `prev` 中的 `children` 变量作修改即可。在 C++ 多态特性下，基类指针也可以指向子类。

#### 删除

删除需要递归式地去判断是否删除子节点，于是开个新函数 `RecursivelyRemove`。需要注意的是，即便成功删除了该键，也不一定需要将对应的节点删除，故需要用一个变量来通知父节点是否需要将自身移除。而对于该键的 non-Terminal Node，需要判断自身是不是其它键的 Terminal Node，不能随意删除。

> 考虑对于两个 Trie 中的键 "Hi" 和 "High"，按不同顺序删除。

#### 取值

和插入一样，但若下个节点不存在，或最后一个字符不是 Terminal Node，或最后一个是 Terminal Node 但存的值类型不一致，则取值失败。在使用 `dynamic_cast` 的时候我选择转为指针类型，是因为方便判断是否转成功。

