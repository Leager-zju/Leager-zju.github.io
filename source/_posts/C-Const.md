---
title: C++ の 常量(Const)
author: Leager
mathjax: true
date: 2023-02-13 12:30:00
summary:
categories: C++
tags: C++11
img:
---

const 与 volatile 一起并称 **CV 限定符**，用于指定被声明对象或被命名类型的常量性或易变性。

<!--more-->

const 全称 **constant**，其指定一个约束，告知编译器该变量无法被修改。对于那些明确不发生改变的变量，应尽可能使用 `const`，以获得编译器的帮助。

## const 普通变量

声明时，`const` 与 `typename` 顺序可以互换，并且可以直接初始化常量，之后就不能对常量进行修改了。

```c++
const int a;         // OK!
int const b = 0;     // OK!

int c = 1;
a = c;               // ERROR! 无法对 const 进行修改
c = a;               // OK!

int const nums[10];  // OK!
```

## const 指针

const 搭配指针使用时，也会出现不同的顺序：

1. **底层 const**：`const` 位于 `*` 之**前**，是为**常量指针**，表明指针指向的变量为常量，无法通过指针修改指向的对象；
2. **顶层 const**：`const` 位于 `*` 之**后**，是为**指针常量**，表明指针为常量，无法修改指针变量本身；

```c++
const int foo = 0;
int bar = 1;

int *p = &foo;             // ERROR! 常量只能被常量指针指向
int *q = (int*)&foo;       // OK!

const int* a = &foo;       // OK! 常量指针
int const* b = &bar;       // OK! 可以指向非常量，但无法通过 *b = ? 的方式修改变量 bar
int* const d = &bar;       // OK! 指针常量
const int* const d = &foo; // OK! 指向常量的常量指针

// *a = 1, d = &foo 这些操作都是编译报错的
```

上面这段代码其实存在漏洞，即将 `foo` 的地址强转为 `int*` 类型并赋值给了 `int* q`。这是不安全的，因为 `p` 并不是常量指针，可以凭借 `p` 修改指向的变量，如果加上下面这段代码，则会发现一些奇妙的事：

```c++
(*q)++;
std::cout << q << " " << *q << "\n"
          << &foo << " " << foo << " " << *(&foo);
// output:
// 0x78fe0c 1
// 0x78fe0c 0 1
```

不难发现，`q` 与 `&foo` 为同一个地址，但奇怪的是，`*q` 与 `foo` 值不同，并且 `foo` 竟然与 `*(&foo)` 的值也产生了差异！

Actually，函数中定义的常量放在内存的**栈**区，而栈内存是可以通过指针修改的，不过即使修改了这块内存，在程序中仍然看起来没有修改常量，这是因为 C++ 编译器对 const 做了优化——当编译器遇到 `foo` 的定义时，会在内存的某个位置开辟一张表，然后将 key-value 对 `{foo, 0}` 写入该表，这就相当于将常量 0 绑定在符号 `foo` 上，之后每次取数据 `foo` 时，虽然运行时栈会为 `foo` 分配内存，但不是取栈中地址对应的值，而会去查这张表，然后用 value: 0 直接代替。

所以尽管指针 `p` 对地址上的值进行了修改，打印 `foo` 时我们得到的并不是真正的地址 `&foo` 上的值。

但并不是所有的常量声明时都是如此，比如将上面的代码略作修改：

```c++
// case 1
int bar = 0;
const int foo = bar;

int *q = (int*)&foo;

(*q)++;
std::cout << q << " " << *q << "\n"
          << &foo << " " << foo << " " << *(&foo);
// output:
// 0x78fe0c 1
// 0x78fe0c 1 1
```

```C++
// case 2
constexpr int bar = 0;
const int foo = bar;

int *q = (int*)&foo;

(*q)++;
std::cout << q << " " << *q << "\n"
          << &foo << " " << foo << " " << *(&foo);
// output:
// 0x78fe0c 1
// 0x78fe0c 0 1
```

