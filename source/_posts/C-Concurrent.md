---
title: C++11 の 并发支持(Concurrency)
author: Leager
mathjax: true
date: 2023-01-29 22:44:35
summary:
categories: C++
tags: C++11
img:
---

C++11 新增了官方**并发支持库**，使得我们能够更好地在系统间移植程序，之前的 Boost 库等也就随之成为历史了。

<!--more-->

## 并发与并行

多线程的世界中，常常会涉及这俩重要概念。

从定义的角度来说，在操作系统中，**并发**是指一个时间段中有几个程序都处于已启动运行到运行完毕之间，且这几个程序都是在同一个处理机上运行，但任一个时刻点上只有一个程序在处理机上运行；而**并行**指的是一组程序按独立异步的速度执行，无论从微观还是宏观，程序都是一起执行的。 （抄自百科）

用自己的语言描述：

- 只会先把饭吃完，再把菜吃完，这叫**单线程**行为；
- 先扒拉几口饭，再夹点菜，再吃饭，以这一时间段为单位，两个行为看似一起进行，但任意时刻却又不同时发生，存在资源（嘴巴）的调度，这叫**并发**；
- 嘴巴里既嚼饭又嚼菜的，即同时吃饭吃菜，有能力同时处理多件事，这叫**并行**；

综上所述，**并发**与**并行**的最主要区别，就在于各个线程是否能够"同时"进行。

## 并发支持库

并发支持库与 boost 很像，主要包含以下 5 个头文件。

### < thread >

> 此头文件中定义了 `std::thread` 以及访问当前执行线程的函数 `std::this_thread`

#### std::thread

