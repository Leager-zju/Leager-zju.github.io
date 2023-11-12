---
title: C++11 の 其它特性(Else)
author: Leager
mathjax: true
date: 2023-02-06 23:02:41
summary:
categories:
    - C++11
tags:
    - C++
img:
---

有些 C++11 特性比较琐碎，单纯用一篇文章描述浪费，还有灌水嫌疑(bushi)，于是整合到同一篇来讲。

<!--more-->

## 范围 for 循环

允许 for 循环中使用 `for (范围变量声明 : 范围表达式)` 的形式进行遍历，无需 `for(...;...;...)` 式的写法。

```c++
std::vector<int> v;

// C++11 前
for (auto iter = v.begin(); iter != v.end(); iter++) {
  DoSomeThing(*iter);
}

// C++11 起
for (auto&& item : v) { // item 为 int& 型
  DoSomeThing(item);
}
```

## constexpr

`constexpr` 和 `const` 很像，两者的共同之处在于都是**修饰词**，可以用于修饰变量与函数，不同之处在于，`const` 修饰的对象仅包含一层 **read-only** 含义，即仅保证该对象在运行时不会被改变，但其仍有可能为动态变量。

而 `constexpr` 可以说是 `const` 的升华版本，用 `constexpr` 修饰的对象**在编译时便能计算出来**，整个运行过程中都不可以被改变，直接自带一层 `const` 语义。这可以说是一个非常强大的优化，有些操作能够直接在编译时完成，就不用再在运行时多次耗费时间。

> 在 constexpr 出现之前，可以在编译期初始化的 const 都隐式为 constexpr，所以其实早就有了。直到 C++11，constexpr 才从 const 中**细分**出来成为一个关键字。作为一门效率敏感型的语言，应当尽可能地使用 **constexpr** 进行代码优化。

### constexpr 变量

