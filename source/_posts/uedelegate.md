---
title: Unreal Engine の 委托
author: Leager
mathjax:
  - false
date: 2024-09-01 12:00:00
summary:
categories:
  - Unreal
tags:
img:
---

> 「**委托**」是一种泛型但类型安全的方式，可在 C++ 对象上调用成员函数。可使用委托动态绑定到任意对象的成员函数，之后在该对象上调用函数，即使调用程序不知对象类型也可进行操作。——[虚幻官方文档](https://dev.epicgames.com/documentation/zh-cn/unreal-engine/delegates-and-lamba-functions-in-unreal-engine)

<!-- more -->

委托本质上是基于「**观察者模式**」的，也就是有「**订阅**」的行为，在委托中称为「**绑定**」。

要使用委托，首先要用 `DECLARE*` 宏进行特定委托的类型声明，之后才允许用 `Bind*()`/`Add*()` 函数将「**订阅者**」（一个可调用对象）绑定到委托对象上。这样一旦某些事件触发，就可以通过 `Execute()`/`BroadCast()` 通知这些订阅者。

委托的基本类型有三种。

1. 单播委托
2. 多播委托
3. 动态委托

## 单播委托 & 动态单播委托

单播，顾名思义就是最多只能绑定**一个**可调用对象，并且不支持反射和序列化。优点是支持返回值。

而「动态」的意思是会在执行时实时根据给定的「函数名」去查找对应的函数（需要用 `UFUNCTION()` 修饰），因此执行速度很慢。此外，动态单播并不支持反射和序列化。

```cpp 单播委托
/**
 * 声明一个名为 DelegateType 的委托类型
 * 允许绑定的函数类型为 void(*)(ParamType1, ParamType2, ...)
 * 相当于 using DelegateType = TDelegate<void(ParamType1, ParamType2, ...)>;
 * 无返回值
 */
#define DECLARE_DELEGATE*(DelegateType, ParamType1, ParamType2, ...)

/**
 * 声明动态委托类型
 * 允许绑定的函数类型为 void(*)(ParamType1 ParamName1, ...)
 * 相当于定义了一个继承自 TBaseDynamicDelegate 的类
 * 无返回值
 */
#define DECLARE_DYNAMIC_DELEGATE*(DelegateType, ParamType1, ParamName1, ...)

/**
 * 允许绑定的函数类型为 RetValType(*)(ParamType1, ParamType2, ...)
 * 相当于 using DelegateType = TDelegate<RetValType(ParamType1, ParamType2, ...)>;
 * 有返回值
 */
#define DECLARE_DELEGATE_RetVal*(RetValType, DelegateType, ParamType1, ParamType2, ...)

/**
 * 允许绑定的函数类型为 RetValType(*)(ParamType1 ParamName1, ...)
 * 有返回值
 */
#define DECLARE_DYNAMIC_DELEGATE_RetVal*(DelegateType, ParamType1, ParamName1, ...)
```

## 多播委托 & 动态多播委托

多播则是允许绑定多个可调用对象，但不支持返回值和反射。

动态多播同样需要用 `UFUNCTION()` 修饰，但支持反射以及序列化，也就是可以在蓝图中进行绑定，此时需要使用 `BlueprintAssignable` 修饰符。

```cpp 多播委托
/**
 * 多播委托类型
 * 相当于 using DelegateType = TMulticastDelegate<void(ParamType1, ParamType2, ...)>;
 */
#define DECLARE_MULTICAST_DELEGATE*(DelegateType, ParamType1, ParamType2, ...)

/**
 * 线程安全多播类型
 * 相当于 using DelegateType = TMulticastDelegate<RetValType(ParamType1, ParamType2, ...)， FDefaultTSDelegateUserPolicy>;
 */
#define DECLARE_TS_MULTICAST_DELEGATE*(DelegateType, ParamType1, ParamType2, ...)

/**
 * 动态多播类型
 * 相当于定义了一个继承自 TBaseDynamicMulticastDelegate 的类
 */
#define DECLARE_DYNAMIC_MULTICAST_DELEGATE*(DelegateType, ParamType1, ParamName1, ...)
```

## 事件

除了上面 7 个宏族，UE 里还有一种声明方式是 `DECLARE_EVENT*()`。它和多播很像，但指定了 Owner，即只能在 Owner 类的成员函数中调用 `BroadCast()`。

```cpp EVENT 委托源码
#define FUNC_DECLARE_EVENT( OwningType, EventName, ReturnType, ... ) \
	class EventName : public TMulticastDelegate<ReturnType(__VA_ARGS__)> \
	{ \
		friend class OwningType; \
	};
```

可以看到用了友元类来进行访问权限的控制。

## 绑定 & 解绑

### 非动态委托

`Bind*()` 系用于单播绑定，`Add*()` 系用于多播绑定。

```cpp 非动态委托
/* 绑定类的静态函数 */
MyUnicastDelegate.BindStatic(/* A static function pointer */, /* Parameters */);
MyMulticastDelegate.AddStatic(/* &MyClass::MyStaticFunc */, /* ... */);


/* 绑定 lambda 函数，可能出现悬垂引用的问题 */
BindLambda(/* Lambda */, /* Parameters */);
AddLambda(/* [this](...) {...} */, /* ... */);


/* 绑定 Weak lambda 函数，区别在于如果 this 无效不会执行 lambda */
BindWeakLambda(/* User Object */, /* Lambda */, /* Parameters */);
AddWeakLambda(/* this */, /* [this](...) {...} */, /* ... */);


/* 绑定到继承自 UObject 对象上的某个函数 */
BindUObject(/* UObject* */, /* A function pointer */, /* Parameters */);
AddUObject(/* this */, /* &MyClass::MyFunc */, /* ... */);


/* 绑定到不继承自 UObject 的对象上的函数，同样可能出现悬垂引用的问题 */
BindRaw(/* Raw Pointer */, /* A function pointer */, /* Parameters */);
AddRaw(/* Other */, /* &OtherClass::OtherFunc */, /* ... */);


/* 在上面的基础上，传入对象为 Shared Pointer */
BindSP(/* Shared Pointer */, /* A function pointer */, /* Parameters */);
AddSP(/* Other.ToSharedRef() */, /* &OtherClass::OtherFunc */, /* ... */);


/* 上面的线程安全版本 */
BindThreadSafeSP(...);
AddThreadSafeSP(...);


/* 基于函数名进行绑定，需要用 UFUNCTION() 修饰 !!开销很大!! */
BindUFunction(/* User Object */, /* Function name */, /* Parameters */);
AddUFunction(/* this */, /* "MyFunction" */, /* ... */);


/* 单播/动态单播 解除绑定 */
UnBind();


/* 多播/动态多播 解除某个绑定 */
Remove(/* this */, /* &MyClass::MyFunc */);
Remove(/* Delegate Handle */);


/* 多播/动态多播 解除所有绑定 */
RemoveAll();
Clear();
```

> 对于单播而言，后续的绑定会覆盖之前的。

### 动态委托

动态委托绑定的函数必须用 `UFUNCTION()` 修饰，否则无效。

```cpp 动态委托
/* 动态单播 */
#define BindDynamic( UserObject, FuncName ) \
        __Internal_BindDynamic( UserObject, FuncName, \
                                STATIC_FUNCTION_FNAME( TEXT( #FuncName ) ) )

BindDynamic(/* User Object */, /* A function poiter */);


/* 动态多播 */
#define AddDynamic( UserObject, FuncName ) \
        __Internal_AddDynamic( UserObject, FuncName, \
                               STATIC_FUNCTION_FNAME( TEXT( #FuncName ) ) )

AddDynamic(/* this */, /* &MyClass::MyFunc */);


/* 动态多播 且去重 */
#define AddUniqueDynamic( UserObject, FuncName ) \
        __Internal_AddUniqueDynamic( UserObject, FuncName, \
                                     STATIC_FUNCTION_FNAME( TEXT( #FuncName ) ) )

AddUniqueDynamic(...);


/* 移除 */
#define RemoveDynamic( UserObject, FuncName ) \
        __Internal_RemoveDynamic( UserObject, FuncName, \
                                  STATIC_FUNCTION_FNAME( TEXT( #FuncName ) ) )

RemoveDynamic(...);
```

这几个其实都是宏定义，而不是类的成员函数（所以 intellisense 没法识别）。

## 通知

```cpp 通知
/* 单播/动态单播 通知，可能存在函数指针无效的问题，此时会报错 */
Execute(/* Parameters */);


/* 上面的安全版本，如果函数指针无效则不执行 */
ExecuteIfBound(/* Parameters */);


/* 多播/动态多播 通知所有订阅者 */
BroadCast(/* Parameters */);
```

注意 `Execute*()` 都可以有返回值，但 `BroadCast()` 不行。