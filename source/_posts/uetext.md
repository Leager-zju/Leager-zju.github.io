---
title: Unreal Engine の 字符串处理
author: Leager
mathjax:
  - false
date: 2024-08-27 12:00:00
summary:
categories:
  - unreal
tags:
  - unreal
  - gameplay
img:
---

在 UE 中主要有三种字符串实现，分别是 `FName`，`FText`，`FString`。参考官方文档，对这三种实现进行深入剖析。

<!-- more -->

## TCHAR

C++ 支持两种字符集，ANSI 和 Unicode，实际对应的字符类型分别是 `char` 和 `wchar_t`。为了在不同平台环境下，使用不同的字符类型，UE 使用 `TCHAR` 对 `char` 和 `wchar_t` 进行封装，将其中的操作进行了统一，使程序具有可移植性。

> Either ANSICHAR or WIDECHAR, depending on whether the platform supports wide characters or the requirements of the licensee.

对于一个字符串字面量 `"hello"` 而言，默认使用的是 `char` 类型。如果前面多加个 L，成为 `L"hello"`，就表示 `wchar_t`。UE 通过一个 `TEXT()` 宏包裹来选择适合当前平台的编码方式。

```cpp TEXT() 宏定义
#define UTF8TEXT_PASTE(x)  u8 ## x
#define UTF16TEXT_PASTE(x) u ## x
#if PLATFORM_WIDECHAR_IS_CHAR16
	#define WIDETEXT_PASTE(x)  UTF16TEXT_PASTE(x)
#else
	#define WIDETEXT_PASTE(x)  L ## x
#endif

#if !defined(TEXT) && !UE_BUILD_DOCS
	#if PLATFORM_TCHAR_IS_UTF8CHAR
		#define TEXT_PASTE(x) UTF8TEXT(x)
	#else
		#define TEXT_PASTE(x) WIDETEXT(x)
	#endif
	#define TEXT(x) TEXT_PASTE(x)
#endif

#define UTF8TEXT(x) (UE::Core::Private::ToUTF8Literal(UTF8TEXT_PASTE(x)))
#define WIDETEXT(str) WIDETEXT_PASTE(str)
```

不难发现，会根据 `PLATFORM_TCHAR_IS_UTF8CHAR` 这个宏来选择相应的编码方式。而 UE 中的所有字符串都作为 FString 或 TCHAR 数组以 UTF-16 格式存储在内存中，所以内部设置字符串变量文字时应使用 `TEXT()` 宏。

### 编码转换

UE 提供了一些宏，可以将字符串转换为各种编码或从各种编码转换字符串。这些宏使用局部范围内声明的类实例，并在堆栈上分配空间，因此**保留**指向这些宏的指针非常重要。

```cpp
// TCHAR* -> char*
TCHAR_TO_ANSI(TcharString);
// TCHAR* -> wchar_t*
TCHAR_TO_UTF8(TcharString);
// char* -> TCHAR*
ANSI_TO_TCHAR(CharString);
// wchar_t* -> TCHAR*
UTF8_TO_TCHAR(WChartString);
```

## FName

FName 在语义上指的是资源的**名字**。其具有**大小写不敏感**，**不可变**，**唯一**这三个特性。

### 底层实现

FName 本质上是一个**索引**，内部只有三个整型变量，而不存储任何字符串内容。

其唯一性是通过「基于哈希表的存储系统」实现的。在用字符串进行 FName 的构造时，首先会将字符串做一次哈希，映射到哈希表中，并得到在哈希表中的索引号，这样保证不会有重复的字符串出现在表中的同时，又能通过索引号进行快速查询。

```cpp class FName in NameTypes.h
/**
 * Index into the Names array (used to find String portion
 * of the string/number pair used for comparison)
 */
FNameEntryId	ComparisonIndex;
/**
 * Number portion of the string/number pair (stored internally
 * as 1 more than actual, so zero'd memory will be the default, no-instance case)
 */
uint32			Number;
/**
 * Index into the Names array (used to find String portion
 * of the string/number pair used for display)
 */
FNameEntryId	DisplayIndex;
```

