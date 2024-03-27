---
title: C++ の 异常处理(Exception)
author: Leager
mathjax: true
date: 2023-03-01 11:31:18
summary:
categories: C++
tags: C++ Basic
img:
---

**异常**，在操作系统中指的是指令内部出现的"**内中断**"，如除数为零，地址越界等。这些情况在程序中也时有发生，C++ 为了应对偶发的程序异常事件，引入了**异常处理**机制。其基于三个关键字：`try`，`throw` 与 `catch`。

<!--more-->

## 异常处理流程

一个完整的异常处理流程如下：

```c++
try {
  /* code */
  throw SomeException;
} catch (ExceptionType_1& e1) {
  /* Response to exception */
} catch (ExceptionType_2& e2) {
  /* Response to exception */
} catch (ExceptionType_3& e3) {
  /* Response to exception */
}
```

`try` 块会正常执行代码，而 `throw` 表达式则是针对性地抛出一个**异常对象**。

> 理论上，你可以在 `try` 内任何地方使用 `throw` 语句抛出异常。

一旦抛出了异常，则 `try` 块后续不再执行，而是进行**栈回溯**：

1. 异常对象构造完成时，以当前 `try-catch` 层为起点；
2. 按出现顺序将当前层每个 `catch` 块的形参类型和异常对象类型进行比较，如果当前层存在匹配，那么控制流跳到匹配的 `catch` 块；
3. 反之，**逃逸**到外层，若此时依然处于 `try-catch` 块内，则重复步骤 2；
4. 调用 `std::terminate()` 终止程序。

> 匹配规则为：
>
> - 形参类型与抛出类型**相同**，或
> - 形参类型为抛出类型的**左值引用**、**基类**、**基类引用**；
>
> 所以如果派生类的 `catch` 在基类的 `catch` 之后，那么按照顺序策略，派生类子句将永远无法执行——能被派生类接收的一定能被基类接收。
>
> **注意**，`throw` 出的异常对象类型取静态类型，即便存在运行时多态。
>
> ```c++
> class Base {
>  public:
>   virtual ~Base() = default;
> };
> 
> class Derived : public Base {
>  public:
>   virtual ~Derived() = default;
> };
> 
> int main() {
>   try {
>     try {
>       Derived d;
>       Base* b = &d;
>       std::cout << "make exception " << typeid(*b).name() << '\n';
>       throw *b;
>     } catch (Derived& d) {
>       std::cerr << "catch " << typeid(d).name() << " success";
>     }
>   } catch (Base& b) {
>     std::cerr << "catch " << typeid(b).name() << " success";
>   }
> }
> // output:
> // make exception 6Derive
> // catch 4Base success
> ```
>
> 尽管 `*b` 在 `typeid` 算子下为 `Derived` 类型，但抛出后仍被识别为 `type Base`，无法被 `Derived&` 接收。于是栈回溯到外层，与 `catch(Base&)` 子句匹配，执行对应的代码。

当然，你甚至可以在 `try-catch` 外再套一层 `try-catch`，是为**重抛**：

```c++
try {
  try {
    throw SomeException;
  } catch (ExceptionType& e) {
    /* Do somthing */
    // throw e; // 复制本子句接受到的异常对象 e，然后抛出新的异常对象，e 被释放
                // 这里的 e 可以改为其它任意新声明的异常对象，比如 ExceptionType e1; throw e1;
    throw;      // 重抛出本子句接受到的异常对象 e，不会额外复制
  }
} catch (ExceptionType& e) {
  /* Do something */
}
```

**异常对象**指的是由 `throw` 表达式在未指明的存储中构造的**临时对象**，不允许出现任何**[不完整类型](https://zh.cppreference.com/w/cpp/language/type#.E4.B8.8D.E5.AE.8C.E6.95.B4.E7.B1.BB.E5.9E.8B)**、**抽象类**、**右值引用**或**指向不完整类型的指针**（`void*` 除外）的异常对象。并且对于异常对象类，其构造、析构函数必须公开。

与其他临时对象不同，异常对象在初始化 `catch` 子句形参时被认为是左值，所以它可以用左值引用捕获、修改及重抛，并且将驻留在所有可能激活的 `catch` 语句都能访问到的内存空间中，在成功匹配的 `catch` 语句的结束处被自动析构。

异常对象存放在内存的**特殊位置**，既不是栈也不是堆，**该对象由异常机制负责创建和释放**，所以避免 `throw new` 的做法，存在内存泄漏的问题。bugfree 起见，**强烈建议**使用派生自 `std::exception` 的类型来抛出异常对象，并且按**左值引用**捕获！

### std::excecption

`std::exception` 是所有异常类的基类，提供统一接口，比如 `typeid`、`dynamic_cast`、`new` 抛出的异常都是派生自该类。如果希望自定义异常派生类，则需要实现的 public 函数有：

1. 默认构造函数/初始化构造函数；
2. 拷贝构造函数；
3. 拷贝赋值运算符；

基类有一个虚函数 `virtual const char* what() const noexcept`，用于返回解释该异常类型的字符串，一般通过重写该虚函数来实现表明不同异常的功能。

## noexcept

声明为 `noexcept` **说明符**的函数能够确定性地不抛出异常，也可以通过声明为 `noexcept(expr)` 的方式，若 `expr = true` 则等效于 `noexcept`；反之表明可能抛出异常。如果一个函数声明了 `noexcept` 还抛异常，编译能过，但会直接 `terminate()`。关于 `noexcept` 函数，有以下几点值得注意：

1. 只有异常说明不同的函数无法实现重载。

    ```c++
    void foo() noexcept;
    void foo();  // ERROR!
    ```

2. 指向不会抛出的函数的指针能**赋值**给或**隐式转换**到指向可能抛出的函数的指针，反之不可；
3. 不抛异常的函数**允许调用**可能抛出的函数，如果该异常未被 `catch`，则 `terminate()`；
4. 如果基类虚函数不会抛出，那么所有派生类只要覆盖了该虚函数，无论声明还是定义，都必须不抛出；

C++17 以前还会用 `throw(类型列表)` 来显式列出函数可能抛出的异常，如果写作 `throw()` 则等效于 `noexcept`，但 C++17 已将 `throw(类型列表)` 移除，且后面的 C++20 也把 `throw()` 给移除了，故不再深究。

`noexcept` 还可以当成一个算子，如果 `expr` 不抛出异常，则 `noexcept(expr)` 返回 `true`，反之亦然。

**注意**，`noexcept` 说明符不是一种编译时检查，只不过告知编译器函数是否会抛出异常。对于不会抛出的函数，编译器会进行更多优化。构造函数、析构函数、赋值运算符这些均隐式不抛出，除非其内部存在抛出的可能，也可以手动实现为可能抛出，而其它函数则不具备这一性质，所以如果明确知道某函数不抛异常，则可以显式指明 `noexcept`。
