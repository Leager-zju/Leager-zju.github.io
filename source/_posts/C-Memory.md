---
title: C++ の 内存分配(Memory Allocation)
author: Leager
mathjax: true
date: 2023-02-19 14:07:28
summary:
categories:
    - C++ Basic
tags:
    - C++
img:
---

众所周知，C++ 是一门与内存紧密相关的语言，本文就来聊聊 C++ 眼中的内存分配。

<!--more-->

### 内存布局

C++ 程序的内存分为 5 大区域，从**低地址**开始分别为**代码区**、**数据区**、**BSS 区**、**堆区**、**栈区**，每个区域存放不同类型的数据：

- **代码区**：存放可执行程序(.exe)的机器码；

- **数据区**：存放**已初始化**的**全局变量**、**静态变量**与**常量**；

- **BSS 区**：存放**未初始化**的**全局变量**与**静态变量**；

    > 当全局/静态变量未初始化的时候，它们记录在 BSS 区，值默认为 0。考虑到这一点，BSS 区内部无需存储大量的零值，而只需记录字节个数即可。
    >
    > 系统载入可执行程序后，将 BSS 区的数据载入数据，并将内存初始化为 0，再调用程序入口（main函数）。

- **堆区**：程序动态分配（`new`、`malloc`）的数据所在处，从低地址向高地址增长；

- **栈区**：程序局部变量、函数参数值、函数返回值所在处，由编译器自动管理分配，从高地址向低地址增长；

### 内存分配 in C

在 C 中，使用 `alloc` 系函数来进行内存的动态分配。

#### malloc

```c++
void* malloc( std::size_t size );
```

分配一片连续的 `size` 个字节的**未初始化**存储。成功时，返回指向分配的适合对任何标量类型对齐的内存块中，最低（首）字节的指针；反之，返回空指针。

> 使用时需强转为所需类型的指针。

#### calloc

```c++
void* calloc( std::size_t num, std::size_t size );
```

分配 `num` 个大小为 `size` 的对象的数组，并**初始化**所有 bit 为零。成功时，返回指向为任何对象类型适当对齐的，被分配内存块最低（首）字节的指针；反之，返回空指针。

> 相当于初始化 + `malloc(num * size);`

#### realloc

```c++
void* realloc( void* ptr, std::size_t new_size );
```

重分配（扩张或收缩）给定的内存区域 `ptr` 大小至 `new_size`。注意这里的再分配不一定在原区域的基础上，而有可能重新分配一片新空间。成功时，返回指向新分配内存起始的指针；反之，返回空指针，且原指针保留。

> 它必须是 `malloc()`、 `calloc()` 或 `realloc()` 先前分配的，且仍未被 `free()` 释放，否则 UB。

#### free

```c++
void free( void* ptr );
```

与 `alloc` 系搭配使用，用于手动释放动态分配的堆内存空间。

- 若 `ptr` 为空指针，则什么也不做；
- 若 `ptr` 并未指向经 `alloc` 动态分配的空间，则为 UB；
- 对同一个 `ptr` 多次 `free` 的行为为 UB；
- 对已 `free` 的 `ptr` 进行内存访问，为 UB；

注意，`free` 仅仅是释放了指针指向的那片内存，并没有改变指针的指向，但 `free` 之后再次使用指针是不合理的，应当置空。

```c++
int* ptr = (int*)malloc(sizeof(int));
printf("before free: %p\n", ptr);

free(ptr);
printf("after free: %p\n", ptr); // WARNING!

ptr = NULL;                      // nullptr in C++

// output:
// before free: 000001EF641FCFB0
// after free: 000001EF641FCFB0
```

### 内存分配 in C++

而在 C++ 中，由于引入了**类**这一概念，`alloc` / `free` 这种只能分配/释放内存的函数并不足以满足需求——`alloc` 分配内存时并不会调用构造函数，并且如果 `free` 简单地释放了一个类对象的内存，那么其析构函数不会被调用，这搞不好会引发大灾难。于是，它俩被功能更强大的 `new` / `delete` 所取代。

#### new / delete

> 定义于头文件 `<new>`

```c++
::(opt) new (布置参数)(opt) (类型) 初始化器(opt) ;
    
int* p1 = new int (1);  // p1 指向 int 变量，并初始化为 1
int* p2 = new int[2] {114, 514};  // p2 指向数组 int[2]，并初始化为 {114, 514}
int* p3 = new(p1) int (3);        // 定位 new，不需要额外分配内存，而是直接在已分配的内存(p1)处调用构造函数即可
int* p4 = new (std::nothrow) int{4}; // 分配失败时不抛出异常，而是返回 nullptr
std::cout << *p1 << " " << p2[0] << " " << p2[1] << " " << *p3 << " " << *p4;

delete p1;    // 单变量用 delete
delete[] p2;  // 数组用 delete[]
delete p3;
delete p4;

// output: 3 114 514 3 4
```

