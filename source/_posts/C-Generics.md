---
title: C++ の 泛型编程(Generics)
author: Leager
mathjax: true
date: 2023-02-28 11:11:02
summary:
categories: C++
tags: C++ Basic
img:
---

**泛型编程**是程序设计语言的一种风格或范式，允许程序员在编写代码时使用一些以后才指定的类型，在实例化时作为参数指明这些类型。在 C++ 里，这是与 OOP 并列的一大分支，通过**模板**来实现。

<!--more-->

## Why 模板？

现在有一个需求，就是写一个简单的 `swap` 函数，要求支持所有内置类型。在模板出来以前，C++ 允许同名函数重载，于是我们可以针对不同类型分别定义。`int`、`double`、`char`、……写着写着发现，我们最后需要实现的函数的数量是所有内置类型总数的平方！并且一旦后续添加了更多类型，我们又要编写更多函数！（不失为一个提高代码量的好方法，但毫无意义）并且维护代码的成本变得极高，一旦某一个 `swap` 函数出了问题，我们需要在巨大的头文件中找到那个出错的函数，仿佛大海捞针一般。

针对这些缺点，C++ 提出了**泛型编程**，也就是写一种与类型无关的代码，或者说是提供一个模板，提高代码的复用性。所谓**模板**，便是给定一套规范以及一定的占位符，根据用户后续对占位符进行不同形式的填充来产生不同的效果。C++ 里可以通过模板来定义一族函数、一族类，甚至是一族变量。

## 函数模板

**函数模板**定义一族函数。

```c++
template<模板形参列表> 函数声明;
```

**模板形参**可以是以下项的任意排列组合：

1. **非类型形参**：仅允许带有 cv 限定的左值引用、指针、整型、枚举类型，类对象以及字符串是不允许的，C++20 起还允许浮点型；
2. **类型形参**：形如 `typename|class T`，类型名 `T` 是可选的；
3. **模板形参**：形如 `template<形参列表> typename|class T`，类型名 `T` 是可选的；
4. 上述的**形参包**；

```c++
// 于是 swap 函数可以写成这样
template<class T>
void swap(T& first, T& second) {
  T temp = first;
  first = second;
  second = temp;
}
```

**注意**，函数模板自身并不是类型、函数或任何其他实体，不会从只包含模板定义的源文件生成任何代码。函数模板只有**实例化**后才会有代码出现。所谓**实例化**，就是用实参填充模板形参列表，让编译器生成指定类型函数，不用定义函数实现。实例化一个函数模板需要知道它的所有模板实参，但不需要指定每个模板实参，允许编译器进行**隐式实例化**，即**模板实参推导**，即尽可能从函数实参推导缺失的模板实参。

```c++
int main() {
  int a = 1, b = 2;
  swap(a, b); // 隐式实例化。允许省略尖括号，编译器会自动进行模板实参推导
              // 推导结果为 swap<int>
  std::cout << a << " " << b;
}
// output: 2 1
```

> 在模板出现以前，对同名函数的重载如果只有某些值的类型不同，那么需要为每一个值定义一遍函数，这是非常麻烦的。有了模板，就能直接在函数名后用尖括号带上特定的类型即可。

对于特定的实现，我们或许不想要依照原来函数模板那样执行，而是自定义函数体，这也是可以的。**函数模板特化**能够将某一个或某几个要处理的数据类型进行单独处理，但需要额外定义对应数据类型的模板函数，比如：

```c++
template<char>
void swap(char& first, char& second) {
  std::cout << "我不 swap，哎，就是玩\n";
}

int main() {
  char a = 'a', b = 'b';
  std::cout << func(a， b); // 推导结果为 func<char>，于是使用特化的函数模板
}
// output: 我不 swap，哎，就是玩
```

如果同时又加上一个这样的普通函数：

```c++
char swap(char& first, char& second) {
  std::cout << "只因你太美\n";
}
```

那么原来的代码会输出 `只因你太美`，这是因为在省略尖括号时，编译器在**编译时**会试图优先将其识别为普通函数，此时如果找到对应的普通函数，则直接调用，而不会进行后续的实参推导。如果希望优先识别为特化后的模板函数，则需要加上尖括号，这样才能让编译器知道噢原来这是个模板函数。

> 实际上，调用顺序为**普通函数 > 模板特化函数 > 模板函数**。

## 类模板

与函数模板一样，**类模板**定义一族类。

```c++
template<模板形参列表> 类声明;
```

