---
title: C++11 の 委托与继承的构造函数(Delegating & Inherited constructors)
author: Leager
mathjax: true
date: 2023-02-03 15:05:39
summary:
categories: c++
tags: C++11
img:
---

**委托构造函数**与**继承构造函数**并非独立的新构造函数，而是 C++11 新增的用于提高编码效率的特性。

<!--more-->

## 委托构造函数

**委托构造函数**允许构造函数通过初始化列表调用同一个类的其他构造函数，相当于将自己的构造职责**委托**给了其它构造函数。目的是简化构造函数的书写，提高代码的可维护性，避免代码冗余膨胀。

```cpp
// 不使用委托，显得十分臃肿且冗余
class A {
 public:
  A(char i_) {
    i = i_;
    j = 0;
    display();
  }
  A(char i_, int j_) {
    i = i_;
    j = j_;
    display();
  }
 private:
  char i;
  int j;
  void display();
};

// 使用委托，精简干练
class A {
 public:
  A() { display(); }
  A(char i_): A() { i = i_; j = 0; }    // 委托构造函数
  A(char i_, int j_): A(i_) { j = j_; } // 委托构造函数
 private:
  char i;
  int j;
  void display();
};
```

一个委托构造函数也有一个成员初始化列表和一个函数体，成员初始化列表只能包含一个其它构造函数，且参数列表必须与已有的构造函数匹配。初始化列表里**不能**再包含其它成员变量的初始化，只能在函数体中对变量进行赋值。

### 注意事项

委托构造不能形成循环，比如下面这种代码：

```cpp
class A {
 public:
  A(char i_): A(i_, 'c') {}
  A(char i_, int j_): A(i_) { j = j_; }
 private:
  char i;
  int j;
};
```

`A(int i_)` 与 `A(int i_, char j_)` 反复调用对方形成循环，这样会导致编译错误。

## 继承构造函数

子类为完成基类初始化，在 C++11 之前，需要须要在构造函数中**显式**声明，即在初始化列表调用基类的构造函数，从而完成构造函数的传递。如果基类拥有多个构造函数，那么子类也需要实现多个与基类构造函数对应的构造函数，比如：

```cpp
class Base {
 public:
  Base() { display(); }
  Base(char i_): Base() { i = i_; j = 0; }
  Base(char i_, int j_): Base(i_) { j = j_; }

 private:
  char i;
  int j;
  void display() {
    std::cout << i <<  " " << j << std::endl;
  }
};

class Derived: public Base {
 public:
  Derived(char i_): Base(i_) {}
  Derived(char i_, int j_): Base(i_, j_) {}
};
```

如果仅仅是为了完成基类的初始化，那么这样的做法显得非常冗余，代码的书写开销高达 $O(n)$！

从 C++11 开始，我们可以直接使用 `using Base::Base` 的方式来将基类中的构造函数全继承到派生类中，而无需重复书写，比如：

```cpp
class Base {
 public:
  Base() { display(); }
  Base(char i_): Base() { i = i_; j = 0; }
  Base(char i_, int j_): Base(i_) { j = j_; }
  // private 部分略
};

class Derived: public Base {
 public:
  using Base::Base;
};
```

和上面那种写法是等价的，比如使用 `char` 变量去初始化 `Derived` 类变量时，会调用 `Base(char)` 去初始化基类，然后调用 `display()` 打印输出。更巧妙的是，这是**隐式**声明继承的，即假设一个继承来的构造函数不被相关的代码使用，编译器不会为之产生真正的函数代码，这样比显式书写各种构造函数更加节省代码量。

### 注意事项

**继承构造函数**的注意事项较多，一一说明。

1）继承构造函数无法初始化派生类数据成员。这很显然，因为继承来的构造函数仅对基类进行初始化。如果要初始化派生类变量，有两种做法。一是使用 `=` / `{}` 对非静态成员就地初始化，二是额外书写构造函数，两种做法各有优劣，第一种减少了代码量，第二种更加灵活，需根据具体应用场景进行选择。

2）当派生类拥有多个基类时，如果多个基类中的部分构造函数的参数列表（中的类型与顺序）完全一致，那么派生类中的继承构造函数将产生冲突，比如：

```cpp
class A {
 public:
  A(int i) {}
};
class B {
 public:
  B(int i) {}
};
class C: A, B {
 public:
  using A::A; // 等价于 C(int i): A(i) {}
  using B::B; // 等价于 C(int i): B(i) {}
  C(int i): A(i), B(i) {} // 应显式声明会产生冲突的构造函数，会将上面两个"等价于"覆盖，阻止了隐式生成对应的构造函数，避免了冲突
};
```

3）若基类构造函数声明为 `private`，则派生类无法使用该构造函数；若为 `public`，即便 `using` 处于 `private` 中，也能使用。比如：

```cpp
class A {
 public:
  A(int i) {}
 private:
  A(int i, int j) {}
};

class B: A {
 private:
  using A::A;
};

B p(1);    // OK! although using is private
B q(1, 2); // ERROR! A(int, int) is private
```

> 网上好多文章提到两点：
>
> 一是若基类构造函数存在默认值，则无法继承该默认值；
>
> 二是若派生类是是从基类虚继承的，那么就不能在派生类中继承构造函数；
>
> 但这两点在实践中都被推翻，但我也无法判断是否是错，这两点存疑。代码如下：
>
> ```cpp
> class A {
>  public:
>   A(int a = 3, double b = 4): _a(a), _b(b){ display(); }
>   void display() { std::cout << _a << " " << _b << std::endl; }
>
>  private:
>   int _a;
>   double _b;
> };
>
> class B: virtual A {
>  public:
>   using A::A;
> };
>
> class C: virtual A {
>  public:
>   using A::A;
> };
>
> class D: B, C {
>   using B::B;
>   using C::C;
> };
>
> int main() {
>   B b(1);
>   D d();
> }
> // output:
> // 1 4
> // 3 4
> ```
>
> 从输出易得 `B`，`C` 确实从 `A` 处继承来了构造函数，并且默认值也得到了继承。
