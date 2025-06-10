---
title: C++11 の 别名(Alias)
author: Leager
mathjax:
  - false
date: 2023-01-17 20:55:25
summary:
categories: c++
tags:
  - C++11
  - C++
img:
---

虽然使用 `auto` 可以大大简化代码，但对于一些使用 `dynamic_cast` 的结果不能用 `auto` 作为占位符。将冗长的变量类型简化仍然是很头疼的一个问题，幸好 C++11 提供了用关键字 **`using`** 给类型起**别名**的特性，既能有效简化代码，又不影响可读性。

<!--more-->

## #define 与 typedef

C 中就已经存在使用 `#define` / `typedef` 来给类型取别名的用法，但为什么还要多此一举用 `using`？它们的区别在哪？

`#define` 是宏定义指令，其在预处理阶段直接将源码文本进行替换，不进行类型检查。

> 也就是说，如果 `#define` 为一个不存在的类型取了别名，写代码的时候 IDE 并不会给你飘红线，但编译时就会报一堆错误。

而对于 `typedef`，其在编译时期执行，故可以进行类型检查，但它不能直接进行模板替换，只能采用**外面套一个结构体**的方式。也就是说，如果定义了这样一个类模板：

```cpp
template<typename T>
class A {};
```

如果试图用 `typedef` 取**模板别名**，则必须用上面那种写法，下面那种写法会报错：

```cpp
// OK
template<typename T>
struct Alias {
  typedef A<T> a_t;
};

// ERROR
template<typename T>
typedef A<T> a_t;
```

这样起别名的方式又增加了冗余的结构体名，降低了可读性与 code 效率。

不仅如此，`typedef` 在定义**函数指针**时也存在降低可读性的情况：

```cpp
typedef void (*func) (int, int); // func 为函数指针 void(*)(int, int) 的别名
```

> 在网上找到很多说 `typedef` / `#define` 无法起模板别名的文章，但实际操作了一遍，发现或许是编译器更新了，一些以前认为无法实现的代码如今都能编译通过。所以还是绝知此事要躬行。

## using

`using` 不仅可以用于导入命名空间或类成员，还可以用于起别名。事实上，`using` 能够实现的功能也已经完全将 `typedef` 能做的包含在内，完全可以舍弃功能单一并且代码反人类直觉的 `typedef`，改用可读性更高的 `using`。

> 委员会既然推出了这一新特性，照着用就完事了~

关于 `using` 的用法，简单来说就是这样的：

```cpp
using new_alias = old_typename;

// or
template<typename T>
using new_alias = old_typename<T>;
```

如果需要使用 `using` 为函数指针取别名，则可以直接用类似赋值的方式，即

```cpp
using func = void(*)(int, int);
```

一目了然，符合直觉。
