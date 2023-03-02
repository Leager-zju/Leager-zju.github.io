---
title: Effective C++ の Note
author: Leager
mathjax: true
date: 2023-03-01 16:55:34
summary:
categories:
    - Book Reading
tags:
    - C++
img:
---

久仰本书大名，花了若干时间入门 C++ 后，终于可以拜读一下这部经典作品。

> 当 C++ 律师！

<!--more-->

## 1. 视 C++ 为一个语言联邦

C++ 高效编程守则视情况而变化，取决于使用 C++ 的哪一部分。

> `C++` = `C` + `Object-Oriented C++` + `Template C++` + `STL`。

## 2. 尽量以 const, enum, inline 替换 #define

或可以说“尽量用编译器代替预处理器”。

1. 对于常量，尽量以 `const`, `enum` 替换。

    ```c++
    #define PI 3.1415926
    // 改为
    const double pi = 3.1415926;
    ```

    如果在代码出现 `PI` 的地方产生了编译错误，编译器只会看到被预处理器替换掉的文本 `3.1415926`，而察觉不到 `PI` 的存在，只会在报错信息中给出一串数字。此时很难定位到出错位置，尤其是将 `#define` 写在其它头文件中的时候——这太糟糕了！

    最大的原因还是在于，编译器看不到 `PI`，因为已经被替换掉了，故无法在**符号表**中找到它。同时预处理器盲目进行文本替换还会可能导致目标代码中出现多份 `3.1415926` 这样的数字。

    而替换为 `const` 则不会出现这一问题，编译器会将 `const` 变量加入符号表，避免了上述错误。`const` 还能进行常量指针的定义，并且 `const` 还能为一个类创建专属常量，自由控制访问级别以及静态与否。这些都是 `#define` 做不到的，毕竟 `#define` 不存在作用域这一说法，也不会进行类型检查。

    > 具体区别请看[**此处**](../../C-Basic/C-Const/#与宏定义的区别)。

2. 对于形似函数的宏，尽量以 `inline` 替换。

    ```c++
    #define FUNC_MAX(a, b) f((a) > (b) ? (a) : (b))
    // 改为
    template<class T>
    void func_max(const T& a, const T& b) {
      f(a > b ? a : b);
    }
    ```

    用宏定义函数属于是最**丑陋**的行为了，因为你需要时刻关心是否正确添加括号。并且有些调用还不一定得到正确反馈，比如下面 `a++` 的调用次数取决于比较的对象：

    ```c++
    int a = 1, b = 0;
    FUNC_MAX(a++, b);    // a++ 调用 2 次
    FUNC_MAX(a++, b+10); // a++ 调用 1 次
    ```

    而[**内联函数**](../../C-Basic/C-Inline)则不会出现上述问题。`func_max()` 成为了真正的函数，遵循作用域和访问规则，能利用泛型的同时，增加了类型检查，同时和 `const` 一样能在类内大显身手，故更为推荐。

但这并不是说预处理器就一无是处了，我们依然需要依靠 `#include` 来引入头文件，以及依赖 `#ifdef`，`#ifndef` 来控制编译。就像最开始说的那样，**尽量用编译器代替预处理器**。

## 3. 尽可能使用 const

> 关于 `const` 可参见[**本文**](../../C-Basic/C-Const)

`const` 更像是一种约束，只要某个变量确定性地能保持不变，我们应该尽可能加上这一约束，以取得编译器的优化。反之，则容易被玩坏，比如：

```c++
class Rational {
 public:
  Rational operator*(const Rational& lhs, const Rational& rhs) { /* ... */ }
};

Rational a, b, c;

if (a * b = c) {
  /* ... */
}
```

我们或许可以宽容地接受 `a * b = c` 本来是想执行比较，但因为某些原因少打了一个 `=` 这一事实。如果 `operator*` 返回值没有声明为 `const`，编译器并不会因此报错，毕竟非 const 变量允许被赋值。不考虑这一点，对函数返回值进行赋值也是个糟糕的行为——右值是不能被赋值的。即便假设编译器忽视了所有问题，程序能够成功运行下去，最终结果也可能并不如人意——该 if 子句很难保证能进去。

将返回值声明为 `const` 则可以预防上面一系列令人头疼的问题，我们需要做的不过是多打几个字符罢了。

### 在 const 和 non-const 成员函数中避免重复

虽然对于成员函数而言，const 与 non-const 是两种重载形式，但如果仅有约束不同，也是一件不好的事。我们拿 [C++のMutable](../../C-Basic/C-Mutable/#类中的-mutable) 里的 `TextBlock` 的例子来说：

```c++
class TextBlock {
 public:
  TextBlock(const char* s) { /* ... */ }

  const char& operator[](std::size_t index) const {
    /* ... */
    return pText[index];
  }

  char& operator[](std::size_t index) {
    /* ... */
    return pText[index];
  }

 private:
  char* pText;
};
```

我们实现了 const 与 non-const 两个重载版本，供不同常量性的对象调用。但细心的人会发现，除了是否 const 以外，其他部分几乎完全一致！这就存在一个问题：一旦往某个函数中加各种比如并发支持、完整性检查等功能，另一个函数也必须要加上同样的代码——为了保证我们希望的一致性——从而导致文件变得臃肿，反而降低可读性。尽管 ctrl cv 降低了编码难度，但总归不太方便。

一个**明智**的做法是利用 non-const 版本调用 const 版本，从而避免**代码重复**：

```c++
class TextBlock {
 public:
  TextBlock(const char* s) { /* ... */ }

  const char& operator[](std::size_t index) const {
    /* ... */
    return pText[index];
  }

  char& operator[](std::size_t index) {
    return const_cast<char&>(static_cast<const TextBlock&>(*this)[position]);
  }

 private:
  char* pText;
};
```

在 non-const 版本中将 `*this` 转型为 const，便能调用 const 函数，最后通过 `const_cast` 移除常量性。代码瞬间精简不少！尽管，[使用 cast 是一个糟糕的想法](./#1-视-c-为一个语言联邦)，但在这里，很安全。

而另一种做法，即通过 const 函数调用 non-const 函数，则是一种错误行为，为了不冒 const 风险，不建议采取这种做法。

## 4 确定对象被使用前已先被初始化

C++ 并不能保证变量在所有语境下声明时都能得到初始化，但能保证读取未初始化的值会导致 **UB**。

与其记忆哪些语境下会初始化，哪些语境下不会，不如选择**永远在使用对象前将其初始化**。

对于内置类型，我们应当手动初始化；而对于非内置类型，则需要用到构造函数，并保证初始化每一个成员变量，此时只有两种方式：要么赋值，要么初始化列表。

```c++
// 赋值
class Entry {
 public:
  Entry(const std::string& name, const std::string &address) {
    myName = name;
    myAddress = address;
  }
 private:
  std::string myName;
  std::string myAddress;
};
```

```c++
// 初始化列表
class Entry {
 public:
  Entry(std::string const& name, std::string const& address)
  :myName(name),
   myAddress(address) {}
 private:
  std::string myName;
  std::string myAddress;
};
```

**第二个版本比第一个版本效率更高**。事实上，类成员变量的初始化行为发生在构造函数之前（见[**构造顺序**](../../C-Basic/C-OOP/#派生类构造顺序)），所以对于大多数类型而言，赋值行为会先调用默认构造函数，然后再使用赋值运算符，这样就导致默认构造函数的操作被浪费，增加无意义的开销并不是一件好事。并且如果某个变量的默认构造函数被**弃置**，编译器还会报错。

而使用初始化列表的方式，则只会影响这些成员变量调用构造函数的版本，相当于是拿着指定的实参去调用构造函数。此时只需调用一次构造，比起赋值的方法高效许多。对于内置类型，两种方式开销一样，但为了一致性还是通过初始化列表来初始化。

最后需要关心的事就是 non-local static 变量了，