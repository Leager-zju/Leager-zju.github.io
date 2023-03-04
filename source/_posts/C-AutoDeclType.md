---
title: C++11 の 类型推导(auto & decltype)
author: Leager
mathjax: true
date: 2023-01-16 12:37:37
summary:
categories:
    - C++11
tags:
    - C++
img:
---

C++11引入了 **`auto`** 和 **`decltype`** 这两个关键字，从而可以在编译期就推导出变量或者表达式的类型，方便开发者编码也简化了代码。

<!--more-->

## auto

关键字 `auto` 的作用便是自动推导变量/函数(C++14起)/模板(C++20起)的类型，例如这样推导是可以的：

```c++
auto foobar = 0;           // OK! 此时 auto 被编译器推导为 int
auto foo = 1, *bar = &foo; // OK! foo, bar 分别为 int 与 int*，此时 auto 被推导为 int（若将 * 删去则报错）
```

但不能这样推导：

```c++
auto foobar;               // ERROR! 必须初始化，否则编译器无法推导。毕竟 auto 只是一个占位符，不能真正代替数据类型进行声明
auto foo = 0, bar = 1.0;   // ERROR! foo, bar 分别为 int 和 double 类型，auto 会产生二义性，非良构
```

### 推导规则

除了上面讲的外，关于 `auto` 还有以下几条规则：

1. 不允许在一个声明中混合 `auto` 的变量和函数，如 `auto f() -> int, i = 0;` 是错误的；
2. 不允许用于**函数形参**的类型推导，如 `void func(auto i);` 是错误的；
3. 在有 **cv 限定符**的类型推导中，若不声明为引用，`auto` 会忽略等号右边的 cv 限定；反之则保留。例如：

    ```c++
    int i = 0;
    const auto con_i = i;          // con_i 为 const int, auto 推导为 int
    
    // no reference
    {
      auto auto_i = i;             // auto_i 为 const int, auto 推导为 int
      auto auto_con_i = con_i;     // auto_con_i 为 const int, auto 推导为 int
    }
    
    // reference
    {
      auto &autoref_i = i;         // autoref_i 为 int&, auto 推导为 int&
      auto &autoref_con_i = con_i; // autoref_con_i 为 const int&, auto 推导为 const int&
    }
    ```

    其中，cv 限定符指关键字 `const` 和 `volatile`。

4. 不允许用作类的**非静态成员变量**；

5. 不允许用于推导**数组**类型，如 `auto arr[3] = {1, 2, 3};` 是不允许的；

6. 不允许用作**模板参数**，如 `std::vector<auto> f{1, 2, 3}; ` 是不允许的，编译器会报 `'auto' not allowed in template argument` 错误；

### 应用场景

将变量声明为迭代器类型是一件非常痛苦的事，尤其是 `std::unordered_map<Typename1, Typename2>::iterator it = map.begin();` 这样的语句，对本人这样的懒惰程序员而言简直是灾祸🤦‍♂️……

在有了 `auto` 后，就可以把上面的语句改写为 `auto it = map.begin()`，懒癌福音🥰

一般地，我个人认为，使用 `auto`的前提是不能影响代码可读性，对于一些不重要的中间变量，使用 `auto` 不会破坏可读性，还能大大提高 code 效率，但对于一些关键的变量，如函数返回值，或是利用到类多态特性的地方，则不建议用 `auto`。

## decltype

尽管都是在编译器进行类型推导，但与 `auto` 不同，`decltype` 根据已声明的变量或表达式推导其类型，无需初始化，例如：

```c++
int foo = 0;
decltype(foo) bar; // 由于 foo 为 int，则 decltype(foo) 被推导为 int
```

上面的 `foo` 可以为任意有类型的表达式，但不能是 `void` 类型。

```c++
void func();

decltype(func) p;   // OK! p 为 void* 的函数指针
decltype(func()) q; // ERROR!
```

### 推导规则

除了上面讲的外，关于 `decltype` 还有以下几条规则：

1. 若推导对象为不被括号包裹的变量表达式或函数调用，则推导结果为该表达式声明时的类型或函数的返回值类型。例如：

    ```c++
    int i = 0;
    const int &j = i;
    auto lambda = [](int a, int b) -> int { return a + b; };
    int func();
    
    class Foo { public: double bar; }
    const Foo *foo;
    
    decltype(i) di = i;         // 推导结果为 int
    decltype(j) dj = j;         // 推导结果为 const int&
    decltype(i+j) k;            // 推导结果为 int
    decltype(lambda) l;         // 推导结果为 lambda [](int, int) -> int
    decltype(func()) f;         // 推导结果为 int
    decltype(foo->bar) foo_bar; // 推导结果为 double
    ```

    > 不难发现，`decltype`会保留表达式的引用和 cv 限定符。

    反之，如果表达式类别为左值，则返回 `T&`；如果为右值，则返回 `T`，其中 `T` 为表达式类型。例如将上面的代码改为下面这样：

    ```c++
    decltype((i)) di = i;                    // 左值，推导结果为 int&
    decltype((j)) dj = j;                    // 左值。推导结果为 const int&
    decltype((i+j)) k;                       // 右值，推导结果为 int
    decltype((lambda)) l;                    // 左值，推导结果为 lambda [](int, int) -> int&
    decltype((func())) f;                    // 右值，推导结果为 int
    decltype((foo->bar)) foo_bar = foo->bar; // 左值，推导结果为 const double&
    ```

2. 若推导对象为函数名，则不允许出现有多个重载的函数，否则会产生二义性，例如：

    ```c++
    int func(int a);
    decltype(func) f1; // OK! func 仅有一个重载
    
    double func(double b);
    decltype(func) f2; // ERROR! func 有两个重载
    ```

### 应用场景

当类模板中需要根据传入的模板参数类中的成员变量来进一步确定类型的变量时，则用 `decltype` 是个很好的选择。常见于推导函数返回值类型的情况，例如：

```c++
template<typename T, typename U>
? func(T t, U u) {
    return t + u;
}
```

由于 T 和 U 不确定，故返回值类型无法判断。一个好的想法是试图用 `decltype(t + u)` 来代替 “?” 的位置，但这样会因为 `t, u` 未定义而报错。但如果与**尾随返回类型**相配合，则完美解决该问题：

```c++
template<typename T, typename U>
auto func(T t, U u) -> decltype(t + u) {
    return t + u;
}
```

**尾随返回类型**也是 C++11 新特性之一，就是用在这种需要根据函数形参类型判断返回值类型的场景中。 
