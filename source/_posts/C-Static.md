---
title: C++ の 静态修饰符(Static)
author: Leager
mathjax: true
date: 2023-02-13 17:02:49
summary:
categories:
    - C++ Basic
tags:
    - C++
img:
---

`static` 是 C++ 中很常用的修饰符，它被用来控制变量的存储方式和可见性。

<!--more-->

### static 普通变量

`static` 修饰的普通变量存储在**静态区**，其生命周期延长至整个程序结束。只有第一次会执行初始化，若无初始值，则用默认值进行初始化。

```c++
class Foo {
 public:
  Foo() { std::cout << "Foo\n"; }
  ~Foo() { std::cout << "~Foo\n"; }
};

void func() { static Foo f; }

int main() {
  std::cout << "Start\n";
  func(); // 初始化 Foo f
  func(); // 不再对 f 初始化
  std::cout << "End\n";
}

// output:
// Start
// Foo
// End
// ~Foo
```

特别的，`static` 修饰**全局变量**时，这个全局变量只能在本文件中访问，不能在其它文件中访问，即便是 `extern` 外部声明也不可以。

### static 函数

`static` 修饰的函数仅在定义该函数的文件内才能使用。一般在多人开发项目时，为了防止与他人命名空间里的函数重名，可以这么做。

### static 类成员变量/类成员函数

`static` 修饰的类成员变量/类成员函数提供一层**类共享**语义，即该成员变量/函数**不属于任一对象，而是属于整个类**，在内存中只占用一份空间，可直接通过 `类名::成员变量名` 或 `类名::成员函数名` 访问，而不需要先创建对象。根据这一特点，静态函数中也就不存在 `this` 指针，也无法使用非静态成员变量。

> 非静态成员变量依附于特定的对象，而静态成员函数在类实例化之前就已经分配空间，此时非静态成员变量连个影子都见不到，更别说使用了。

```c++
class Foo {
 private:
  int non_static{0};

 public:
  // 静态函数既可在类内定义，也可在类外定义
  static void func1();      
  static void func2() {
    std::cout << non_static; // ERROR! 不能在静态函数中使用非静态变量
    func();                  // ERROR! 不能在静态函数中调用非静态函数
  }
  void func() { func1(); }   // OK! 可以在非静态函数中调用静态函数，这里的 func1 并不会隐式使用 this

  static int val1；
  static const int val2{0}; // 静态常量只能在类内定义
};

void Foo::func1() {}
int Foo::val1 = 1;  // 静态非常量只能在类外定义

int main() {
  Foo::func1(); // OK!
  Foo::func();  // ERROR! 不能用此法调用非静态函数
    
  Foo f;
  f.func1();    // OK! 既然 func1 属于 Foo 类，那么任一对象均可调用该函数
}
```

需要注意的是：

- 静态成员变量必须先初始化；
- 构造函数与析构函数、运算符重载这类特殊函数不能用 `static` 进行修饰；