模板形参列表与函数模板完全一致。**注意**，类模板自身并不是类型、对象或任何其他实体，不会从只包含模板定义的源文件生成任何代码。类模板同样只有**实例化**后才会有代码出现，并且也支持**类模板实参推导**，即尽可能从类构造函数实参推导缺失的模板实参。此外，类模板的**特化**还进一步分为了**全特化**与**偏特化**。

```c++
#include <iostream>

template <class First, class Second>
class MyPair {
 public:
  MyPair(First f_, Second s_) : f(f_), s(s_) {
    std::cout << "No specialization: " << f << ' ' << s << '\n';
  }
  void show();

 private:
  First f;
  Second s;
};

template <class First, class Second>
void MyPair<First, Second>::show() {  // 类模板的函数在类外实现，需要加上模板参数列表
  std::cout << f << " " << s << "\n";
}

// 偏特化 1
template <class First>
class MyPair<First, char> { // 偏特化时需加上模板参数列表，以指明特化了哪个形参
 public:
  MyPair(First f_, char s_) : f(f_), s(s_) {
    std::cout << "specialization <First, char>: " << f << ' ' << s << '\n';
  }

 private:
  First f;
  char s;
};

// 偏特化 2
template <class Second>
class MyPair<int, Second> {
 public:
  MyPair(int f_, Second s_) : f(f_), s(s_) {
    std::cout << "specialization <int, Second>: " << f << ' ' << s << '\n';
  }

 private:
  int f;
  Second s;
};

// 全特化
template <>
class MyPair<int, char> {
 public:
  MyPair(int f_, char s_) : f(f_), s(s_) {
    std::cout << "specialization <int, char>: " << f << ' ' << s << '\n';
  }
 private:
  int f;
  char s;
};

int main() {
  MyPair<double, int> pair1(3.14, 1); // 显式实例化
  MyPair pair2(2.7, 'a');             // 推导结果为 MyPair<double, char>
  MyPair pair3(1, 'b');               // 推导结果为 MyPair<int, char>
}
// output:
// No specialization: 3.14 1
// specialization <First, char>: 2.7 a
// specialization <int, char>: 1 b
```

与函数模板不同的是，类模板不能与普通同名类共存，即若上述代码中又定义了一个 `class MyPair`，则编译报错。

## 派生

类模板、模板类和普通类之间可以互相派生。它们之间的派生关系有以下几种情况。

### 模板类的派生

```c++
template <class T>
class Base1 {};
    
// case 1.1: 模板类派生类模板
template <class T>
class Derive11: Base1<int> { T val; };

// case 1.2: 模板类派生普通类
class Derive12: Base<int> {};
```

### 类模板的派生

```c++
template <class T>
class Base2 {};
    
// case 2.1: 类模板派生类模板
template <class T>
class Derive21: Base2<T> {};
```

### 普通类的派生

```c++
class Base3 {};

// case 3.1: 普通类派生类模板
template <class T>
class Derive31: Base3 { T val; };

// case 3.2: 普通类派生普通类，略
```

## 多态

子类和父类的模板参数列表可以不一样，但必须一一对应。

```c++
template <class T, class U>
class Base {
 public:
  virtual void foo(T, U) = 0;
};

class Derive1 : public Base<int, char> {
 public:
  void foo(int a, char b) override {
    std::cout << "Derive1 foo():" << a << ' ' << b << '\n';
  }
};

template <class T, class U>
class Derive2 : public Base<U, T> {
 public:
  void foo(U a, T b) override {
    std::cout << "Derive2 foo():" << a << ' ' << b << '\n';
  }
};

int main() {
  Base<int, char>* ptr1 = new Derive1(); // 必须用 Base<int, char>* 指向，因为 Derive1 就是派生自该模板类
  ptr1->foo(1, '2');  // 调用 Derive1::foo(int, char)

  Base<int, double>* ptr2 = new Derive2<double, int>(); // 与继承顺序一一对应
  ptr2->foo(3, 3.14); // 调用 Derive2::foo(int, double)
}
// output:
// Derive1 foo():1 2
// Derive2 foo():3 3.14
```

> 上面代码写的不规范，按道理有虚函数的类应该为其设置一个虚析构函数，上面分别有两个特化的基类 `Base<int, char>` 与 `Base<int, double`，就需要分别定义两个特化类并设置虚析构函数。

## 成员模板

任意类都可以在体内嵌套声明类模板/函数模板。规则：