`ComparisonIndex` 和 `DisplayIndex` 表示 string portion 在表中的索引，里面只有一个 uint32 的索引值，而 `number` 是 number portion。所以整体内存占 12B。

> 形如 `XYZ_123` 这样的字符串会被分为 `XYZ` 和 `123` 两部分。前者为 string portion，后者为 number portion。
> 
> 之所以这么搞是因为当在关卡中拷贝一个名为 `Name` 的 Actor 时，新生成的那份会在名字后面加一个后缀，成为 `Name_1`。后续的拷贝就是 `_2`，`_3`，……如果把每个 Actor 的名字都加入表中，那内存开销就是 O(n)。而如果划分为 string/number 两个部分，就只需要存一份字符串即可，同时又会把 number 部分以 uint32 的形式存储起来，可以用于 compare，大大节省了内存开销。

`ComparisonIndex` 和 `DisplayIndex` 的区别在于，索引到的 string portion 是否区分大小写。比如 `ABC` 和 `abc` 两个 FName，当进行比较时，会用 ComparisonIndex 去 IgnoreCase 的那张表查询，得到的结果一致，认为是两个相同的 FName；而用于显示时，则用 DisplayIndex 去 CaseSensitive 的表查询，这张表存的就是原始字符串了。

### 为何快

两个 FName 之间的比较并不执行字符串的对比，而是进行**数值**的对比，这可极大地节约 CPU 开销。该数值是通过一个内部函数 `ToUnstableInt()` 进行计算的，这个函数会将 `ComparisonIndex` 和 `Number` 组装成一个 uint64 的值，然后返回。

```cpp NameTypes.h
FORCEINLINE uint64 ToUnstableInt() const
{
	static_assert(STRUCT_OFFSET(FName, ComparisonIndex) == 0);
	static_assert(STRUCT_OFFSET(FName, Number) == 4);
	static_assert((STRUCT_OFFSET(FName, Number) + sizeof(Number)) == sizeof(uint64));

	uint64 Out = 0;
	FMemory::Memcpy(&Out, this, sizeof(uint64));
	return Out;
}
```

为了优化字符串，在游戏开发过程中，如果可以确定哪些字符串是固定不变的数据且无需考虑文本本地化，应该尽可能对它们使用 FName，只在必要的时候才将 FName 转换为其他字符串类型进行操作。

### 查找与添加

```cpp
// 若不在表中，则构造函数结果为 NAME_None/FName()，但不进行添加。
FName res1 = FName(TEXT("foo"), FNAME_Find);

// 若不在表中，则添加；反之做和 Find 一样的行为。
FName res2 = FName(TEXT("bar"), FNAME_Add);
```

## FText

FText 是一种静态字符串。当字符串需要显示给玩家时，使用 FText 以支持文本本地化和增强字体渲染性能。

### 底层实现

FText 对象内部用一个带**引用计数**的智能指针 `TRefCountPtr<ITextData>` 来指向实际存储的数据，这样就使得拷贝一个 FText 的成本很低。

## FString

FString 则是是对 string 进行的一个封装，和 `std::string` 非常相似，但底层字符串是用 `TArray<TCHAR>` 进行存储的。其着重于字符串的操作，提供了大量对字符串的操作接口，是三者中唯一**可修改**的字符串类型，但其它两种字符串来说消耗更高，性能更低。

## 三者之间的转换

|从|到|函数|说明|
|:-:|:-:|:-:|:-:|
|FName|FText|`FText::FromName(name)`||
|FName|FString|`name.ToString()`||
|FText|FName||FText 不能直接转换到 FName，可先转换为 FString，再转换为 FName|
|FText|FString|`txt.ToString()`|对于某些语言来说可能存在损耗。|
|FString|FName|`FName(*str)`|**不可靠**。因为 FName 不区分大小写，所以转换存在损耗。|
|FString|FText|`FText::FromString(str)`||