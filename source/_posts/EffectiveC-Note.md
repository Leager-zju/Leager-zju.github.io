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

关于 `const` 具体可见[**本文**](../../C-Basic/C-Const)。

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

在 non-const 版本中将 `*this` 转型为 const，便能调用 const 函数，最后通过 `const_cast` 移除常量性。代码瞬间精简不少！尽管，使用 cast 是一个糟糕的想法，但在这里，很安全。

而另一种做法，即通过 const 函数调用 non-const 函数，则是一种错误行为，为了不冒 const 风险，不建议采取这种做法。

## 4. 确定对象被使用前已先被初始化

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

而使用初始化列表的方式，则只会影响这些成员变量调用构造函数的版本，相当于是拿着指定的实参去调用构造函数，不用担心顺序问题（但最好还是按照成员变量列出顺序来）。此时只需调用一次构造，比起赋值的方法高效许多。对于内置类型，两种方式开销一样，但为了一致性还是通过初始化列表来初始化。

最后需要关心的事就是**定义于不同编译单元内的 non-local static 变量**了，即定义在作用域外的其它文件的静态变量。因为 C++ 对于这类变量的初始化顺序并未明确定义，甚至根本无解。所以我们在使用一个 `extern` 标识的变量时，它极有可能未被初始化！

```c++
// Tool.h
class Tool {
 /* ... */
};

// Human.h
class Human {
 /* ... */
};
extern Tool theTool;

Human Jack(theTool); // 如果 theTool 未被初始化，则该语句的实现效果将是非确定性的。
```