用 `constexpr` 修饰的变量必须为[字面类型](https://zh.cppreference.com/w/cpp/named_req/LiteralType)，并且必须立即被初始化，初始化时所调用的表达式必须为[常量表达式](https://zh.cppreference.com/w/cpp/language/constant_expression)。

### constexpr 函数

对于用 `constexpr` 修饰的函数，如果其传入的参数可以在编译时计算出来，那么这个函数就会产生编译时的值；反之，就和普通函数一样了。

```c++
constexpr int calculate(int x, int y) { return x + y; }

int main() {
  int x = 1, y = 2;
  constexpr int res1 = calculate(1, 2);    // OK! 编译时完成计算
  // constexpr int res2 = calculate(x, y); // ERROR! calculate 视为普通函数，除非改为 constexpr int x = 1, y = 2
}
```

> 虚函数由于是在运行时进行查表调用的，故无法声明为 `constexpr`

constexpr 函数也包含诸多限制：

1. 其所有的参数类型及返回值类型都必须为字面类型；
2. 在不为构造函数时，有且仅能有一条 return 语句（允许包含 `typedef`、`using`、`static_assert`）；
3. 只能调用其它 constexpr 函数；

可以用 constexpr 函数实现递归，科技为**三元运算符**。`fact(5)` 将在编译时得到运算，这也是与 `inline` 函数的一个显著区别。

```c++
constexpr int fact(int i) {
  return i > 1 ? i * fact(i-1) : 1;
}
```

### constexpr 构造函数

若构造函数中所有参数均为 constexpr 变量，则该类的所有成员变量也均为 constexpr，这个对象也就为 constexpr 对象了。

需**额外注意**的是：

1. constexpr 构造函数所有初始化必须都放在初始化列表里，并且函数体为空；
2. 仅有 constexpr 对象可以调用声明为 `constexpr` 的成员函数；

```c++
class Test {
 public:
  constexpr Test(int val_): val(val_) {}
  constexpr int get_val() const { return val; }

 private:
  int val;
};

int main() {
  int x = 1;
  // constexpr Test foo(x);            // ERROR! x 不是 constexpr 变量
  Test foo(x);                         // OK! 视为普通构造函数
  // constexpr int val = foo.get_val() // ERROR! 非 constexpr 对象

  constexpr Test bar(1);           // OK! 此时 bar 为 constexpr 对象
  constexpr int val = t.get_val(); // OK!
}
```

## nullptr

C++11 以前使用宏 `NULL` 来表示空指针。本质上它是 `#define NULL 0`，也就是一个数字 0，并不算真正意义上的指针。如果遇到以下代码，则会出现二义性：

```c++
void func(int) {}
void func(void*) {}
```

> 函数 `func` 有两个重载形式，当调用 `func(NULL)` 时，两个函数都有充分的理由被调用，因为 NULL 可以视为 0 而调用 `func(int)`，二义性由此产生。

C++11 引入的新关键词 `nullptr` 代表指针**字面量**，它是 `std::nullptr_t` 类型的纯右值，该类型可以隐式转换到任何指针类型及任何成员指针类型。注意这个转换是**单向**的！

```c++
template<class T>
constexpr T clone(const T& t) {
  return t;
}

void func(int) {
  std::cout << "函数 func(int) 已调用\n";
}
 
void func(int*) {
  std::cout << "函数 func(int*) 已调用\n";
}
 
int main() {
  func(nullptr);         // OK!
  func(0);               // OK!
  // func(NULL);         // ERROR! 二义性
 
  func(clone(nullptr));  // OK!
  //  func(clone(0));    // ERROR! 非字面量的零不能为空指针常量
  //  func(clone(NULL)); // ERROR! 非字面量的零不能为空指针常量
}

// output:
// 函数 func(int*) 已调用
// 函数 func(int) 已调用
// 函数 func(int*) 已调用
```

## override

`override` 用于修饰派生类中的**虚函数**，告诉编译器（与程序员）该函数进行了重写。如果一个函数声明为 `override` 但父类却没有这个虚函数，编译报错，故可以避免程序员在重写基类函数时无意产生的错误，提高代码规范性。

```c++
struct A {
    virtual void foo();
    void bar();
};
 
struct B : A {
  void foo() const override; // ERROR! A::foo 非 const，签名不匹配
  void foo() override;       // OK!
  void bar() override;       // ERROR! A::bar 非虚
};
```

## final

`final` 用于指定某个**虚函数**不能在派生类中被重写，或者某个类不能被派生。

```c++
struct Base {
  virtual void foo();
};
 
struct A : Base {
  void foo() final;    // OK! A::foo 为 final
  void bar() final;    // ERROR! A::bar 非虚，因此它不能是 final 的
};
 
struct B final : A {   // OK! B 为 final
  void foo() override; // ERROR! foo 不能被重写，A::foo 为 final
};
 
struct C : B{};        // ERROR! B 为 final，无法进一步派生
```

> 对于多态类，如果确定一个虚函数不会再被覆盖，或者该类不会再被继承，则推荐标上 `final`。这可以为编译器提供非常有价值的编译优化信息，总而将原本需要推迟到运行期才能确定的虚函数调用提前在编译期就已确定。如被调用的函数能与上层调用方一起进一步地做函数内联、常量折叠、无用代码消除等优化，则可以压榨出非常可观的性能提升。

## enum class

C++11 以前，**枚举**并不限定作用域，所有枚举成员均暴露在外层作用域下，并且所有枚举值都可自动转换为整型。这也就导致：

1. 不同枚举类型的枚举成员禁止重名；
2. 不同枚举类型能够相互比较；

显然，这种传统的枚举并不安全。

C++11 引入了**限定作用域的枚举**来解决以上问题。

```c++
enum Color { red, blue, green };
enum class newColor { red, blue, green };  // OK! 此限定域内自成一派，与其它枚举类型无影响
// enum class newColor: typename {...};    // 枚举类型底层默认为 int，可以如此进行修改

Color c1 = 1;             // ERROR! C++11 起不能通过整型来初始化枚举类型
Color c2 = red;           // OK! red 在该作用域中可访问，并且这里 red 的类型为 Color
Color c3 = Color::red;    // OK! 可以通过 枚举类型::枚举成员名 访问成员

newColor l1 = red;        // ERROR! red 为 Color 类型，不能用于初始化 newColor 类型
newColor l2 = Light::red; // OK! 仅能通过 枚举类型::枚举成员名 访问成员

int foo = Color::red;     // OK! 无限定作用域的枚举成员可转化为整数
int bar = newColor::red;  // ERROR! 限定作用域的枚举成员不可转化为整数

std::cout << std::boolalpha;
std::cout << (red == 0);  // output: true
```

虽然限制很多，但也更安全。应当尽可能使用带限定域的枚举。

## static_assert

说到这个，就不得不提另一个很像的叫 `assert` 的玩意。这两者都起到**断言**的作用，区别在于：

`static_assert` 作为 C++11 新引入的**关键字**，为**静态断言**，即编译时进行断言，若表达式为 false，则编译错误。这样一来不会生成目标代码，也不会影响程序性能。用法为：

```c++
static_assert(expr, msg); // 如果 expr == false，则输出 msg
```

`assert` 为**动态断言**，在运行时执行，不影响编译（其实就是一个**宏**）。通过 `static_cast<bool>` 把表达式转换成 `bool` 类型，从而实现断言。缺点在于影响程序性能，常用于 debug 模式，在 release 模式中一般会关掉。

## 自定义字面量

C++ 自带如下字面量（及其对应引用）：

1. 整数型，如 `1`；
2. 浮点型，如 `1.23`；
3. 字符型，如 `'1'`；
4. 字符串型，如 `"123"`；

以整数型为例，字面量最后可以添加后缀来表示具体类型：

1. `unsigned int`，如 `123u`；
2. `lont int`，如 `123l`；

这些后缀就仿佛**单位**一般，能够告诉程序员一些关于类型的信息。

C++11 以前，我们如果希望定义一些描述时间相关的变量，或许会这样写：

```c++
int time = 1;
```

但问题在于，这里的 `time` 的单位是什么？秒？微秒？还是纳秒？如果不加以注释，则会为代码阅读带来不便。有没有一种手段，能够让我们编写以下代码，使得开发者能够直接得到想要的信息？

```c++
auto time1 = 30_ms;
auto time2 = 40_s;
```

答案是**肯定**的，只需在上面的代码之前加上以下语句，就能成功编译并运行。

```c++
int operator""_ms (unsigned long long time) {
  return time;
}
int operator""_s (unsigned long long time) {
  return 1000 * time;
}
```

当代码中出现了 `30_ms` 这样的字面量时，编译器认出这里有一个用户定义后缀 `_ms`，于是首先会去查找函数 `operator""_ms`，并检查前面的字面量 `30` 类型是否与函数形参类型匹配。若失败，则报错。

> 为了不与 C++ 内置的自定义后缀混淆，用户定义的后缀通常以下划线开头。

> 有人会注意到上面的形参类型为 `unsigned long long`，这是由于自定义字面量存在**限制**——C++11 只允许字面量后缀函数的参数为以下类型，对应整数，浮点，字符以及字符串：
>
> - `unsigned long long`
> - `long double`
> - `char` / `wchar_t` / `char8_t` / `char16_t` / `char32_t`
> - `const char*`
> - `const char*, std::size_t`
> - `const wchar_t*, std::size_t`
> - `const char16_t*, std::size_t`
> - `const char32_t*, std::size_t`

如果希望在编译时就调用字面量后缀函数，则需要把函数定义为 `constexpr`。

## 新的数据结构

### std::forward_list

> 定义于头文件 `<forward_list>`

以前有双向链表 `std::list`，现在加入了新容器**单向链表** `std::forward_list`，每个节点节省了一个指针的空间。

forward_list 内部实现以下功能：

|                    方法                    |                             描述                             |
| :----------------------------------------: | :----------------------------------------------------------: |
| `begin()` /  `cbegin` / `end()` / `cend()` |                  返回指向起始/末尾的迭代器                   |
|    `before_begin()` / `cbefore_begin()`    |           返回指向第一个元素之前的迭代器（头节点）           |
|                 `empty()`                  |                       检查容器是否为空                       |
|                `max_size()`                |                     返回可容纳最大元素数                     |
|                 `clear()`                  |                           清空容器                           |
|      `insert_after(iter_pos, value)`       |                      在某处之后插入元素                      |
|      `emplace_after(iter_pos, value)`      |                      在某处之后构造元素                      |
|          `erase_after(iter_pos)`           |                      移除某处之后的元素                      |
|            `push_front(value)`             |                      在链表头部插入元素                      |
|           `emplace_front(value)`           |                      在链表头部构造元素                      |
|               `pop_front()`                |                         移除头部元素                         |
|           `merge(forward_list)`            |         合并两个已排序链表，默认升序，可自定义比较器         |
|   `splice_after(iter_pos, forward_list)`   |           移动另一链表的元素到某处后，执行移动语义           |
|    `remove(value)` / `remove_if(pred)`     |                    移除满足特定标准的元素                    |
|                `reverse()`                 |                           倒转链表                           |
|                 `unique()`                 | 如果有多个连续的值相等的元素，则只保留第一个，移除后续所有，可自定义比较器 |
|                  `sort()`                  |              排序链表，默认升序，可自定义比较器              |

### std::unordered_map

> 定义于头文件 `<unordered_map>`

`std::map` 底层采用红黑树实现，会对 key 进行排序，适用于对有序有要求的场景，缺点是内存占用大。

 `std::unordered_map` 底层采用哈希表实现，并不会进行排序，且查找时间几乎为 `O(1)`，适用于查找多的场景。用法几乎与 `std::map` 一样。

### std::unordered_set

> 定义于头文件 `<unordered_set>`

其之于 `std::set` 就好比 `std::unordered_map` 之于 `std::map`。略。

### std::array

> 定义于头文件 `<array>`

`std::array` 是将静态的连续一维数组进行封装的容器，方便内存的管理与释放，遵循**聚合初始化**规则，使用**初始化列表**进行初始化。与 `std::vector` 的区别在于无法对数组大小进行修改，即没有 `push_back()` 之类的操作，因而更加精简。可以通过以下操作访问元素：

- `at(index)`：访问指定下标的元素；
- `operator[]`：访问指定下标的元素；
- `front()`：等价于 `at(0)`；
- `back()`：等价于 `at(size-1)`；
- `data()` 返直接访问底层数组；
- 全局函数 `std::get<index>(array)`；

并且类内使用 `fill()` 函数来代替之前的 `memset()` 操作。

### std::tuple

> 定义于头文件 `<tuple>`

​	`std::tuple` 是固定大小的值集合，却不要求这些值都为相同类型。它是 `std::pair` 的拓展，`std::pair` 可以视为只容纳两个元素的 `std::tuple`。`std::tuple` 拥有从 `std::pair` 的转换赋值。

可以通过以下操作构造一个 tuple：

- 常规初始化；

    ```c++
    std::tuple<int, double, char> t1 = {1, 2.0, '3'}; // 列表初始化
    std::tuple<int, double, char> t2(t1);             // 拷贝初始化
    std::tuple<int, double, char> t3(std::move(t1));  // 移动初始化
    ```

- 函数模板 `make_tuple<Types...>(args...)` 创建一个 tuple 对象，并根据 `Types` 定义具体类型；

    ```c++
    std::tuple<int, double, char> t = make_tuple(1, 2.0, '3'); // 模板自动推导
    ```

- `tie(args...)` 创建**左值引用**组成的 tuple，或将接收到的 tuple / pair 进行解包；

    ```c++
    std::unordered_set<int> s;
    bool result;
    std::tie(std::ignore, result) = s.insert(1);
    ```

    如果一个函数需要返回多个值，则可以返回一个 tuple 或是 pair，然后用 `std::tie` 将收到的返回值 `[iterator, bool]` 解包为 `std::ignore` 与 `result`。这里 `std::ignore` 为一个常量，是一个**占位符**，表示这里不需要任何变量接收。

    > 相当于 Go 里面的 `_`。

- `forward_as_tuple(args...)` 创建**转发引用**组成的 tuple；

    ```c++
    std::unordered_map<int, std::string> m;
    
    // 插入 (1, "aa")
    m.emplace(std::piecewise_construct,
              std::forward_as_tuple(1),       // 1 转发给 int 初始化
              std::forward_as_tuple(2, 'a')); // 2, 'a' 转发给 string 初始化
    ```

- `tuple_cat(tuples...)` 连接任意数量的 tuple；

并可以通过全局函数 `std::get<index>(tuple)` 访问 tuple 对象的第 index 个元素。

## 新的算法

> 定义于头文件 `<algorithm>`

### std::all_of / std::any_of / std::none_of

`std::all_of(first, last, pred)` 检查迭代器范围 `[first, last)` 内是否均满足 `pred`；

`std::any_of(first, last, pred)` 检查迭代器范围 `[first, last)` 内是否存在一个元素满足 `pred`；

`std::none_of(first, last, pred)` 检查迭代器范围 `[first, last)` 内是否均不满足 `pred`；

```c++
std::vector<int> nums{1, 2, 3, 4, 5};
std::cout << std::boolalpha << std::all_of(nums.begin(), nums.end(), [](int i) { return i > 0; });
// output: true
```

### std::find / std::find_if / std::find_if_not

`std::find(first, last, value)` 返回迭代器范围 `[first, last)` 内第一个 `operator== (value)` 返回 true 的元素**的迭代器**；

`std::find_if(first, last, pred)` 返回迭代器范围 `[first, last)` 内第一个满足 `pred` 的元素**的迭代器**；

`std::find_if_not(first, last, pred)` 返回迭代器范围 `[first, last)` 内第一个不满足 `pred` 的元素**的迭代器**；

```c++
std::vector<int> nums{1, 2, 3, 4, 5};
std::cout << *std::find_if(nums.begin(), nums.end(), [](int i) { return i > 3; });
// output: 4
```

### std::copy / std::copy_if / std::copy_n

`std::copy(first, last, begin)` 复制迭代器范围 `[first, last)` 内所有元素到 `begin` 开始的范围；

`std::copy_if(first, last, begin, pred)` 与上面相比，仅复制满足 `pred` 的元素；

`std::copy_n(first, count, begin)` 复制从 `first` 开始的 `count` 个元素到 `begin` 开始的范围；

```c++
std::vector<int> nums{1, 2, 3, 4, 5};
std::vector<int> new_nums;
std::copy_n(nums.begin(), 5, new_nums.begin());
// new_nums = {1, 2, 3, 4, 5}
```

### std::is_partitioned

`std::is_partitioned(first, last, pred)` 检查迭代器范围 `[first, last)` 内是否所有满足 `pred` 的元素都在不满足 `pred` 的元素之前

```c++
std::vector<int> nums{1, 2, 3, 4, 5};
std::cout << std::boolalpha << std::is_partitioned(nums.begin(), nums.end(), [](int i) { return i <= 3; });
// output: true
```

### std::is_sorted

`std::is_sorted(first, last{, comp})` 检查迭代器范围 `[first, last)` 内是否有序。可自定义比较器 `comp`，默认为非降序，即 `comp <=> operator<`。

```c++
std::vector<int> nums{1, 2, 3, 4, 5};
std::cout << std::boolalpha << std::is_sorted(nums.begin(), nums.end());
// output: true
```

### std::minmax

`std::minmax(a, b{, comp})` 返回 `a`，`b` 中较小值与较大值**的引用**，并打包为 `std::pair` 返回，可自定义比较器 `comp`。

若需要返回至少三个元素中的最小值与最大值的引用，则改为版本 `std::minmax(initializer_list{, comp})`。

```c++
int minm, maxm;
std::tie(minm, maxm) = std::minmax({1, 2, 3, 4, 5});
std::cout << minm << " " << maxm;
// output: 1 5
```

### std::minmax_element

`std::minmax_element(first, last{, comp})` 返回迭代器范围 `[first, last)` 中较小值与较大值**的迭代器**，并打包为 `std::pair` 返回，可自定义比较器 `comp`。

```c++
std::vector<int> nums{1, 2, 3, 4, 5};
std::vector<int>::iterator min_iter, max_iter;
std::tie(min_iter, max_iter) = std::minmax_element(nums.begin(), nums.end());
std::cout << *min_iter << " " << *max_iter;
// output: 1 5
```

### std::itoa

`std::itoa(first, last, value)` 以 value 为起始，并不断以 `++value` 填充迭代器范围 `[first, last)`。

```c++
std::vector<int> nums(10);
std::itoa(nums.begin(), nums.end(), 1);
// nums = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
```

