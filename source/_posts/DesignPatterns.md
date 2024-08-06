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

## 单例模式 Singleton

**单例模式**是一种创建型设计模式，保证一个类只有一个实例，并提供一个访问该实例的全局 API，且该实例为全局共享。

所有单例的实现都包含以下两个相同的步骤：

- 将默认构造函数设为私有，防止其他对象使用单例类的 `new` 运算符。
- 新建一个静态构建方法作为构造函数。该函数会 “偷偷” 调用私有构造函数来创建对象，并将其保存在一个静态成员变量中。此后所有对于该函数的调用都将返回这一对象。

### 懒汉式 lazy

用到的时候才创建实例。C++ 11 以前容易产生线程安全的问题，但 C++11 标准之后的最佳的选择是 **`Meyers' Singleton`**，它利用了局部静态变量在第一次使用时才初始化的特性，并且由于 C++11 标准解决了局部静态变量的线程安全问题，使得它成为当前**最优雅**的实现方式。

```cpp
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

### 饿汉式 eager

指单例实例在程序运行时被立即执行初始化，保证线程安全，但在某些程序中，初始化语句与调用语句的先后顺序并不确定，故存在潜在问题。目前最好的办法还是用 Meyers' Singleton。

## 工厂模式

**工厂模式**属于创建型设计模式，它提供了一种创建对象的最佳方式。在工厂模式中，我们在创建对象时不会对外部暴露创建逻辑，而是通过使用一个全局共享的接口来创建新的对象。终极目的是为了**解耦**，实现创建者和调用者的分离。

它利用了面向对象中**多态**的特性，将存在着继承关系的类，通过一个工厂类创建对应的子类（派生类）对象。

### 简单工厂

简单工厂的工厂类里封装了创建具体产品对象的函数。

```cpp
enum class ProductType;
class Factory {
  public:
    Product* CreateProduct(ProductType type) {
      switch(type) {
        case TYPEA:
          return new ProductA();
        case TYPEB:
          return new ProductB();
        ...
        default:
          return nullptr;
      }
    }
};
```

缺陷是扩展性差，一旦需要新增产品，则必须修改 `ProductType` 以及工厂类的创建函数。

### 工厂方法

工厂方法模式将工厂类进行抽象，仅提供创建具体产品的接口，而具体实现交由子类（即具体工厂）去完成。

```cpp
class AbstractFactory {
  public:
    virtual Product* CreateProduct() = 0;
    virtual ~AbstractFactory() = default;
}

class ConcreteFactory1: public AbstractFactory {
  public:
    virtual Product* CreateProductA() { return new ProductA(); }
}

class ConcreteFactory2: public AbstractFactory {
  public:
    virtual Product* CreateProductB() { return new ProductB(); }
}
...
```

和简单工厂一样，每新增一个产品，就需要增加一个对应的产品的具体工厂类。相比简单工厂而言，工厂方法模式需要更多的类定义。

### 抽象工厂

在工厂方法基础上，为抽象类增加多个接口，若子类支持某接口，则进行 override，否则什么也不做。这样就实现了创建多个产品族中的产品对象。代码略。

### 模板工厂

以上三种方式，在新增产品时，要么修改工厂类，要么需新增具体的工厂类，说明工厂类的封装性还不够好。模板工厂是将工厂方法模式封装成模板工厂类，那么这样在新增产品时，是不需要新增具体的工厂类，减少了代码的编写量。

```cpp
// 抽象模板工厂类
// AbstractProduct_t 产品抽象类
template <class AbstractProduct_t>
class AbstractFactory {
  public:
    virtual AbstractProduct_t *CreateProduct() = 0;
    virtual ~AbstractFactory() = default;
};

// 具体模板工厂类
// AbstractProduct_t 产品抽象类，ConcreteProduct_t 产品具体类
template <class AbstractProduct_t, class ConcreteProduct_t>
class ConcreteFactory : public AbstractFactory<AbstractProduct_t> {
  public:
    AbstractProduct_t *CreateProduct() { return new ConcreteProduct_t(); }
};
```

当然，也可以在创建产品时通过某种 primary key 将其注册进 `std::map`/`std::unordered_map` 中，后续可以通过该 key 直接获取之前创建过的产品。