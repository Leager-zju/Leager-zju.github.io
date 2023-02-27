---
title: C++ の 类型转换(Cast)
author: Leager
mathjax: true
date: 2023-02-27 10:04:11
summary:
categories:
    - C++ Basic
tags:
    - C++
img:
---

当表达式期望为 `T` 类型，而我们只能产生 `S` 类型的表达式时，就需要利用**类型转换**功能来满足需求。

<!--more-->

### Cast in C

C 中的类型转换语法非常简单粗暴，直接在表达式前加上 `(Target_Type)` 即可，如：

```c++
double pi = 3.14;
int p = (int)pi;
std::cout << p; // output: 3
```

但这种粗暴的强转会带来许多难以察觉的安全性问题。于是，C++ 提供了许多应用场景更广泛的转换算子，用于删除 C 语言转换中的一些多义性和危险继承。

### Cast in C++

#### static_cast

```c++
static_cast<new_type>(expr);
```

该算子实现的效果与 C 中的强转差不多，但由于**没有**在运行时进行类型检查来确保安全性，故跟 **Cast in C** 一样存在隐患，用于**非多态对象**的转换。

> 所谓**多态对象**，就是声明或继承了至少一个虚函数的**类类型**的对象。每个多态对象中，实现都会储存额外的信息，它被用于进行虚函数的调用，**RTTI** 功能特性也用它在运行时确定对象创建时所用的类型，而不管使用它的表达式是什么类型。
>
> 对于**非多态对象**，值的解释方式由使用对象的表达式所确定，这在编译期就已经决定了。

通常用于数值类型的相互转换，比如浮点型到整型（如 `double` 到 `int`），整型到字符型（如 `int` -> `char`）等。

> 得到的 `char` 可能没有足够的位来保存整个 `int` 值，故需要程序员来验证转换的结果是否安全。

但在类的层次结构之间进行转换时，比如将基类指针**向下转换**为派生类指针这一操作，由于派生类可能有自己新定义的字段或信息，故**向下转换是不安全**的。但**向上转换一定是安全**的，因为派生类一定包含基类的所有信息。

```c++
class B {};
class D: public B {
 public:
  int val;
};

void Foo(B* pb, D* pd) {
  D* pd1 = static_cast<D*>(pb); // not safe! D::val 不在 B 中。
                                // 如果此时 pb 指向一个非 D 类对象，则调用 pd1->val 出错。
  B* pb1 = static_cast<B*>(pd); // safe! 基类指针一定能指向所有派生类
}
```

#### dynamic_cast

```c++
dynamic_cast<new_type>(expr); // 其中 new_type/expr 必须为指针或引用。若 new_type 为指针，则 expr 必须为指针；如为引用，则 expr 为左值
```

与 `static_cast` 相对，`dynamic_cast` 在运行时执行类型检查，故用于**多态对象**的转换，且更加安全。具体表现为：

- 如果转型成功，那么 `dynamic_cast` 就会正确返回转换后的值；
- 如果转型失败且 `new_type` 是指针类型，那么它会返回 `nullptr`；
- 如果转型失败且 `new_type` 是引用类型，那么它会抛出 `std::bad_cast` 异常。

```c++
#include <iostream>

class A {
 public:
  virtual void foo() { std::cout << "A foo()\n"; }
  virtual ~A() = default;
};

class B : public A {
 public:
  virtual void foo() override { std::cout << "B foo()\n"; }
  void bar() { std::cout << "B bar()\n"; }
  virtual ~B() = default;
};

class C : public B {
 public:
  virtual void foo() { std::cout << "C foo()\n"; }
  void bar() { std::cout << "C bar()\n"; }
  virtual ~C() = default;
};

void Foo(A& a) {
  try {
    [[__maybe_unused__]] C &c = dynamic_cast<C&>(a);
    std::cout << "Cast to C SUCCESS!\n";
  } catch(std::bad_cast) {
    std::cout << "Cast to C ERROR!\n";
  }
}

int main() {
  A* pa1 = new C;
  A* pa2 = new B;

  pa1->foo();

  B* pb = dynamic_cast<B*>(pa1);
  std::cout << "Try to cast A* pa1 to B* pb ...\n";
  if (pb) {
    std::cout << "Cast success\n";
    pb->foo();
    pb->bar();
  } else {
    std::cout << "Cast failed\n";
  }

  C* pc = dynamic_cast<C*>(pa2);
  std::cout << "Try to cast A* pa2 to C* pc ...\n";
  if (pc) {
    std::cout << "Cast success\n";
    pc->foo();
    pc->bar();
  } else {
    std::cout << "Cast failed\n";
  }

  C c;
  Foo(c);

  B b;
  Foo(b);
}
// output:
// C foo()

// Try to cast A* pa1 to B* pb ...
// Cast success
// C foo()
// B bar()

// Try to cast A* pa2 to C* pc ...
// cast failed

// Cast to C SUCCESS!

// Cast to C ERROR!
```

整体类层次结构为 `A -> B -> C`。从上述结果中不难发现：

