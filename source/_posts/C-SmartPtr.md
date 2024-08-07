---
title: C++11 の 智能指针(Smart Pointer)
author: Leager
mathjax: true
date: 2023-02-02 17:19:10
summary:
categories: c++
tags: C++11
img:
---

C++ 不像 Java 那样有虚拟机动态的管理内存，如果使用裸指针，在程序运行过程中可能就会出现内存泄漏等问题，然而这种问题其实都可以通过 C++11 引入的**智能指针**来解决。

<!--more-->

## 裸指针的内存泄漏问题

前面提到使用**裸指针**会存在内存泄漏等问题。这里用具体代码来说明：

```cpp 裸指针的内存泄漏
class A {};
void func() {
  auto p = new A; // 定义 p 为指向 A 对象的裸指针
  if (...) {
    throw exception(SomeExceptionReason);
  }
  delete p;
}
```

如果 `func()` 运行过程中抛出异常或其他原因中途退出，则 `new` 出来的内存得不到释放，随着函数退出，`p` 的生存周期结束，之后这片内存就永远无法被访问，导致**内存泄漏**。

## 智能指针

**智能指针**设计出来就是为了解放程序员，使其无需担心是否释放内存的问题。其本质上是对裸指针进行封装，利用 RAII 思想在构造函数中 `new`，在析构函数中 `delete`，保证了内存不泄露。

根据不同特性，智能指针分为以下三种。

## std::unique_ptr

`unique_ptr` 是一个**独占型**的智能指针，它**不允许**其它 `unique_ptr` 共享其管理的内部指针，故不允许**拷贝构造**与**拷贝赋值**，只能通过**移动语义**来获得资源。

`unique_ptr` 有两个版本：

1. 管理单个对象（例如以 `new` 分配）；

    ```cpp
    template<
        class T,
        class Deleter = std::default_delete<T>
    > class unique_ptr;
    ```

2. 管理动态分配的对象数组（例如以 `new[]` 分配）；

    ```cpp
    template <
        class T,
        class Deleter
    > class unique_ptr<T[], Deleter>;
    ```

其中 `Deleter` 指定删除器类型，即析构函数中调用的对内存进行释放的可调用对象。一旦某个 `unique_ptr` 对象以**移动**方式将资源转移给另一个 `unique_ptr`，或是在生命周期结束后被系统回收时，其关联的删除器会释放内部指针的所有权（即赋值为 `nullptr`）。

> `unique_ptr` 的**删除器**要求必须是能且仅能够传入 `T*` 类型参数的左值可调用对象，而不能是 lambda 表达式：
>
> ```cpp
> template<typename T>
> struct deleter {
>   void operator(T* p) { delete p; }
> };
>
> deleter<int> d;
> std::unique_ptr<int, deleter<int>> ptr(new int, d);
> ```

用法如下：

```cpp unique_ptr
struct A {
  ~A() { std::cout << "~A\n"; }
  void Print() { std::cout << "Print\n"; }
};
const int size = 2;
// 两种版本
auto ptr = std::unique_ptr<A>(new A);
auto ptrs = std::unique_ptr<A[]>(new A[size]);

// 移动语义
auto new_ptr = std::unique_ptr<A>(std::move(ptr)); // 此时 ptr 失去了关联对象指针的所有权
if (ptr) {  // operator bool 检查是否有关联的管理对象
  std::cout << "ptr is empty";
}
std::cout << "\n";

// 成员函数，最常用的就是 get()
auto raw = new_ptr.get(); // get() 返回 A 类型的指针
raw->Print();

// 管理单个对象的 unique_ptr
new_ptr->Print();   // 可以通过 operator-> 解引用，看起来就像一个裸指针一样
(*new_ptr).Print(); // 可以通过 operator* 解引用

// 管理对象数组的 unique_ptr 可以通过 operator[] 以下标访问对象（而非指针）
ptrs[1].Print();

/*
 * output:
 * ptr is empty
 * Print
 * Print
 * Print
 * Print
 * ~A
 * ~A
 * ~A
 */
```

## std::shared_ptr

与 `unique_ptr` 相反，`shared_ptr` 是一个**共享型**的智能指针，它**允许**其它 `shared_ptr` 共享其管理的内部指针，故实现了**拷贝构造**与**拷贝赋值**，并通过这两种方式进行资源共享。

