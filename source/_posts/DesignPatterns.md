---
title: 设计模式
author: Leager
mathjax: true
date: 2023-11-08 15:37:11
summary:
categories: 编程思想
tags:
img:
---

设计模式是软件设计中常见问题的典型解决方案。每个模式就像一张蓝图，可以通过对其进行定制来解决代码中的特定设计问题。

<!--more-->

## 创建型

### 单例模式

**单例模式**保证一个类只有一个全局共享的实例，并提供一个访问该实例的全局 API。

所有单例的实现都包含以下两个相同的步骤：

- 将默认构造函数设为私有，防止其他对象在某些地方进行单例类的构造；
- 使用静态构建方法创建对象，并将其保存在一个静态成员变量中。此后所有对于该函数的调用都将返回这一对象；

#### 懒汉式(lazy)

用到的时候才创建实例。C++11 以前容易产生线程安全的问题，但 C++11 标准之后的最佳的选择是「**Meyers' Singleton**」，它利用了局部静态变量在第一次使用时才初始化的特性。并且由于 C++11 标准解决了局部静态变量的线程安全问题，使得它成为当前**最优雅**的实现方式。

```cpp Meyers' Singleton
class Singleton {
 public:
  static Singleton& getInstance() {
    static Singleton instance;  // so elegent
    return instance;
  }

 private:
  Singleton() = default;
  ~Singleton() = default;
  Singleton(const Singleton&) = default;
  Singleton& operator=(const Singleton&) = default;
};
```

#### 饿汉式(eager)

指单例实例在程序运行时被立即执行初始化，也能保证线程安全。但如果用不到的话可能会浪费不必要的资源，同时如果一个单例依赖另一个单例，此时这两个单例的构造先后顺序是不确定的，存在隐患。

推荐用 Meyers' Singleton。

```cpp 饿汉式
class Singleton {
 public:
  static Singleton* getInstance() { return instance; }

 private:
  Singleton() = default;
  ~Singleton() = default;
  Singleton(const Singleton&) = default;
  Singleton& operator=(const Singleton&) = default;

  static Singleton* instance;
};

Singleton* Singleton::instance = new Singleton();
```

### 工厂模式

**工厂模式**通过使用一个全局共享的接口来创建新的对象。终极目的是为了**解耦**，实现创建者和调用者的分离。

它利用了面向对象中**多态**的特性，将存在着继承关系的类，通过一个工厂类创建对应的派生类对象。

#### 简单工厂

简单工厂的工厂类里封装了创建具体产品对象的函数。

```cpp 简单工厂
enum class ProductType {
  TYPEA,
  TYPEB
};
class Factory {
 public:
  Product* CreateProduct(ProductType type) {
    switch (type) {
      case ProductType::TYPEA:
        return new ProductA();
      case ProductType::TYPEB:
        return new ProductB();
      ...
      default:
        return nullptr;
    }
  }
};
```

缺陷在于扩展性差：一旦需要新增产品，则必须修改 `ProductType` 以及工厂类的创建函数。

#### 工厂方法

工厂方法将工厂类进行抽象，仅提供创建具体产品的接口，而具体实现交由子类（即具体工厂）去完成。

```cpp 工厂方法
class AbstractFactory {
 public:
  virtual Product* CreateProduct() = 0;
  virtual ~AbstractFactory() = default;
};

class ConcreteFactory1 : public AbstractFactory {
 public:
  virtual Product* CreateProductA() { return new ProductA(); }
};

class ConcreteFactory2 : public AbstractFactory {
 public:
  virtual Product* CreateProductB() { return new ProductB(); }
};
...
```

同样，每新增一个产品，就需要增加一个对应的产品的具体工厂类。相比简单工厂而言，工厂方法模式需要更多的类定义。

#### 抽象工厂

在工厂方法基础上，为抽象类增加多个接口，若子类支持某接口，则进行 override，否则什么也不做。这样就实现了创建多个产品族中的产品对象。代码略。

#### 模板工厂

以上三种方式，在新增产品时，要么修改工厂类，要么需新增具体的工厂类，说明工厂类的封装性还不够好。模板工厂是将工厂方法模式封装成模板工厂类，那么这样在新增产品时，是不需要新增具体的工厂类，减少了代码的编写量。

