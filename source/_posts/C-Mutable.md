---
title: C++ の 可变说明符(Mutable)
author: Leager
mathjax:
  - false
date: 2023-03-02 14:29:34
summary:
categories: c++
tags:
  - C++
img:
---

`mutable` 意为**可变的**，可以在**非引用非常量非静态**数据成员的声明中出现，允许被常量类对象修改。

<!--more-->

## 类中的 mutable

先聊聊一个有趣的话题，关于 [**const**](../../c/c-const) 类成员函数有两大观点流派：

1. **bitwise constness**：主张成员函数只有在不更改对象的任何非静态成员变量时才被认为是 const，即**绝对**常量；

    > 事实上这正是 C++ 对**常量性**的定义。

2. **logical constness**：主张 const 成员函数可以修改所处理对象内部的某些 bits，仅当用户看不出的情况才行，即**自适应**常量；

对于第一种主张，有些成员函数并不具备 bitwise 特性，却能通过编译，一个很直观的例子便是，一个 const 类成员函数修改了类中某个指针指向的内容，却没有改变其指向：

```cpp bitwise constness
class TextBlock {
 public:
  TextBlock(const char* s) { /* ... */ }

  char& operator[](std::size_t index) const {
    return pText[index];
  }

 private:
  char* pText;
};

int main() {
  const TextBlock t("hello");
  char* ptr = &t[0];
  *ptr = 'j';
}
```

于是一个保有字符串 `"hello"` 的常量对象，并没有拿牢，而是被改为了 `"jello"`。

对于第二种主张，编译器并不支持这一做法，于是 `mutable` 关键字派上用场。如果将一个成员变量声明为 `mutable`（保证声明前提），则可以在 `const` 成员函数中对其进行修改，如下：

```cpp logical constness
class Foo {
 public:
  /* ... */
  int AddAndGet() const { return ++bar; }
 private:
  mutable int bar; // 释放 bitwise constness 约束
};
```

> 主要用于指定不影响类的外部可观察状态的成员，通常在并发场景下搭配互斥锁使用。

## lambda 表达式中的 mutable

具体可参考[本文](../../c/c-function/#可选说明符)。

简单来说就是 lambda 表达式会将值捕获的变量视为 `const`，若想要对其进行修改需加上 `mutable` 说明符。