该类管理**单个[执行线程](https://en.wikipedia.org/wiki/Thread_(computing))**，并对外提供 api。

首先讲下**初始化方式**。由于每个线程都是一个独立的执行单位，故不存在两个同样的执行线程，那么**拷贝构造**与**拷贝赋值**因此被**弃置**(`delete`)。除此之外，其初始化方式共有四种重载形式：

|                                      重载形式                                       |                                                      说明                                                       |
| :---------------------------------------------------------------------------------: | :-------------------------------------------------------------------------------------------------------------: |
|                                 `thread() noexcept`                                 |                           **默认构造函数**。构造**不**关联执行线程的新 thread 对象。                            |
|                         `thread( thread&& other ) noexcept`                         |         **移动构造函数**。将 `other` 所关联的执行线程的资源转移，此后 `other` **不**关联任何执行线程。          |
|                   `thread& operator=( thread&& other ) noexcept`                    | **移动赋值运算符**。若当前对象此时拥有关联的运行中线程（即 `joinable() == true` ），则调用 `std::terminate()`。 |
| `template< class Func, class... Args > explicit thread( Func&& f, Args&&... args )` |       **初始化构造函数**。thread 创建并关联一个新的执行线程，开始执行可调用对象 `f`，相应参数也一并给出。       |

接下来是其**成员函数**：

1. `get_id()`：任何关联执行线程的 thread 对象均有一个唯一标识线程的对象 `id`。若当前对象存在关联的执行线程，则返回其 `id`；反之，输出 "**thread::id of a non-executing thread**"；
2. `join()`：阻塞当前线程直至 thread 对象关联的线程运行完毕。当前线程的 `id` 不能与 thread 的 `id` 相同，否则出现死锁（自己等自己）。并且，thread 自身不进行同步。同时从多个线程在同一 thread 对象上调用 `join()` 构成数据竞争，导致 **UB**；
3. `joinable()`：判断当前 thread 是否可以 join，即是否关联**活跃**的执行线程。简单来说，就是**是否正在执行**。结束执行但未 join 的 thread 也视为 **joinable**。由默认构造函数生成的 thread 对象 `joinable() == false`；
4. `detach()`：从 thread 对象分离执行线程，允许其独立执行。线程结束后，才释放资源。分离后，thread 也就不再关联任何执行对象了，既无法 `get_id()`，也无法 `join()`；

    > 考虑这样一种情况：
    >
    > 若 thread 关联的线程执行周期比 thread 对象生命周期还长，则当 thread 周期结束后调用析构函数删除资源时，如果没有调用 `join()` 或 `detach()`，此时线程仍在运行，则会出大问题。
    >
    > 所以要么用 `join()` 来阻塞当前线程防止过早结束，要么用 `detach()` 进行线程与 thread 对象的分离。
    >
    > 当然，也可以进一步封装 thread，在析构函数中调用 `join()` / `detach()` 操作，就不会出现上述情况了。

5. `native_handler()`：返回实现线程句柄，实现实时调度。

6. `[static] hardware_concurrency()`：静态方法，返回实现支持的并发线程数。

下面用具体代码进行演示。

```c++
#include <bits/stdc++.h>
using namespace std;

void foo(int n) {
  cout << "Thread " << n << " executing\n";
  this_thread::sleep_for(chrono::seconds(1));
}

int main() {
  thread t1;
  thread t2(foo, 2);
  thread t3(foo, 3);
  thread t4(std::move(t3));

  cout << boolalpha
       << "t1 id: " << t1.get_id() << ", joinable: " << t1.joinable() << "\n"
       << "t2 id: " << t2.get_id() << ", joinable: " << t2.joinable() << "\n"
       << "t3 id: " << t3.get_id() << ", joinable: " << t3.joinable() << "\n"
       << "t4 id: " << t4.get_id() << ", joinable: " << t4.joinable() << "\n";

  t2.join();
  t4.join();
}
/*
 * output:
 * Thread 3 executing
 * Thread 2 executing
 * t1 id: thread::id of a non-executing thread, joinable: false
 * t2 id: 2, joinable: true
 * t3 id: thread::id of a non-executing thread, joinable: false
 * t4 id: 3, joinable: true
 */

```

#### std::this_thread

这实际上是 `std` 下的一个命名空间，用来表示当前线程。

该命名空间下有以下常用成员函数：

1. `get_id()`：获取当前线程 `id`；
2. `yield()`：让出 CPU 资源；
3. `sleep_for()`：当前线程主动睡眠指定时间后醒来。**函数原型**为

    ```c++
    template< typename Rep, typename Period >
    inline void sleep_for(const std::chrono::duration<Rep, Period>& time)
    ```

4. `sleep_until()`：当前线程主动睡眠，直至指定时刻。**函数原型**为

    ```c++
    template< typename Clock, typename Duration >
    inline void sleep_until(const std::chrono::time_point<Clock, Duration>& time)
    ```

### < mutex >

> 此头文件中定义了各种互斥锁如 `std::mutex`，`std::lock_guard`，`std::unique_lock` 等

#### std::mutex

mutex，全称 **mutual exclusion**(互斥体)，用于保护共享数据的**互斥**访问，也就是常说的**锁**。mutex 相当于一种独占性的资源，仅有 `lock` / `try_lock`（获取该资源）与 `unlock`（释放该资源）两种操作，其余各种锁都是围绕 mutex 进行封装与变形，故这些锁的**拷贝构造函数**与**拷贝赋值运算符**被**弃置**。其**主要特性**如下：

- **调用方**线程从它成功调用 `lock` / `try_lock` 开始，到它调用 unlock 为止占有 mutex；
- 任一其它线程占有 mutex 时，当前线程若试图通过 `lock` / `try_lock` 要求获得 mutex 的所有权，则阻塞，直至**占有方**通过 `unlock` 释放 mutex；
- 调用方线程在 `lock` / `try_lock` 前必须不占有 mutex，否则为 **UB**；

就**初始化方式**而言，直接通过**默认构造函数**进行创建互斥锁对象，创建后锁处于**未锁定**状态。

mutex 类是所有锁的基础，其**成员函数**只有三个，都是基于之前讨论的特性：

1. `lock()`：尝试锁定 mutex；
2. `try_lock()`：尝试锁定 mutex，成功获得锁时返回 `true` ，否则返回 `false`；
3. `unlock()`：释放 mutex；

#### std::timed_mutex

在 mutex 基础上，timedMutex 添加了**超时语义**，相关成员函数为：

1. `try_lock_for( time )`：尝试获取锁，若一段时间 time 后超时未获得锁则放弃；
2. `try_lock_until( time )`：尝试获取锁，若指定时刻 time 后超时未获得锁则放弃；

以上两个函数都会在成功时返回 `true`，失败时返回 `false`。

#### std::recursively_mutex

以上两种锁都无法重复获取，即已占有 mutex 的线程继续 `lock` / `try_lock` 会发生 UB。在 mutex 基础上，recursivelyMutex 添加了**递归语义**，即允许线程多次上锁，并在释放相等次数的锁后结束（好比左右括号匹配）。其成员函数与 mutex 一致。

#### std::recursively_timed_mutex

**省流**：recursivelyMutex + timedMutex

#### std::lock() & std::try_lock()

除了各个锁类以外，<mutex\> 头文件下还定义了两个全局函数 `std::lock()` 与 `std::try_lock()`，提供了通用的**一次性加多个锁**的方法。**函数原型**如下：

```c++
template< class Lockable1, class Lockable2, class... LockableN >
void lock( Lockable1& lock1, Lockable2& lock2, LockableN&... lockn );

template< class Lockable1, class Lockable2, class... LockableN >
int try_lock( Lockable1& lock1, Lockable2& lock2, LockableN&... lockn );
```

`std::lock()` 为阻塞式加锁，`std::try_lock()` 为异步式加锁，它俩其实是去调用每种 lockable 对象，即 mutex 自身的方法，然后加锁，并且不会因为不同线程上锁顺序不同而死锁，这是因为一旦上锁失败，则不再推进，而对所有已上锁的 mutex 调用 `unlock()`，然后再次重复尝试，直至所有 mutex 都已上锁。

#### std::lock_guard

对于不加超时语义的 mutex 而言，需要程序员主动上锁解锁，但如果某线程在 unlock 之前就因为抛出异常而被迫终止，那么其持有的 mutex 就永远无法释放，所有等待该资源的线程也就陷入了无尽的阻塞中，这显然是不可用的。并且这样的手动释放要求我们在所有执行体的出口都要解锁，也增加了不必要的代码量。

`lock_guard` 应用了 [RAII 技术](https://zhuanlan.zhihu.com/p/34660259)，其将 mutex 进一步封装，并在构造/析构函数中进行资源的分配/释放，这样就不会出现上述问题——因为一旦线程退出，其所有资源都会被释放，那么必然会调用析构函数，进行解锁，防止线程由于编码失误导致一直持有锁。

> 这样一来，就不能用同一个 mutex 对象来初始化两个不同的 lock_guard 对象了，否则会出现**死锁**，下面几个锁也是如此。

其类定义如下：

```c++
template<typename Mutex>
class lock_guard {
 public:
  using mutex_type = Mutex;
    
  explicit lock_guard(mutex_type& m): m_(m) { m_.lock(); }

  lock_guard(mutex_type& m, adopt_lock_t) noexcept: m_(m) {} // 线程拥有锁时调用此构造函数

  ~lock_guard() { m_.unlock(); }

  lock_guard(const lock_guard&) = delete;
  lock_guard& operator=(const lock_guard&) = delete;

 private:
  mutex_type&  m_;
};
```

两种构造函数区别在于：第一种在构造时上锁；而第二种重载形式形参中的 `adopt_lock_t` 为空结构体类型，表示**构造模式**，即**假设调用方线程已拥有 mutex 的所有权**，以此种方式进行构造时不会上锁。`std` 命名空间下已为我们实现了名为 `adopt_lock` 的全局变量，故可以用以下方式进行初始化：

```c++
std::mutex a;
std::lock_guard b(a);             // 构造后 a 上锁

a.lock();                         // 这句没有就报错
std::lock_guard c(a, adopt_lock); // 告知 a 已上锁，此时用这种初始化方式
```

下面还会讲另外两种上锁模式，也是同理的。

#### std::unique_lock

顾名思义，unique_lock 是独占性的，故不存在两个 unique_lock 对应同一个 mutex 对象，故**移动构造函数**与**移动赋值运算符**得到了实现，方便转移资源。

类定义如下：

```c++
template <typename Mutex>
class unique_lock {
 public:
  using mutex_type = Mutex;

  unique_lock() noexcept: m_(nullptr), own_(false) {}

  explicit unique_lock(mutex_type &m_): m_(std::__addressof(m_)), own_(false) {
    lock();
    own_ = true;
  }

  // 支持三种上锁模式
  unique_lock(mutex_type &m_, defer_lock_t) noexcept: m_(std::__addressof(m_)), own_(false) {}
  unique_lock(mutex_type &m_, try_to_lock_t): m_(std::__addressof(m_)), own_(m_->try_lock()) {}
  unique_lock(mutex_type &m_, adopt_lock_t) noexcept: m_(std::__addressof(m_)), own_(true) {}

  // 超时语义
  template <typename Clock, typename Duration>
  unique_lock(mutex_type &m_, const chrono::time_point<Clock, Duration> &time): m_(std::__addressof(m_)), own_(m_->try_lock_until(time)) {}

  template <typename Rep, typename Period>
  unique_lock(mutex_type &m_, const chrono::duration<Rep, Period> &time): m_(std::__addressof(m_)), own_(m_->try_lock_for(time)) {}

  ~unique_lock() {
    if (own_)
      unlock();
  }

  // 拷贝被弃置
  unique_lock(const unique_lock &) = delete;
  unique_lock &operator=(const unique_lock &) = delete;

  // 移动被实现
  unique_lock(unique_lock &&u) noexcept: m_(u.m_), own_(u.own_) {
    u.m_ = nullptr;
    u.own_ = false;
  }
  unique_lock &operator=(unique_lock &&u) noexcept {
    if (own_)
      unlock();
    unique_lock(std::move(u)).swap(*this);
    u.m_ = nullptr;
    u.own_ = false;
    return *this;
  }

 private:
  mutex_type *m_;
  bool own_;
};
```

unique_lock 在 lock_guard 基础上添加了超时语义，并且支持另外两种**上锁模式**：

1. `defer_lock_t`：不上锁；
2. `try_lock_t`：尝试上锁，而不阻塞；

除此以外，`unique_lock` 还提供了 `lock()`，`unlock()`，`try_lock()`，`try_lock_for()`，`try_lock_until()` 这几个 api，并能通过调用 `release()` 解绑所拥有的锁对象。

为了支持上述功能，类中新添加了变量 `own_` 来判断当前是否持有锁，并且 mutex 对象改为了指针类型，以便判断当前是否存在绑定的 mutex。

> lock_gurad 相比于 unique_lock 更轻量，但因为 unique_lock 类可以手动解锁，所以**条件变量**都搭配 unique_lock 一起使用，因为条件变量在 wait 时需要有手动解锁的能力。

#### std::call_once()

此函数保证某一函数在多线程环境中只调用一次，它需要配合 `std::once_flag` 使用。**函数原型**为：

```c++
template< class Callable, class... Args >
void call_once( std::once_flag& flag, Callable&& f, Args&&... args );
```

若 `flag == true`，则直接返回；反之，利用 `std::forward` 调用 `f`，且仅当正常返回时将 `flag` 由 `false` 改为 `true`。具体代码如下：

```c++
#include <bits/stdc++.h>
using namespace std;

once_flag flag;

void func(int i) {
  call_once(flag, [i]() {
    cout << i << " call\n";
  });
}

int main() {
  thread threads[5];
  for (int i = 0; i < 5; ++i) {
    threads[i] = thread(func, i);
  }
  for (auto& t : threads) {
    t.join();
  }
  return 0;
}

// output: 0 call
```

### < atomic >

> 此头文件中定义了原子变量 `std::atomic<T>`，以及其各种特化 `std::atomic_int`，`std::atomic_bool` 等

#### std::atomic

考虑这样一个情况：存在一整型变量 `x = 0`，现在有两个线程 A, B 分别对其执行加 1 与 减 1 的操作，这些操作可以归结为两步原子操作：

1. 读取变量值；
2. 加/减该值，赋值给原变量；

如果不加以限制，可能会出现 **Write-After-Read**, **Write-After-Write** 的情况，+则 x 最终的结果可能是 -1, 0, 1 这三种，这取决于线程每一步原子操作之间的执行顺序。

我们希望最终结果是**确定性**的，就需要严格控制线程同步，一个很好的考虑是使用前面提到的 mutex，代码可以写为：

```c++
int x = 0;
std::mutex m;
void add() {
  std::lock_guard(m);
  x++;
}
void sub() {
  std::lock_guard(m);
  x--;
}
```

而如果使用**原子变量**，则代码可以简化为：

```c++
std::atomic<int> x(0);  // or std::atomic_int x(0)
void add() { x++; }
void sub() { x--; }
```

事实上，原子变量能帮助我们自动控制线程之间的同步，保证加/减等操作的原子性——若一个线程写入原子对象，同时另一线程从它读取，则行为良好定义。

### < condition_variable >

#### std::condition_variable

`condition_variable` 是利用线程间共享的**全局变量**进行**同步**的一种机制，能用于阻塞一个或多个线程（或称使其等待(**wait**)），直至另一线程通知(**notify**)条件变量将等待的线程唤醒。相当于操作系统里的 **P/V** 操作。

> 下面就用 P/V 代称 wait/notify。

即使共享变量是原子的，也必须互斥地修改它，故尝试进行 P/V 的线程必须在持有锁时进行 P/V，这里的锁必须采用 `unique_lock`，因为需要 RAII 以及手动 lock/unlock。具体用法大致如下：

```c++
std::condition_variable cond;

{
  std::mutex m;
  std::unique_lock<mutex> lock(m);
  /*
   * predicate 为布尔类型表达式
   * 若 predicate == true，则 do something
   * 反之，进入休眠状态，直至被唤醒后检查到 predicate == true
   */
  while (!predicate) {
    cond.wait(lock);  // 必须在持有锁的情况下调用 wait，会被其它线程通过 notify 唤醒
  }
  
  // do something

  cond.notify();
}
```

与互斥方式相比，条件变量的 P 操作以**非竞争方式**争夺资源，会进入一个等待队列，这样一来 CPU 的时间片就得到了充分利用，而不是耗费在无意义的等待上锁上。

接下来谈谈其**成员函数**。

首先是 **wait** 系列：

```c++
// 1. wait
// 原子地进行 unlock ，阻塞当前线程，并将它添加到等待队列。唤醒后，进行 lock 且 wait 退出。
void wait( std::unique_lock<std::mutex>& lock ); 
// 等价于 while(!pred()) { wait(lock); }，这里 pred 是一个返回 bool 值的可调用对象
template< class Predicate >
void wait( std::unique_lock<std::mutex>& lock, Predicate pred ); 


// 2. wait_until
// 等待至时刻 timeout_time 后若还未被唤醒，则强制唤醒
template< class Clock, class Duration >
std::cv_status wait_until( std::unique_lock<std::mutex>& lock,
                           const std::chrono::time_point<Clock, Duration>& timeout_time );
// 等价于:
// while (!pred()) {
//   if (wait_until(lock, timeout_time) == std::cv_status::timeout) {
//     return pred();
//   }
// }
return true;
template< class Clock, class Duration, class Pred >
bool wait_until( std::unique_lock<std::mutex>& lock,
                 const std::chrono::time_point<Clock, Duration>& timeout_time,
                 Pred pred );


// 3. wait_for
// 等待 rel_time 后若还未被唤醒，则强制唤醒
template< class Rep, class Period >
std::cv_status wait_for( std::unique_lock<std::mutex>& lock,
                         const std::chrono::duration<Rep, Period>& rel_time);

// 等价于
// return wait_until(lock,
//                   std::chrono::steady_clock::now() + rel_time,
//                   std::move(pred));
template< class Rep, class Period, class Predicate >
bool wait_for( std::unique_lock<std::mutex>& lock,
               const std::chrono::duration<Rep, Period>& rel_time,
               Predicate pred);
```

> 其中 `cv_status` 是一个枚举型变量，描述定时等待是否因时限返回。其只包含两个枚举值：
>
> 1. `no_timeout`：表示条件变量因 `notify_all` 、 `notify_one` 或虚假地被唤醒；
> 2. `timeout`：表示条件变量因时限耗尽被唤醒；

接下来是 **notify** 系列：

```c++
// 唤醒等待队列中的某一线程，一般只有两个线程的时候才会用 notify_one，因为非此即彼。
void notify_one() noexcept;

// 唤醒等待队列中的所有线程
void notify_all() noexcept;
```

#### std::condition_variable_any

与 `condition_variable` 相比，`condition_variable_any` 是 `condition_variable` 的泛化，其支持任一 Lockable 的锁，不一定非要用 `unique_lock`。除此以外与 `condition_variable` 几乎完全一致，就不聊了。

#### std::notify_all_at_thread_exit()

在此线程完全结束时调用 `notify_all()`。函数原型为：

```c++
void notify_all_at_thread_exit( std::condition_variable& cond,
                                std::unique_lock<std::mutex> lk );
```

需要注意的是，调用该函数之前，必须首先用与 cond 绑定的相同 mutex 来创建 unique_lock 对象，并且传参时需要用 `move()` 将先前获得的锁 `lk` 的所有权转移到内部存储。

#### 唤醒丢失

上面讲条件变量用法时，我提到"**尝试进行 P/V 的线程必须在持有锁时进行 P/V**"，那么如果不上锁就 wait/notify 会怎样呢？不加锁便进行wait 操作的行为我们已经说过是 UB，而不加锁便进行 notify 的行为会导致**唤醒丢失**，且看：

```c++
// case1 唤醒丢失
std::mutex m;
std::condition_variable cond;
bool flag = false;

std::thread thread1([]{
  std::unique_lock<std::mutex> lock(m);
  while (!flag) {
    cond.wait(lock);
  }
  std::cout << "thread1 over\n";
});

std::thread thread2([]{
  flag = true;
  cond.notify_all();
  std::cout << "thread2 over\n";
});

thread1.join();
thread2.join();
```

我们希望的是：thread1 首先上锁，然后 wait（此时会隐式地解锁），然后 thread2 上锁，修改 flag，唤醒 thread1，然后两个线程分别打印一条消息出来。

但线程是异步推进的，极有可能由于 thread2 未进行 `m` 的上锁操作，故其执行体不会被阻塞，从而出现 thread1 上锁，thread2 notify，thread1 再 wait 的执行顺序，显然会导致 thread1 无限阻塞。这便是**不加锁导致唤醒丢失**的经典案例。

为了解决这一问题，我们需要在 notify 前上锁，这样保证了在 thread1 的上锁与 wait 之间不会发生 notify 行为——thread2 会因竞争锁资源而被阻塞。

```c++
// OK
std::mutex m;
std::condition_variable cond;
bool flag = false;

std::thread thread1([]{
  std::unique_lock<std::mutex> lock(m);
  while(flag) {
    cond.wait(lock);
  }
  std::cout << "thread1 over\n";
});

std::thread thread2([]{
  std::unique_lock<std::mutex> lock(m);
  flag = true;
  cond.notify_all();
  std::cout << "thread2 over\n";
});

thread1.join();
thread2.join();
```

上面这种情况中，我们只考虑了 notify 是否会发生在上锁与 wait 之间，但 notify 也有可能发生在上锁之前，这也可能导致唤醒丢失。考虑下面这种情况：

```c++
// case2 唤醒丢失
std::mutex m;
std::condition_variable cond;

std::thread thread1([]{
  std::unique_lock<std::mutex> lock(m);
  cond.wait(lock);
  std::cout << "thread1 over\n";
});

std::thread thread2([]{
  std::unique_lock<std::mutex> lock(m);
  cond.notify_all();
  std::cout << "thread2 over\n";
});

thread1.join();
thread2.join();
```

 thread2 先上锁然后 notify_all（此时会隐式地解锁），再是 thread1 上锁并进行 wait。由于没有其它线程执行唤醒的工作，thread1 将永远 wait 下去——thread2 的 notify 实际上丢失了！这便是**不加条件导致唤醒丢失**的经典案例。

为了解决这一问题，我们应当加上某些限制，使得 notify 确定性地位于 wait 之后。于是需要套上一层条件判断的语句（如 `while`），检测当前是否应当 wait，套上 `while` 后，即便 thread2 首先执行，但由于 thread2 中修改了 predicate，thread1 也就能够很快检测到，能够跳过 wait 阶段。当然也可以不用 `while`，而是写成下面这种样子，这两者是等价的。

```c++
cond.wait(lock, [] { return flag; });
```

#### 虚假唤醒

当上面的条件判断语句由 `while` 改为 `if` 时，便存在**虚假唤醒**的情况。

> 当一个线程从等待一个已发出信号的条件变量中醒来，却发现它正在等待的条件不满足时，就会发生**虚假唤醒**。之所以称为虚假，是因为该线程似乎无缘无故地被唤醒了。但是虚假唤醒不会无缘无故地发生：它们通常会发生，因为在条件变量发出信号和等待线程最终运行之间，另一个线程运行并改变了条件。（抄自[百科](https://en.wikipedia.org/wiki/Spurious_wakeup)）

用一个例子来说明：在**生产者消费者**问题中，生产者每生产出一个产品，就通知所有消费者；当所有消费者被唤醒时，它们对产品的获取顺序为竞争关系，此时第一个赢得竞争的消费者取走了产品，而之后的消费者会发现并没有任何产品存在，又此时已经退出了 wait 阶段，也就继续推进下去直至消亡，最后就导致只有一个消费者进行了消费。比如下面这段代码：

```c++
// case3 虚假唤醒
std::mutex m;
std::condition_variable cond;
int cnt = 0; // 产品

void consumer() {
  std::unique_lock<std::mutex> lock(m);
  if (cnt == 0) {
    cond.wait(lock);
  }
}

void producer() {
  std::unique_lock<std::mutex> lock(m);
  cnt++;
  cond.notify_all();
}
```

解决办法就是**将 wait 放到条件判断循环中**，即类似于上一节中第二段代码。

### < future >

#### std::future

`std::future` 类型变量可以用于保存某个异步任务的结果（**共享变量**），并且内含一个状态(state)来表示该任务是否完成(ready)。因此可以把它当成一种简单的线程间同步的手段。通常由某个 "Provider" 创建，并在未来的某个线程中设置共享变量的值（future 因此得名），另外一个线程中与该共享变量相关联的 `std::future` 对象调用 `get()` 获取该值。

如果共享变量中 `state != ready`，则对 `std::future::get()` 的调用会阻塞，直到 Provider 设置了共享变量的值（然后 `state == ready`），这才返回异步任务的值或异常（如果发生了异常）。

#### std::promise

`std::promise<T>` 属于 Provider。它关联了一个 `std::future<T>` 对象，并可以通过 `get_future()` 返回该对象。同样的，它也可以通过 `set_value(T)` 进行共享变量的赋值，从而唤醒另一个调用了 `std::future::get()` 的线程（如果有）。

```C++
#include <functional>
#include <future>
#include <iostream>
#include <thread>

void print_int(std::future<int>& fut) {
  int x = fut.get();                    // 1. 阻塞
  std::cout << "value: " << x << '\n';  // 3. 打印 value: 10.
}

int main() {
  std::promise<int> prom;
  std::future<int> fut = prom.get_future();
  std::thread t(print_int, std::ref(fut));

  prom.set_value(10); // 2. 线程 t 结束对 fut.get() 的阻塞
  t.join();
  return 0;
}
// output:
// value: 10
```

#### std::packaged_task

`std::packaged_task<T(Args...)>` 也是 Provider。它除了关联一个 `std::future<T>` 对象，还包装了一个类型为 `T(Args...)` 的**可调用对象**。packaged_task 实现了 `operator()`（因而可以作为 `std::thread` 的初始化参数），调用一个 packaged_task 相当于调用内含的可调用对象，并将返回值或异常存在关联的 future 里。

当线程 a 用一个 `std::packaged_task` 初始化新线程 b 时，a 可以调用 `std::packaged_task::get_future()` 返回一个 future 对象，并调用 `get()` 阻塞直至 b 执行完返回。

```C++
#include <chrono>
#include <future>
#include <iostream>
#include <thread>

int count(int from, int to) {
  for (int i = from; i != to; --i) {
    std::cout << i << '\n';
    std::this_thread::sleep_for(std::chrono::seconds(1));
  }
  std::cout << "Finished!\n";
  return from - to;
}

int main() {
  std::packaged_task<int(int, int)> task(count); // contruct a packaged_task
  std::future<int> ret = task.get_future();      // get its future

  std::thread th(std::move(task), 10, 0);
  int value = ret.get(); // wait until count() is done

  std::cout << "The countdown lasted for " << value << " seconds.\n";

  th.join();
  return 0;
}
// output:
// 10
// 9
// 8
// 7
// 6
// 5
// 4
// 3
// 2
// 1
// Finished!
// The countdown lasted for 10 seconds.
```

## 并发应用

### 无锁队列(Lockless Queue)

### 线程池(Thread Pool)

利用 `std::future` 和 `std::packaged_task`，我们可以实现一个支持异步返回结果的**线程池**。

和普通的仅支持**执行但不返回结果**的线程池相比，其核心在于一个 `ThreadPool::execute()` 执行函数。该函数为模板函数，允许传入一个可调用对象及其参数列表，内部通过 `std::packaged_task` 包装后交付给空闲线程执行，并将返回结果保存在其关联的 `std::future` 对象中。执行函数可以返回这个 future，并让用户通过 `std::future::get()` 等待执行结果。

```C++
template<class F, class ...Args>
auto ThreadPool::execute(F&& callable, Args&& ...args) -> decltype(callable(args...)) {
  using returnType = decltype(callable(args...));
  std::packaged_task<returnType(Args...)> task(callable);
  std::future result = task.get_future();

  taskQueue.emplace(std::move(task)); // 加入就绪队列，唤醒线程取出任务并执行

  return result.get();
}

...

int max(int a, int b) {
  return a > b ? a : b;
}

int main() {
  ThreadPool& tp = ThreadPool::getInstance(); // 单例模式
  int res = tp.execute(max, 1, 2);
  cout << res;
  return 0;
}
```