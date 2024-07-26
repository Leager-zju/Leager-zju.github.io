---
title: C++11 の 列表初始化(List Initialize)
author: Leager
mathjax: true
date: 2023-01-28 19:52:46
summary:
categories: C++
tags: C++11
img:
---

在 C++11 中，可以直接在变量名后面用 **`{初始化列表}`** 来进行对象的初始化。

<!--more-->

## 旧世界

C++11 以前，各种初始化方式如神仙打架，百花齐放，在同一个项目中，你或许可以看到如以下几种不同的初始化方式：

```c++
class A {
 public:
  A() {}
  A(int i): i_(i) {}
  A(const A &other): i_(other.i_) {}
  int i_;
};

struct B {
  int x, y;
};

int nums[3] = {1, 2, 3}; // 数组列表初始化
A a0;                    // 默认初始化
A a1();                  // 值初始化
A a2(2);                 // 直接初始化
A a3 = 3;                // 先通过调用 A(3) 构建临时对象，再复制初始化
B b = {0, 0};            // 聚合初始化
```

这使得程序员，或者初学者们经常会感到疑惑：这么多的对象初始化方式，怎样去初始化一个变量或者是一个对象？不仅增加了学习成本，也使得代码风格有较大出入，影响了代码的可读性和统一性。

> 其中聚合初始化**仅**适用于**聚合类型**，通常为**数组**类型，或满足以下条件的**类**类型（通常是 `struct` 或 `union`）：
>
> 1. 没有用户声明或继承的构造函数；
> 2. 没有 `protected` / `private` 的非静态数据成员；
> 3. 没有基类；
> 4. 没有虚函数；
> 5. 没有类内直接初始化的非静态数据成员；
> 6. 没有默认成员初始化器；

## 新世界！列表初始化

为了统一代码，C++11 将列表初始化的功能进行拓展，使其能够应用于绝大多数构造情况，同样的，`new` 操作符等可以用圆括号进行初始化的地方，也可以使用初始化列表。如：

```c++
class A {
 public:
  A(int i): i_(i) {}
 private:
  A(const A &other): i_(other.i_) {}
  int i_;
};

A a0(0);
A a1{1};
A a2 = 2;   // ERROR! A(const A&) 为 private
A a3 = {3}; // OK! 列表初始化，私有拷贝函数无影响，直接应用于其数据 i_
A* a4 = new A{4};
```

不仅如此，列表初始化还可以直接使用在函数的返回值上，亦可以用于 STL 中。自此，初始化代码规范得到了统一，程序员再也不用纠结于初始化方式的挑选了。

除了提高代码可读性这点优势，列表初始化还对基本数据类型的隐式转换作出了**窄化限制**，避免**精度丢失**，比如：

1. 从浮点类型到整数类型的转换；

    ```c++
    int a = 1.2;   // OK!
    int b = {1.2}; // ERROR!
    ```

2. 从整数类型到浮点类型的转换，除非源是常量表达式且不发生截断；

    ```c++
    float a = (unsigned long long)(-1);    // OK!
    float b = {(unsigned long long)(-1)};  // ERROR! -1 为 11..11，转换到 float 会将高位 1 截断
    float c = (unsigned long long)(1);     // OK!
    float d = {(unsigned long long)(1)};   // OK!
    ```

3. 从整数或无作用域枚举类型到不能表示原类型所有值的整数类型的转换，除非源是常量表达式且不发生截断；

    ```c++
    const int a = 1000;
    const int b = 2;
    char c = a;   // OK!
    char d = {a}; // ERROR! 发生截断

    char e = b;   // OK!
    char f = {b}; // OK! 不发生截断，但如果去掉 const 属性，也报错
    ```

4. 路线 `long double -> double -> float` 的转换，除非来源是常量表达式且不发生溢出；

    ```c++
    float c = 1e70;   // OK!
    float d = {1e70}; // ERROR! double -> float
    ```



