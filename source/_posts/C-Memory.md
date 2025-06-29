---
title: C++ の 内存分配(Memory Allocation)
author: Leager
mathjax:
  - false
date: 2023-02-19 14:07:28
summary:
categories:
  - C++
tags:
img:
---

众所周知，C++ 是一门与内存紧密相关的语言，本文就来聊聊 C++ 眼中的**内存分配**。

<!--more-->

## 内存布局

C++ 程序的内存分为 5 大区域，分别为**代码区**、**常量存储区**、**全局/静态存储区**、**堆区**、**栈区**，每个区域存放不同类型的数据：

- **代码区(.text)**：存放可执行程序(.exe)的机器码；

- **常量存储区(.rodata)**：存放**常量**，不允许修改；

- **全局/静态存储区(.bss/.data)**：**全局变量**与**静态变量**被分配到同一片内存；

    > C 里会根据变量初始化与否细分为 data 和 bss，but C++ not。

- **堆区(heap)**：通过库函数 `malloc()` 动态分配的数据所在处，地址从低向高增长。如果堆区某片内存没有通过 `free()` 释放，则在程序结束后由操作系统自动回收，但如果不及时释放，那么后续很可能无法分配到足够的内存；

    > C++ 里有个概念叫**自由存储区**，专指通过运算符 `new` 分配得到的内存区域。当使用默认 `new` 时，会分配堆区的内存，此时自由存储区=堆区，也可以进行运算符重载，改用其他内存来实现自由存储，例如全局变量做的对象池，这样自由存储区就不一定是堆区了。所以说是**自由**嘛(
    >
    > 总而言之，堆区是操作系统维护的一块内存，而自由存储区是 C++ 中通过 `new` 与 `delete` 动态分配和释放对象的抽象概念，与堆并不等价。

- **栈区(stack)**：程序局部变量、函数参数值、函数返回值所在处，由编译器自动管理分配，地址从高向低增长；

## 内存分配 in C

在 C 中，使用 `alloc()` 系库函数来进行内存的动态分配。

### malloc()

```cpp
void* malloc( std::size_t size );
```

分配一片连续的 `size` 个字节的**未初始化**存储。成功时，返回指向分配的适合对任何标量类型对齐的内存块中，最低（首）字节的指针；反之，返回空指针。

> 使用时需强转为所需类型的指针。

🔔 调用 `malloc` 分配内存时，会有两种方式向操作系统申请

1. 小于某个阈值（如 128KB）时，使用 `brk()` 系统调用在堆上分配内存；
2. 大于某个阈值时，使用 `mmap()` 系统调用在文件映射区上分配内存；

### calloc()

```cpp
void* calloc( std::size_t num, std::size_t size );
```

分配 `num` 个大小为 `size` 的对象的数组，并**初始化**所有 bit 为零。成功时，返回指向为任何对象类型适当对齐的，被分配内存块最低（首）字节的指针；反之，返回空指针。

> 相当于初始化 + `malloc(num * size);`

### realloc()

```cpp
void* realloc( void* ptr, std::size_t new_size );
```

重分配（扩张或收缩）给定的内存区域 `ptr` 大小至 `new_size`。注意这里的再分配不一定在原区域的基础上，而有可能重新分配一片新空间。成功时，返回指向新分配内存起始的指针；反之，返回空指针，且原指针保留。

> 它必须是 `malloc()`、 `calloc()` 或 `realloc()` 先前分配的，且仍未被 `free()` 释放，否则 UB。

### free()

```cpp
void free( void* ptr );
```

与 `alloc` 系搭配使用，用于手动释放动态分配的堆内存空间。

- 若 `ptr` 为空指针，则什么也不做；
- 若 `ptr` 并未指向经 `alloc` 动态分配的空间，则为 UB；
- 对同一个 `ptr` 多次 `free` 的行为为 UB；
- 对已 `free` 的 `ptr` 进行内存访问，为 UB；

注意，`free` 仅仅是释放了指针指向的那片内存，并没有改变指针的指向，但 `free` 之后再次使用指针是 UB，应当置空。

```cpp
int* ptr = (int*)malloc(sizeof(int));
printf("before free: %p\n", ptr);

free(ptr);
printf("after free: %p\n", ptr); // WARNING!

ptr = NULL;                      // nullptr in C++

// output:
// before free: 000001EF641FCFB0
// after free: 000001EF641FCFB0
```

## 内存分配 in C++

而在 C++ 中，由于引入了**类**这一概念，`alloc` / `free` 这种只能分配/释放内存的函数并不足以满足需求——`alloc` 分配内存时并不会调用构造函数，并且如果 `free` 简单地释放了一个类对象的内存，那么其析构函数不会被调用，这搞不好会引发大灾难。于是，它俩被功能更强大的 `new` / `delete` 所取代。

### new / delete

> 定义于头文件 `<new>`

```cpp use of new/delete
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

1. 底层 `operator new()` 调用 `malloc()` 动态分配内存；
2. 在分配的动态内存块上调用构造函数以初始化对象。成功时返回首地址，否则抛出 `std::bad_alloc()` 异常（可以通过加 `std::nothrow` 改变）；

`delete` / `delete[]` 也主要完成两件事：

1. 调用析构函数；
2. 底层 `operator delete()` 释放内存；

### 定位 new(placement new)

上面的代码提到了一种叫**定位 new** 的操作，它的意义在于将内存的**分配和构造分离**。

> 如果内存分配与构造不分离，则存在以下弊端：
>
> 1. 可能会构造出我们用不到的对象；
> 2. 初始化与后续使用时各进行一次赋值，产生不必要的开销；
>
> > ```cpp
> > auto ptr = new Foo[10]; // 默认初始化赋值一次
> > for (int i = 0; i < 10; i++) {
> >   Foo[i] = {...};       // 后续又进行了一次赋值
> > }
> > ```
>
> 3. 没有默认初始化函数的类甚至执行不了 `new[]` 操作；

而借助定位 new 来进行对象的构建，上述弊端则迎刃而解：一方面可以避免频繁调用系统 `new` / `delete` 带来的开销，另一方面可以手动控制内存的分配和释放以及类的构造，更加自由。

> 使用此法，则不一定会在**堆**上分配内存，而是在对应地址处直接构造。

### 重载 operator new()

`new` / `delete` 是关键字，我们无法修改其功能本身，但其底层所使用的运算符 `operator new()` / `operator delete()` 则能为我们根据需要所重载使用。

```cpp
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

```cpp
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

### 重载 operator delete()

重载 `operator delete()` 时需注意第一个参数必须为 `void*`，且返回值必须为 `void`。但并没有重载的必要，因为我们无法手动调用。但设置这个的意义在于与 `operator new()` 配套使用，只有 `operator new` 抛异常了，才会调用对应的 `operator delete`。若没有对应的 `operator delete`，则无法释放内存。

### 其他

#### delete this 合法吗？

合法，但必须保证：

1. this 对象是通过 `new` 在堆上分配的；
2. `delete this` 后没有人使用该对象/调用 this 了，使用成员变量/成员函数也不行；

    > 内存都没了还调用个 der

#### 如何定义一个只能在堆/栈上生成对象的类？

- **只能在堆上**：将析构函数设置为**非公有**。C++ 是静态绑定语言，编译器管理栈上对象的生命周期，编译器在为类对象分配栈空间时，会先检查类的析构函数的访问性。若析构函数不可访问，则不能在栈上创建对象。

    ```cpp 定义一个只能在堆上生成的类
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

#### 为什么说 new 效率低

`new` 的动态分配内存涉及到内核级行为，并且存在上锁的可能，会产生一定开销。进行分配时，如果不是定位 new，则会在任意位置进行分配，不易管理。

## 分配器 Allocator

> 定义于头文件 `<memory>`

C++ 的所有容器都是类模板，以 `std::vector` 为例，其在定义中包含了两个模板参数。
```cpp
template<
  class T,
  class Allocator = std::allocator<T>
>
```
第一个参数就是容器包含的元素类型，第二个参数就是下面要讲的**分配器类**，默认为 C++ 自带的 `std::allocator`。

所谓**分配器**，就是负责封装堆内存管理的对象，它们在整个标准库中使用，特别是 STL 容器使用它们来管理容器内部的所有内存分配。其最大的特点与意义在于，将内存分配与构造分离（正如定位 new 那样），这样就可以先分配大块内存，而只在真正需要时才执行对象创建操作。

`std::allocator` 的成员函数如下：

> C++20 对分配器的成员函数进行了一些改动

- `constexpr T* allocate(size_t n)`：分配足够的存储空间来存储 n 个实例，并返回指向它的指针；
- `constexpr void deallocate(T* p, size_t n)`：释放分配的内存。p 必须是调用 `allocate()` 获得的指针，n 必须等于调用 `allocate()` 时传入的参数；
- `void construct(T* p, Args ... args)`：使用参数 args 在 p 处构造一个对象。**C++20 中移除**；
- `void destroy(T* p)`：调用 p 处对象的析构函数。**C++20 中移除**；

> 如果希望自定义分配器，可以直接继承自 `std::allocator`，然后重写分配/解分配策略。

## 未初始化内存算法

> 定义于头文件 `<memory>`

- `constexpr void destroy_at(T*)`：销毁在给定地址的对象；
- `constexpr void destroy(ForwardIt, ForwardIt)`：销毁一个范围中的对象；
- `constexpr ForwardIt destroy_n( ForwardIt first, Size n )`：销毁范围中一定数量的对象；
- `constexpr T* construct_at( T* p, Args&&... args )`：在给定地址创建对象；

## 智能指针

智能指针是针对裸指针进行封装的类，它能够更安全、更方便地使用动态内存。具体见 [C++11 の 智能指针](../../c/c-smartptr)。

## 内存泄漏及其常用工具

如果使用了 `malloc()/new` 分配内存却未调用 `free()/delete` 释放，那么指向该内存区域的指针（通常分配在栈上）将会因为生命周期结束而被释放，从而永远无法访问那片内存。在操作系统视角下，程序员没释放，那就是有可能使用，这块内存将被一直保留。一旦这种情况越来越多，那么后续再进行内存分配时，将会没有内存可用，这就是**内存泄漏**。

### Valgrind

Valgrind 可以用来检测程序是否有非法使用内存的问题，例如访问未初始化的内存、访问数组时越界、忘记释放动态内存等问题。

构建项目时加上编译选项 `-g`，之后调用 `valgrind --tool=memcheck --leak-check=full  {可执行文件}` 即可进行内存问题检测。

### Address Sanitizer

AddressSanitizer 是 Google 开发的一款用于检测内存访问错误的工具。它内置在 GCC 版本 >= 4.8 中，适用于 C 和 C++ 代码。它能够检测：

- **Heap buffer overflow**：堆越界访问；
- **Stack buffer overflow**：栈越界访问；
- **Global buffer overflow**：全局缓冲区越界访问；
- **Use after free**：访问指向*已释放内存*的野指针；
- **Use after return**：访问指向*生命周期结束的局部变量*的野指针；
- **Use after scope**：同上；
- **Initialization order bugs**；
- **Memory leaks**：内存泄漏，即分配但不释放；

AddressSanitizer 可在使用运行时检测跟踪内存分配，这意味着必须使用 AddressSanitizer 构建代码才能利用它的功能。

构建项目时，用 `-fsanitize=address` 选项编译和链接（同时记得加上编译选项 `-g`）。此时可执行文件就进入 ASan 模式。在程序运行时首次检测到问题时，会打印错误信息并退出。

```cpp main.c
int main() {
  int *ptr = new int(1);
  return 0;
}
```

```bash
$ gcc -fsanitize=address -g main.c -o main
$ ./main
## 输出错误信息
```

和 Valgrind 相比，AddressSanitizer **性能更高**。