1. 析构函数和复制构造函数不能是模板；
2. 成员函数模板不能为虚，且派生类中的成员函数模板不能覆盖来自基类的虚成员函数；
3. 可以声明具有相同名字的非模板成员函数和模板成员函数。在冲突的情况下，执行效果如同之前讨论的函数模板那样；

## 形参包

形参包分为两种：

1. **模板形参包**是接受零个或更多个模板实参的模板形参；
2. **函数形参包**是接受零个或更多个函数实参的函数形参。

至少有一个形参包的模板被称作**变参模板**。

**变参类模板**可以用任意数量的模板实参实例化，以 `std::tuple` 为例，其定义为：

```c++
template<class... Types>
class tuple;

std::tuple<> t0;           // Types 不包含实参
std::tuple<int> t1;        // Types 包含一个实参：int
std::tuple<int, float> t2; // Types 包含两个实参：int 与 float
std::tuple<0> error;       // ERROR! 0 不是类型
```

**变参函数模板**也是同理，可以用任意数量的函数实参调用：

```c++
template<class... Types>
void f(Types... args);

f();       // OK：args 不包含实参
f(1);      // OK：args 包含一个实参：int
f(2, 1.0); // OK：args 包含两个实参：int 与 double
```

## 一些疑问

### Why 非类型模板形参？

> 把非类型模板形参放到函数参数列表里，或者类的构造函数里，不是效果也差不多吗，为什么要多此一举设置一个非类型模板形参呢？

首先要明确的一点是，非类型模板实参必须是 `constexpr` 且能转换为整类型的字面量，这就使得我们**能够利用一个在编译时可知的自定义参数**。而 `constexpr` 变量是不能用作函数形参的，如果是类构造函数，则无法进行自定义，所以总有缺陷。

`std::tuple` 的 `get()` 函数正是采用了非类型模板形参，而不是将下标参数作为函数参数，因为我们需要确定返回值的类型，而这无法在运行时确定。借助非类型模板形参，就可以在编译时确定返回值类型，还能提高运行效率。

> 本质上相当于是编译器为 `tuple` 里的每个元素都生成一个对应的获取函数。

### 类模板的声明和实现为什么不能放在不同的文件里？

对于普通类而言，声明可以放在 `.h` 文件中，而成员函数的实现可以写在 `.cpp` 里。这是因为多个 `.cpp` 会先被编译成若干目标代码文件 `.obj`，最后链接到一起形成可执行文件。在编译的过程中，编译器能够知道足够信息，比如形参类型，从而根据 `.cpp` 里的成员函数实现生成目标代码。

> 这也有利于对外隐藏实现，直接将实现文件打包成库，和头文件一起发布。

而对于类模板，如果也将成员函数实现写在 `.cpp` 里，比如

```C++ test.h
template<class T>
class test {
  public:
    T get();
    void set(const T& v);

  private:
    T value;
};
```

```C++ test.cpp
template<class T>
T test::get() {
  return value;
}

template<class T>
void set(const T& v) {
  value = v;
}
```

然后又在另一个 `.cpp` 文件里生成了 `test<int> t` 并且调用 `t.set(1)`，进行编译会报 `undefined reference` 错误。

《C++编程思想》第 15 章(P300)说明了原因：模板定义很特殊。由 `template<…>` 处理的任何东西都意味着编译器在当时不为它分配存储空间，它一直处于等待状态直到被一个模板实例告知。在编译器和连接器的某一处，有一机制能去掉指定模板的多重定义。所以为了容易使用，几乎总是在头文件中放置全部的模板声明和定义。

在调用 `t.set(1)` 的时候，由于当前文件里没有这一函数的定义，所以编译器仅仅是生成一个符号，并寄希望于链接器在其他 `.obj` 文件中找到该函数的定义。然而，正如上面说的，在处理 `test.cpp` 的时候，**编译器并不会对 `set()` 函数生成任何目标代码**——因为编译器根本不知道 `T` 实际是什么！所以最后链接的时候只能在头文件 `test.h` 里找到答案。

很遗憾，头文件中只有声明，没有定义。我们不知道调用的这个函数具体应该做什么，也就产生了上面那个错误。

为了解决这一问题，有两种方法：

1. 将声明和定义统一放在头文件中；
2. 将声明和定义分离，但在 `.cpp` 中显式实例化声明，比如下面这样：

```C++ test.cpp
template<class T>
T test::get() {
  return value;
}

template<class T>
void set(const T& v) {
  value = v;
}

template class test<int>; // 实例化声明
```

这样做的缺点就是必须为所有类型添加实例化声明，这样编译器才能在处理 `test.cpp` 时生成正确的目标代码。