一个**好的设计**是将 static 变量移到成员函数中，该函数返回一个该变量的引用，用户通过调用该函数来获取变量的访问权，而非直接使用——这就是[**单例模式**](https://zh.wikipedia.org/zh-hans/%E5%8D%95%E4%BE%8B%E6%A8%A1%E5%BC%8F)的常用实现手法。

为什么说它好？因为函数内部的 static 变量会在调用函数首次遇到定义式时进行初始化，且仅初始化这一次。所以只要调用该函数，便能保证变量必然被初始化。furthermore，如果不调用函数，则变量永远不会被初始化，构造和析构的开销也降低了。

```c++
// Tool.h
class Tool {};

// Human.h
class Human {
 /* ... */
};

Tool& getTool() {
  static Tool globalTool;
  return globalTool;
}

Human Jack(getTool()); // 保证得到初始化
```

## 5. 了解 C++ 默默编写并调用哪些函数

[**见此处**](../../C-Basic/C-OOP/#装)

> C++11 引入移动语义之后，对于一个**空类**，编译器将为其默认生成以下 6 种特殊成员函数，且访问级别默认为 `public`（见下文）：**默认构造函数**、**析构函数**、**拷贝构造函数**、**拷贝赋值运算符**、**移动构造函数**、**移动赋值运算符**。

## 6. 若不想使用编译器自动生成的函数，就该明确拒绝

通常来说，如果不希望使用某函数，则不声明即可。但上面那点提到，尽管你可能没声明，但一旦尝试调用，编译器就会自动帮你声明。

所以希望完全阻止这种调用行为，可以加上 [`delete` 说明符](../../C-11/C-DefaultAndDelete/#delete)。

> 与 `default` 相对，后面加上 `= delete` 的函数会被视为**弃置**(deleted)，在编译器眼中这个函数**禁止被定义**，对该函数的调用会导致编译错误，继而从根本上解决了这个问题。

## 7. 为多态基类声明 virtual 析构函数

见[**此处**](../../C-Basic/C-OOP/#注意)第 5 条。

> 当可能用到基类指针/引用绑定派生类时，基类的析构函数必须为虚函数。这是因为当出现 `Base* ptr = new Derive` 这样的代码时，虽然 `ptr` 是 `Base` 类的指针，但我们实际上还分配了一个 `Derive` 类的空间，如果析构函数非虚，则只会执行 `Base` 类的析构函数，而属于 `Derive` 的那一部分并没有被析构。为了程序安全运行，我们应该要调用派生类的析构函数，也就是通过将基类析构函数设为虚函数来实现；

## 8. 别让异常逃离析构函数

C++ 虽然并不禁止析构函数吐出异常，但**不建议**。考虑这种情况：

```c++
class Widget {
 public:
  ~Widget() { /* 存在抛出异常的可能 */ }
};

std::vector<Widget> widgets;
```

在 `widgets` 销毁时，会调用每一个 `Widget` 对象的析构函数，一旦某个对象析构时抛出异常，并且没有得到正确处理，整个程序可能因此发生一些 UB。

析构函数必须对此异常进行处理，以防止它逃逸到外层，造成不必要的危害。此时有两种做法：

1. 直接终止
   ```c++
   class Widget {
    public:
     ~Widget() {
       try { /* 调用某些可能抛出异常的函数 */ }
       catch() {
         /* 记录调用失败 */
         std::abort();
       }
     }
   }
   ```
2. 吞下异常
   ```c++
   class Widget {
    public:
     ~Widget() {
       try { /* 调用某些可能抛出异常的函数 */ }
       catch() {
         /* 记录调用失败 */
       }
     }
   }
   ```
两种做法均能阻止异常的逃逸，这是好的。另外，如果客户需要对某个函数运行期间抛出的异常做出响应，那么类应该提供一个普通函数（而不是在析构函数中）执行该响应。

## 9. 绝不在构造和析构过程中调用 virtual 函数

假设有一个 transaction 类体系，用于模拟股市的买卖等操作，每次创建一个交易对象时，都会根据交易类型进行一次适当的记录。比如下面这个看起来挺好的做法：

```c++
class Transaction {
 public:
  virtual void logTxn() const = 0; // 创建一份因类型不同而不同的交易日志
  Transaction() {
    /* ... */
    logTxn();
  }
};

class BuyTransaction: public Transaction {
 public:
  virtual void logTxn() const { /* ... */ }
};

class SellTransaction: public Transaction {
 public:
  virtual void logTxn() const { /* ... */ }
};

BuyTransation buyTxn;
```

创建 `buyTxn` 时，根据[**构造顺序**](../../C-Basic/C-OOP/#派生类构造顺序)，其基类的构造一定会更早被调用，然后才是派生类的专属部分。而其基类的构造函数中出现了一个纯虚函数 `logTxn()`，这是万恶之源！

我们本意是希望通过该虚函数完成派生类版本的构造，但事实上，构造 `BuyTransaction` 对象时，优先构造的是对象中的基类部分，也就是 `Transaction` 部分，此时调用的 `logTxn()` 尽管为虚，但其无法表现出多态性质，相当于将其视为了 non-virtual，执行的还是 `Transaction` 版本的函数，并不会下降到派生类 `BuyTransaction`。毕竟，此时派生类专属部分尚未得到初始化，如果派生类版本的 `logTxn()` 将用到其成员变量，那将成为“**通往彻夜调试的直达车票**”——C++ 不允许你使用对象内部尚未初始化的部分。

还有一个更根本的原因是，在基类部分构造期间，对象类型会被视为基类而非派生类，请看：

```c++
class B {
 public:
  B() { std::cout << typeid(*this).name() << "cons\n"; }
};

class D: public B {
 public:
  D() { std::cout << typeid(*this).name() << "cons\n"; }
};

int main() {
  D d;
}
// output:
// 1Bcons
// 1Dcons
```

所以就算能实现多态，也不会使用派生类的版本——那不就相当于没有多态么(笑

更何况，基类 `logTxn()` 还是 pure virtual，压根无法调用，故本条款也是为了防止这种情况发生。

上面说的所有原因也同样适用于析构函数。

如果非要实现“**根据不同类型使用不同构造函数**”，一个好的做法是，将基类的 `logTxn()` 设为 non-virtual，然后要求为该函数传入必要的信息，如:

```c++
class Transaction {
 public:
  void logTxn(const TransactionInfo& info) const {
    /* ... */
  }
  Transaction() {
    /* ... */
    logTxn();
  }
  static TransactionInfo createInfo( /* params */ ) {
    /* ... */
  }
};

class BuyTransaction: public Transaction {
 public:
  BuyTransaction( /* params */)
    :Transaction(createInfo( /* params */ ))
    { /* ... */ }
};
```

这样就由**令派生类将必要的信息向上传递**代替了**使用虚函数向下调用**。

## 10. 令 operator= 返回一个 reference to *this

关于赋值，可以写为如下形式：

```c++
int a, b, c;
a = b = c = 15;
// 由于赋值遵循右结合律，故被解析为
a = (b = (c = 15));
```

为了实现**连锁赋值**，`operator=` 必须返回一个自身的引用。这同样适用于 `+=`、`-=`、`后++` 等运算符。

## 11. 在 operator= 中处理“自我赋值”

```c++
class Object {
  /* ... */
 private:
  const std::string* name;
};
Object ob;
ob = ob;
```

是的这很蠢，但为了演示，没办法（摊手）。当然这种写法是被允许的，只不过自我赋值增加了无意义的开销——这还算能接受，但如果类的赋值运算符写成这样，那就要当心点了：

```c++
Object& opeartor=(Object& rhs) {
  delete this->name;
  this->name = new std::string(*rhs.name);
  return *this;
}
```

如果 `rhs == *this` 会发生什么？`this->name` 与 `rhs.name` 实际上就是同一个指针，指向同一块内存。那么此时 `name` 首先被 delete，然后再通过 `operator*` 获取 `name` 指向的字符串……接下来懂的都懂了吧~

为了避免这种危害，**传统做法**是在最开始执行**证同测试**，实现**自我赋值安全性**：

```c++
Object& opeartor=(Object& rhs) {
  if (this == &rhs) return *this; // 比较地址比比较对象本身更好

  delete this->name;
  this->name = new std::string(*rhs.name);
  return *this;
}
```

但该做法无法保证**异常安全性**，也就是说，如果 `new` 操作中出现异常（内存不够 or 构造函数异常），最后还是会得到一份**不安全**的反馈——`name` 可能因此被永久 delete，既无法删除，也无法读取。看 solution！

```c++
Object& opeartor=(Object& rhs) {
  const std::string* tmp = this->name;
  this->name = new std::string(*rhs.name);
  delete tmp;
  return *this;
}
```

即便 `new` 或构造函数出现异常，`name` 也不会因此被贸然 delete——该做法保证了先分配再释放。同样的，这也解决了最开始**自我赋值安全性**的问题。

上一方案的替代做法是 **copy and swap**。

```c++
class Object {
  /* ... */
  void swap(Object& rhs) { /* 交换 *this 和 rhs 的数据 */ }
 private:
  const std::string* name;
};
Object& opeartor=(Object& rhs) {
  Object tmp(rhs);
  swap(tmp);
  return *this;
}
```

或者直接这样写：

```c++
class Object {
  /* ... */
  void swap(Object& rhs) { /* 交换 *this 和 rhs 的数据 */ }
 private:
  const std::string* name;
};
Object& opeartor=(Object rhs) {
  swap(rhs);
  return *this;
}
```

> 当然可以在这些方案的最开始加上证同测试，但需要在自我赋值开销与目标代码、CPU 控制流之间做出 trade-off。

## 12. 复制对象时勿忘其每个成分

本来编译器会为你默认生成一个完美的拷贝构造/拷贝赋值，但不一定是你想要的，所以此时你进行了一些自定义。

结果后面类加入了新的成员变量，你就需要时刻警醒自己：别忘了修改自定义的拷贝构造与拷贝赋值。否则就会出现违背[**条款 4**](#4-确定对象被使用前已先被初始化) 的结果。

当然这还好说，但一旦出现继承，另一个噩梦又来了……

```c++
class Customer {
 public:
  /* ... */
 private:
  std::string name;
};

class PriorityCustomer: public Customer {
 public:
  PriorityCustomer(const PriorityCustomer& rhs): priority(rhs.priority) {}

  PriorityCustomer& operator=(const PriorityCustomer& rhs) {
    priority = rhs.priority;
    return *this;
  }
 private:
  int priority;
};
```

上面看起来没啥问题，但实际上，`PriorityCustomer` 类对象进行拷贝时，仅仅对派生类部分的变量进行了拷贝，而忽略了基类部分的 `std::string name`。这是致命的！此时 `name` 会用默认的方式进行构造，那么得到的新 `PriorityCustomer` 对象就变成无名氏了~

> 因为如果让编译器来干，它会毫不犹豫地将基类部分也一并拷贝，怎么到你这就拉垮了？尽管如此，编译器不会给你报错，哎就是玩，毕竟这也不是啥大问题嘛，万一你真的不想拷贝呢~

所以通过拷贝的方式进行构造时，一定不要忘了调用所有基类的适当的拷贝函数，拷贝赋值也是同理的。就像下面这样：

```c++
class PriorityCustomer: public Customer {
 public:
  PriorityCustomer(const PriorityCustomer& rhs)
    :Customer(rhs), 
     priority(rhs.priority) {}

  PriorityCustomer& operator=(const PriorityCustomer& rhs) {
    Customer.operator=(rhs);
    priority = rhs.priority;
    return *this;
  }
 private:
  int priority;
};
```

最后要注意的是，如果拷贝构造与拷贝赋值出现了重复部分，可以将这些重复的部分写入新的函数(eg.`init()`)，然后让它俩一起调用，从而消除冗余。而不是让一个拷贝调用另一个拷贝——[构造跟赋值不能混为一谈](../../C-Basic/C-OOP/#赋值运算符)！