```cpp 抽象模板工厂 & 具体模板工厂
// 抽象模板工厂类
// AbstractProduct_t 产品抽象类
template <class AbstractProduct_t>
class AbstractFactory {
 public:
  virtual AbstractProduct_t* CreateProduct() = 0;
  virtual ~AbstractFactory() = default;
};

// 具体模板工厂类
// AbstractProduct_t 产品抽象类，ConcreteProduct_t 产品具体类
template <class AbstractProduct_t, class ConcreteProduct_t>
class ConcreteFactory : public AbstractFactory<AbstractProduct_t> {
 public:
  AbstractProduct_t* CreateProduct() { return new ConcreteProduct_t(); }
};
```

当然，也可以在创建产品时通过某种 primary key 将其注册进 `std::map`/`std::unordered_map` 中，后续可以通过该 key 直接获取之前创建过的产品，这就实现了「**反射**」。

## 行为型

### 状态模式 & 策略模式

使用**状态模式**的类需要在内部设置一个「状态变量」，该变量会随函数调用而**被动**切换，类似于自动状态机，并且根据不同状态执行不同的行为。

而使用**策略模式**的类需要在内部设置一个「策略变量」，该变量会被开发者**手动**设置，从而根据不同策略执行不同的行为。

不难发现，这两种模式都涉及将具体的行为封装到不同的类中，以便在运行时选择不同的行为，但区别在于是被动修改还是主动修改。更严格地说，切换这一内部变量的函数是 private 的还是 public 的。

> 通常会搭配**单例模式**实现，因为特定行为应当是全局一致的。

```cpp 状态模式
/**
 * 这段代码可以通过声明与实现分离的形式编写，这里就简单写到一起了。
 */
#include <iostream>

class StateBase;
class Object {
 public:
  Object();
  void request();

 private:
  void setState(const StateBase* newState) { state = newState; }
  const StateBase* state;
};

class StateBase {
 public:
  virtual void handle(Object* obj) const = 0;
  virtual ~StateBase() = default;
};

class StateA : public StateBase {
 public:
  void handle(Object* obj) const override;
  static const StateA& get() {
    static const StateA state;
    return state;
  }
};

class StateB : public StateBase {
 public:
  void handle(Object* obj) const override;
  static const StateB& get() {
    static const StateB state;
    return state;
  }
};

void StateA::handle(Object* obj) const {
  std::cout << "here is stateA" << std::endl;
  obj->setState(&StateB::get()); // 状态转移到 stateB
}

void StateB::handle(Object* obj) const {
  std::cout << "here is stateB" << std::endl;
  obj->setState(&StateA::get()); // 状态转移到 stateA
}

Object::Object() : state(&StateA::get()) {}
void Object::request() { state->handle(this); } // 利用多态，根据不同状态执行不同行为

int main() {
  Object obj;
  obj.request(); // here is stateA
  obj.request(); // here is stateB
  return 0;
}
```

```cpp 策略模式
/**
 * 这段代码可以通过声明与实现分离的形式编写，这里就简单写到一起了。
 */
#include <iostream>

class StrategyBase;
class Object {
 public:
  Object();
  void setStrategy(const StrategyBase* newStrategy) { strategy = newStrategy; }
  void execute();

 private:
  const StrategyBase* strategy;
};

class StrategyBase {
 public:
  virtual void handle(Object* obj) const = 0;
  virtual ~StrategyBase() = default;
};

class StrategyA : public StrategyBase {
 public:
  void handle(Object* obj) const override {
    std::cout << "here is strategyA" << std::endl;
  }
  static const StrategyA& get() {
    static const StrategyA strategy;
    return strategy;
  }
};

class StrategyB : public StrategyBase {
 public:
  void handle(Object* obj) const override {
    std::cout << "here is strategyB" << std::endl;
  }
  static const StrategyB& get() {
    static const StrategyB strategy;
    return strategy;
  }
};

void Object::execute() { strategy->handle(this); }

int main() {
  Object obj;
  obj.setStrategy(&StrategyA::get()); // 主动切换策略到 StrategyA
  obj.execute();                      // here is strategyA

  obj.setStrategy(&StrategyB::get()); // 主动切换策略到 StrategyB
  obj.execute();                      // here is strategyB
  return 0;
}
```