发现上面两个 case 唯一的区别在于变量 `bar` 是否为 [**constexpr**](../../C/C-Else/#constexpr)，换句话说，就是用于初始化 `foo` 的变量值是否在编译时可知。如果只有到了运行时才能确定常量 `foo` 的值，那么编译器并不会写 key-value 进表，而是表现地像 C 语言一样，直接从栈上获取数据；反之，如果在编译时就能确定值（比如上面那个 `const int foo = 0;`），编译器就会跟我们上面讨论的一样运作。

> 所以有些时候改用 `constexpr` 是更好的选择。

而如果对**全局变量**进行 `const` 约束，此时变量分配在**静态区**，那么无论怎样都无法修改。

```c++
const int a;

int main() {
  int *p = (int*)&a;
  (*p)++; // ERROR!
}
```

## const 引用

修饰引用时，`const` 只能位于 `&` 左侧，毕竟引用变量本身一经初始化就无法更改，自带 const 语义。这种情况下，const + 引用均视为**常量引用**，即引用的变量为常量，无法修改。

```c++
const int foo = 1;
int bar = 2;

const int& a = foo; // OK!
const int& b = bar; // OK!
int const& c = foo; // OK!
int& const d = foo; // ERROR!

// a = 1 编译报错
```

## const 函数

const 与函数搭配只有两种情况：

1. **修饰形参**。此时函数体内无法修改 const 修饰的形参；
2. **修饰函数返回值**。

## const 类成员变量

类中定义常量主要有以下实现方式：

1. **枚举**。此时枚举变量相当于静态变量，在编译时可知。

    ```c++
    class A {
     public:
      enum test { foo, bar };  // static
      int nums1[test::foo];
      int nums2[test::bar];
    };

    std::cout << A::test::foo; // output: 0
    ```

2. **const 修饰**。仅用 const 修饰的变量为非静态变量，只有在运行时才能确定值。仅能在构造函数的初始化列表进行初始化，或者直接就地初始化。此后无法再修改。

    ```c++
    class A {
     public:
      const int foo{0};
      int bar[foo];          // ERROR! invalid use of non-static A::foo
      // A() { foo = 1; }    // ERROR!
      A(): foo(1) {}
      void test() { foo++; } // ERROR! foo is const
    };
    ```

## const 类成员函数

除了普通函数的用法外，类成员函数还可以在函数体前加上 `const` 修饰符，表明该成员函数不会修改任何非 [mutable](../C-Mutable) 关键字修饰的成员变量。此时 this 隐式为 `const *`（更严谨地说应该为 `const *const`，因为 this 不可修改指向），表明在该函数体内，编译器将该对象视为 const 对象。对于 const 对象，只能调用 const 成员函数，因为非 const 函数无法保证不会修改成员变量。

```c++
class Foo {
 public:
  void show() const {
    std::cout << bar;
    bar++;               // ERROR!
    Foo* p = this;       // ERROR! this 为 const Foo*
    const Foo* q = this; // OK!
  }
 private:
  int bar{1};
};
```

此外，`const` 类成员函数亦可与不加 `const` 的同名成员函数产生不同重载版本。至于调用哪个重载版本，就看调用的对象是否为常量，如果是常量，则调用 const 版本，否则调用非 const 版本。

```c++
class Foo {
 public:
  // 两个重载版本
  void show() const { std::cout << "const\n"; }
  void show() { std::cout << "non-const\n"; }
};

int main() {
  Foo a;
  const Foo b;
  const Foo* c = &a;
  a.show();
  b.show();
  c->show();
}

// output:
// non-const
// const
// const
```

## 与宏定义的区别

|     宏定义 #define     |   常量 const   |
| :--------------------: | :------------: |
| 宏定义，相当于字符替换 |    常量声明    |
|      预处理器处理      |   编译器处理   |
|     无类型安全检查     | 有类型安全检查 |
|       不分配内存       |   要分配内存   |
|      存储在代码段      |  存储在数据段  |
|  可通过 `#undef` 取消  |    不可取消    |