- `A* pa1` 指向 `C` 类对象，调用虚函数 `foo()` 时实现了多态的效果；
- `A* pa1` 指向 `C` 类对象，转换为 `B*` 指针时成功，因为 `C` 是 `B` 的派生类，拥有基类的所有信息；
- `A* pa2` 指向 `B` 类对象，转换为 `C*` 指针时失败，并返回空指针；
- `A& a` 绑定到 `C` 类对象时，能够转换到 `C&` 型；
- `A& a` 绑定到 `B` 类对象时，无法转换到 `B&` 型，并抛出异常；

总结出，`dynamic_cast<new_type>(expr)` 转换成功与否，关键看指针/引用 `expr` 指向/绑定的对象是否为 `new_type` 的相同类型或派生类，而不用关心指针/引用类型本身。

再来看另一种情况。

```c++
class A { virtual f(); };
class B : public A { virtual f(); };
class C : public A {};
class D { virtual f(); };
class E : public B, public C, public D { virtual f(); };

/********
 A  A
 |  |
 B  C  D
 |__|__|
    |
    E
********/
```

如果我们拥有一个 `D* pd = new E;` 的指针，希望将其转换为 `A*`，一种可行的思路是先转到 `E*` 再转到 `B*` 最后转到 `A*`，就像这样进行“crabbing”：

```c++
E* pe = dynamic_cast<E*>(pd);
B* pb = pe;
A* pa = pb;
```

事实上，如果 `new_type` 与 `expr` 所指代的指针/引用类型处于同一层次（比如这里的 `D` 与 `B`），并且 `expr` 所指向/绑定的对象为它俩的共同派生类，则可以进行**横向转换**，比如：

```c++
B* pb = dynamic_cast<B*>(pd);
```

在一些更复杂的类层次结构中，**横向转换**可以极大地提高 coding 效率。

#### reinterpret_cast

```c++
reinterpret_cast<new_type>(expr);
```

`reinterpret_cast` 通过对底层比特位重新解读来进行类型间的转换。当然，这也是不安全的，需要程序员手动检查。

```C++
int main() {
  int a;
  std::cout << &a << '\n'
            << reinterpret_cast<unsigned long long>(&a); // 将 64 位指针类型的 &a 重新解读为 64 位 unsigned long long 类型。
}
// output:
// 0000000169AFFD5C
// 6068108636
```

#### const_cast

```c++
const_cast<new_type>(expr);
```

`const_cast` 最大特点就在于它可以移除 `expr` 的 cv 限定，这是其余几个算子都做不到的。

```c++
class A {
  int val;
 public:
  A(int val_): val(val_) {}
  void show() { std::cout << val << '\n'; }
  void foo(int i) const {
    // val = i;                    // ERROR! A::foo() is const
    const_cast<A*>(this)->val = i; // A::foo() const 中，this 为 const A* 型，使用 const_cast 去限定后允许修改成员变量
  }
};

int main() {
  A a(3);
  a.show();
  a.foo(6);
  a.show();
}
// output: 6
```

`const_cast` 使得到非 `const` / 非 `volatile` 类型的指针/引用能够实际指向/绑定到 `const` / `volatile` 对象。通过非 `const` 访问路径修改 `const` 对象和通过非 `volatile` 泛左值指代 `volatile` 对象是 UB。

```c++
int main() {
  const int a = 1;
  int* pa = const_cast<int*>(&a);
  int& ra = const_cast<int&>(a);
    
  *pa = 2;
  std::cout << "a = " << a << " *pa = " << *pa << " ra = " << ra << '\n';
    
  ra = 3;
  std::cout << "a = " << a << " *pa = " << *pa << " ra = " << ra << '\n';
}
// output:
// a = 1 *pa = 2 ra = 2
// a = 1 *pa = 3 ra = 3
```

### 隐式转换

凡是在语境中使用了某种表达式类型 `T1`，但语境不接受该类型，而接受另一类型 `T2` 的时候，会进行**隐式转换**。

```c++
int a = 1;
long long b = a + 1; // int -> long long
if (a) {             // int -> bool
  char c = a;        // int -> char
}
```

事实上，C++ 的任何的**隐式转换**都是使用 `static_cast` 来实现。所以具体的直接看 `static_cast` 就行了，这里就列几个比较有代表性的例子。

#### 生成了几个 string

```c++
std::string s = "hi";
```

首先，`“hi”` 会被编译器认为是 `const char*` 型字面量。

- 在 C++ 11 之前，会首先调用 `std::string::string(const char *)` 的初始化构造函数，进行隐式转换生成一个临时变量，再调用拷贝构造函数生成 `s`；
- 引入移动语义的 C++ 11 之后，依然会隐式转换生成临时变量，但此时由于该变量为右值，于是调用了移动构造函数将临时变量保有的资源 `“hi”` 移至 `s` 中；
- 而到了 C++ 17，引入了一个叫[**复制消除**](https://zh.cppreference.com/w/cpp/language/copy_elision)的规则，要求在满足一定的条件下避免对象的复制，于是这里的临时变量不会生成，直接调用 `std::string::string(const char *)` 构造对象；

> 在不同编译器标准下，答案分别为 2 2 1



### 显示转换

#### User Defined Cast