既然允许共享，那就存在多个 `shared_ptr` 使用同一片内存，故不能直接在析构时释放内存。在典型的实现中，`std::shared_ptr` 只保有两个指针：**数据指针** `_M_ptr` 以及**计数器指针** `_M_refcount`。

> 计数器包含：
> 
> - 指向被管理对象的指针或被管理对象本身；
> - 删除器；
> - 分配器；
> - 被管理对象的 shared_ptr 的数量（**引用计数**）；
> - 被管理对象的 weak_ptr 的数量；

每当以拷贝的形式新建了一个 `shared_ptr`，则指向同一片内存的所有 `shared_ptr` 的引用计数都会加一，每次析构的时候引用计数减一，在最后一个 `shared_ptr` 析构的时候（也就是引用计数归零时），对应的内存才会释放。

同为智能指针家族，`shared_ptr` 也实现了以下功能：

1. `get()`：获取内部关联的对象指针。
2. `operator*` / `operator->`：解引用关联的指针；
3. `operator bool`：检查是否有关联的管理对象；

除此之外，其还对外公开了一个 `use_count()` 函数，用于返回引用计数值。

`shared_ptr` 还可以自定义**删除器**，在引用计数为零的时候自动调用删除器来释放对象的内存，这里删除器只需要是传入 `T*` 参数的可调用对象即可：

```cpp
std::shared_ptr<int> ptr(new int, [](int *p){ delete p; });
```

`shared_ptr` 实现上较 `unique_ptr` 更为宽松，但代价为存在一些安全隐患，需要注意的是：

1. 不用同一个裸指针初始化多个 `shared_ptr`，也不要对 `get()` 返回的裸指针进行 `delete`，否则会出现 **double free** 导致出问题；
2. 不将 `this` 指针初始化 `shared_ptr` 并返回，否则会出现 **double free**，比如：

    ```cpp this 的 double free
    class A {
      shared_ptr<A> func() {
        return std::shared_ptr<A>(this);
      }
    };
    ```

    A 本身会调用析构函数，函数返回值由于关联了 `this` 指针，进行 `delete this` 时还会调用一遍析构函数。如果非要实现这一功能，请继承自 `std::enable_shared_from_this<A>`，之后就可以调用 `shared_from_this()` 来获取一个指向自身的 shared ptr 了。

3. 尽量用 `make_shared` 代替 `new`，比如：

    ```cpp
    class A {
      A(int i) { std::cout << i; }
    };
    std::shared_ptr<A> p(new int(1));
    std::shared_ptr<A> q = std::make_shared<A>(1); // 等价于上面那种，but better
    ```

    > `make_shared()` 为我们提供了一个新的创建共享指针的方法，其函数原型为：
    >
    > ```cpp
    > template< class T, class... Args >
    > shared_ptr<T> make_shared( Args&&... args );
    > ```
    >
    > 以 `args` 为 `T` 的构造函数参数列表，构造 `T` 类型对象并将它包装于 `shared_ptr`。
    >
    > 等价于用表达式 `new T(std::forward<Args>(args)...)` 构造，其中 `pv` 是内部指向适合保有 `T` 类型对象的存储的 `void*` 指针。

4. 避免**循环引用**。所谓循环引用，就是存在一个引用通过一系列的引用链，最后引用回自身，且看代码：

    ```cpp 循环引用
    struct A;
    struct B;

    struct A {
      std::shared_ptr<B> other;
    };

    struct B {
      std::shared_ptr<A> other;
    };

    int main() {
      auto aptr = std::make_shared<A>(); // aptr.count = 1
      auto bptr = std::make_shared<B>(); // bptr.count = 1
      aptr->other = bptr;                // 由于 copy，bptr.count++
      bptr->other = aptr;                // 由于 copy，aptr.count++
      return 0;
    }
    ```

    这里 aptr 指向了 A 类对象，随后 aptr.other 又与另一个指向 B 类对象的共享指针 bptr 通过拷贝的方式共享了指针，并且 bptr.other 也通过拷贝的方式与 aptr 共享了指针。这样一来 aptr 的 other 指向的对象 bptr，其 other 又指回了自身，从而存在**循环引用**，并且此时两者的引用计数值均为 2。

    当程序结束时，aptr, bptr 调用析构函数，引用计数值减一，但此时两块内存的引用计数值仍然大于零，永远得不到释放。糟糕透了！