`new` / `new[]` 主要完成两件事：

1. 底层调用 `operator new()` 动态分配内存；
2. 在分配的动态内存块上调用构造函数以初始化对象。成功时返回首地址，否则抛出 `std::bad_alloc()` 异常（可以通过加 `std::nothrow` 改变）；

`delete` / `delete[]` 也主要完成两件事：

1. 调用析构函数；
2. 底层调用 `operator delete()` 释放内存；

#### 定位 new(placement new)

上面的代码提到了一种叫**定位 new** 的操作，它的意义在于将内存的**分配**和**构造**分离，比如在 buffer pool 的 coding 中，我们可以预先申请一块大的连续内存，然后在该内存中使用定位 new 来进行对象的构建，一方面可以避免频繁调用系统 `new` / `delete` 带来的开销（并且在该场景下避免了内存不连续的情况），另一方面可以手动控制内存的分配和释放。使用此法，则不一定会在**堆**上分配内存，而是在对应地址处直接构造。

#### 重载 operator new()

`new` / `delete` 是关键字，我们无法修改其功能本身，但其底层所使用的运算符 `operator new()` / `operator delete()` 则能为我们根据需要所重载使用。

```c++
class Foo {
 public:
  void* operator new(size_t size) {
    std::cout << "operator new override\n";
    return std::malloc(size);
  }
};

int main() {
  Foo* f = new Foo;
  delete f;
}
// output: operator new override
```

遇到 `new Foo` 时，编译器首先在类和其基类中寻找 `operator new()`，找不到就在全局中找，再找不到就用默认的。我们在类中重载了该操作符，且对操作符的重载默认为 `static`，于是底层会调用 `Foo::operator new() (sizeof(Foo));`

当然，重载形式也可以加入更多参数，但第一个参数必须为 `size_t` 类型，且返回值必须为 `void*` 类型。比如上面说的定位 new，就是在参数列表中加了一个 `void*` 的重载形式。

```c++
class Foo {
 public:
  void* operator new(size_t size, void* ptr) {
    std::cout << "placement new override\n";
    return ptr;
  }
};

int main() {
  Foo* temp = new Foo;
  Foo* f = new (temp) Foo;
  delete temp;
  // delete f;
}
// output: placement new override
```

相当于底层调用了  `Foo::operator new() (sizeof(Foo), temp);`。此时就不用再 `delete f` 了，懂得都懂。

当然也可以加别的形参，比如 `void* operator new(size_t, int);`，使用时直接 `new(100) type;` 即可（圆括号里就是从除了 `size_t` 以外的实参列表）。之前提到的加上 `std::nothrow` 不会抛出异常则是使用了 `void* opertor new(size_t, nothrow_t&)` 的重载形式。

#### 重载 operator delete()

重载 `operator delete()` 时需注意第一个参数必须为 `void*`，且返回值必须为 `void`。但并没有重载的必要，因为我们无法手动调用。但设置这个的意义在于与 `operator new()` 配套使用，只有 `operator new` 抛异常了，才会调用对应的 `operator delete`。若没有对应的 `operator delete`，则无法释放内存。

#### 其他

##### delete this 合法吗？

合法，但必须保证：

1. this 对象是通过 `new` 在堆上分配的；

2. `delete this` 后没有人使用该对象/调用 this 了，使用成员变量/成员函数也不行；

    > 内存都没了还调用个 der

##### 如何定义一个只能在堆/栈上生成对象的类？

- **只能在堆上**：将析构函数设置为**非公有**。C++ 是静态绑定语言，编译器管理栈上对象的生命周期，编译器在为类对象分配栈空间时，会先检查类的析构函数的访问性。若析构函数不可访问，则不能在栈上创建对象。

    ```c++
    // Bad Example →_→
    // can't derive and inconvenient
    class Foo {
     private:
      ~Foo() = default;
     public:
      void Destory() {
        Foo::~Foo(); // or delete this;
      }
    }
    
    // Good Example ^_^
    class Bar {
     protected:
      Bar() = default;
      ~Bar() = default;
     public:
      static Bar* GetBar() {
        return new Bar;
      }
      void Destory() {
        delete this;
      }
    };
    ```

- **只能在栈上**：将 `operator new()` 和 `operator delete()` 设置为**私有**。此时 `new` 的第一步操作（上面讲过）无法执行，进而无法在堆上生成。

##### 为什么说 new 效率低

`new` 的动态分配内存涉及到内核级行为，并且存在上锁的可能，会产生一定开销。进行分配时，如果不是定位 new，则会在任意位置进行分配，不易管理。

### 分配器 Allocator