## std::weak_ptr

为了解决共享指针可能存在的**循环引用**问题，`weak_ptr` 被提出。

`weak_ptr` 用来表达**临时所有权**的概念：它不管理指针，也就没有 `get()` 函数，只能通过 `weak_ptr` / `shared_ptr` 进行构造。其拷贝与析构都不会影响引用计数，纯粹是作为一个**旁观者**监视 `shared_ptr` 中管理的资源是否存在，该功能可以通过成员函数 `expire()` 实现——检查被引用的对象是否已删除。

> 当某个对象只有存在时才需要被访问，而且随时可能被他人删除时，可以使用 `weak_ptr` 来监视该对象。

当真正需要通过` weak_ptr` 去调用那片内存时，需创建一个新的**临时** `shared_ptr` 来共享被管理对象的所有权，此时如果原来的 `shared_ptr` 被销毁，则该对象的生命周期将被延长至这个临时的 `shared_ptr` 同样被销毁为止。

具体用法为：

```cpp weak_ptr
int* a = new int{0};
std::shared_ptr<int> shared_p(a);
std::weak_ptr<int> weak_p = shared_p; // weak_ptr 不共享所有权，仅作监视用
std::cout << shared_p.use_count() << " " << weak_p.use_count() << std::endl;

auto q = weak_p.lock(); // lock() 创建新的 std::shared_ptr 对象
std::cout << shared_p.use_count() << " " << weak_p.use_count() << " " << q.use_count();

// output:
// 1 1
// 2 2 2
```

在这样的基础上，`weak_ptr` 也就能够打破 `shared_ptr` 中所存在的循环引用现象——令循环中的其中一个指针为 `weak_ptr` 即可。

```cpp 解决循环引用
struct A;
struct B;

struct A {
  std::shared_ptr<B> other;
};

struct B {
  std::weak_ptr<A> other;
};

int main() {
  auto aptr = std::make_shared<A>(); // aptr.count = 1
  auto bptr = std::make_shared<B>(); // bptr.count = 1
  aptr->other = bptr;
  bptr->other = aptr;
  // 不存在 shared_ptr 之间的拷贝，故引用计数值不会发生变化。
  return 0;
}
```

## 如何手撕一个简单的 shared ptr

首先思考的是：shared ptr 需要支持哪些特性？

1. 类模板，支持所有类型及其构造函数参数；
2. 线程安全的计数器；
3. 拷贝/赋值/移动构造函数；
4. 支持用派生类构造；
5. 正确释放指针；

```cpp 实现 shared_ptr

template <class T>
class SharedPointer {
 public:
  class Counter {
   public:
    Counter(T* ptr) : ptr_(ptr), cnt_(0) {}
    ~Counter() { delete ptr_; }
    void addRef() { cnt_.fetch_add(1); }
    void release() { cnt_.fetch_sub(1); }
    int getCount() { return cnt_.load(); }
    T* ptr_;

   private:
    std::atomic<int> cnt_;
  };

 public:
  SharedPointer(T* ptr) { counter_ = new Counter(ptr); }
  // copy constructor
  SharedPointer(const SharedPointer<T>& sp) {
    counter_ = sp.counter_;
    counter_->addRef();
  }
  SharedPointer& operator=(const SharedPointer<T>& sp) {
    counter_ = sp.counter_;
    counter_->addRef();
  }

  // move constructor
  SharedPointer(SharedPointer<T>&& sp) {
    counter_ = sp.counter_;
    sp.counter_ = nullptr;
  }
  SharedPointer& operator=(SharedPointer<T>&& sp) {
    counter_ = sp.counter_;
    sp.counter_ = nullptr;
  }

  // derived constructor
  template <class U>
  SharedPointer(U* derive) {
    assert(std::is_base_of<T, U>::value);
    counter_ = new Counter(derive);
  }

  ~SharedPointer() {
    counter_->release();
    if (counter_->getCount() == 0) {
      delete counter_;
    }
  }

  T* get() { return counter_->ptr_; }

  bool isNull() { return get() == nullptr; }

 private:
  Counter* counter_;
};
```