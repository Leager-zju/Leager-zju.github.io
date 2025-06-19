---
title: Unreal Engine の Gameplay 框架
author: Leager
mathjax:
  - false
date: 2024-08-29 12:00:00
summary:
categories:
  - Unreal
tags:
img:
---

<!-- more -->

## UObject

> 部分参考 [InsideUE4 - UObject](https://zhuanlan.zhihu.com/p/24319968)

`UObject` 是 UE 中所有 C++ 对象的根基类，它是 UE 对象系统的重要组成部分。通过 UObject，UE 支持以下功能：

- 垃圾回收
- 引用更新
- 映象
- 序列化
- 默认属性变化自动更新
- 自动属性初始化
- 自动编辑器整合
- 运行时类型信息可用
- 网络复制
- ...



它有以下五个继承自 `UObjectBase` 的关键变量。

```cpp
/**
 * 用于描述一个对象。比如
 *   - RF_ClassDefaultObject 表明它是 ClassDefaultObject；
 *   - RF_MarkAsRootSet 表明它不应被 GC，即使不被引用；
 *   - RF_NeedInitialization 表明该对象还未初始化完成状态；
 *   - ...
 * 这些描述符体现为一个 32 位无符号整数的 bit
 */
EObjectFlags ObjectFlags;

/**
 * GUObjectArray 的索引，用于实现「内存管理」与「垃圾回收」。
 * 其中 GUObjectArray 是一个全局 UObject 数组。
 * 每构造一个对象，都会在构造函数中调用 AddObject() 将其加入到数组中。
 */
int32        InternalIndex;

/** 该 Object 所属的 UClass，用于实现「反射」 */
ObjectPtr_Private::TNonAccessTrackedObjectPtr<UClass> ClassPrivate;

/** 该 Object 的名字，用于实现「反射」 */
FName        NamePrivate;

/**
 * 拥有该 Object 的 Object。
 * 在运行时引用自己的对象可能有无穷个，但自己的 Outer 有且仅有一个。
 * Outer 语义上就是真正拥有自己的那个对象。
 */
ObjectPtr_Private::TNonAccessTrackedObjectPtr<UObject> OuterPrivate;
```

后面四个对象都可以通过一个 public 接口 `GetXXX()` 获取。

### UObject 的内存管理

UObject 与 UE 内存管理相关的所有逻辑是在其基类 `UObjectBase` 中实现的。

#### 构造函数

首先观察 UObjectBase 的构造函数，发现执行了关键的一条函数 `AddObject()`。

```cpp UObjectBase.cpp
UObjectBase::UObjectBase(...)
{
	check(ClassPrivate);
	// Add to global table.
	AddObject(InName, InInternalFlags, InInternalIndex, InSerialNumber);
}	

void UObjectBase::AddObject(FName InName, EInternalObjectFlags InSetInternalFlags,
                            int32 InInternalIndex, int32 InSerialNumber)
{
  ...
  EInternalObjectFlags InternalFlagsToSet = InSetInternalFlags;
  ...
  GUObjectArray.AllocateUObjectIndex(this, InternalFlagsToSet,
                                     InInternalIndex, InSerialNumber);
  HashObject(this);
}
```

这里主要关注其中两步，即 `AllocateUObjectIndex()` 和 `HashObject()`。

#### AllocateUObjectIndex()

这个函数的作用是将 Object 放到一个全局的名为 `GUObjectArray` 的对象中。顾名思义，该对象用于管理所有 UObject 的信息，之后要提的垃圾回收也是基于这个对象进行的。

```cpp UObjectArray.cpp
void FUObjectArray::AllocateUObjectIndex(UObjectBase* Object,
                                         EInternalObjectFlags InitialFlags,
                                         int32 AlreadyAllocatedIndex,
                                         int32 SerialNumber)
{
  ...
  int32 Index = INDEX_NONE;
  LockInternalArray();

  // 如果已经分配过了
  if (AlreadyAllocatedIndex >= 0)
  {
    Index = AlreadyAllocatedIndex;
  }
  // 如果开启了忽略 GC 的优化
  else if (OpenForDisregardForGC && DisregardForGCEnabled())
  {
    Index = ++ObjLastNonGCIndex;
    // 如果超过 忽略 GC 的最大 Object 数量，则需要扩容。
    if (ObjLastNonGCIndex >= MaxObjectsNotConsideredByGC)
    {
      Index = ObjObjects.AddSingle();
    }
    MaxObjectsNotConsideredByGC = FMath::Max(MaxObjectsNotConsideredByGC,
                                             ObjLastNonGCIndex + 1);
  }
  // 剩下就是有 GC 的情况
  else
  {
    // 这里用「空闲列表」是因为后续回收的 Object 索引是不确定的
    // 要用空闲列表防止产生碎片
    if (ObjAvailableList.Num() > 0)
    {
      Index = ObjAvailableList.Pop();
      const int32 AvailableCount = ObjAvailableList.Num();
      checkSlow(AvailableCount >= 0);
    }
    else // 如果空间不足，就扩容
    {
      Index = ObjObjects.AddSingle();      
    }
    // 这个 check 信息量很大
    // 可以得到 ObjFirstGCIndex > ObjLastNonGCIndex 总是成立的
    // 这意味着 ObjectArray 划分为两部分，前面为 NonGC，后面为 NeedGC
    // 同时 NonGC 会优先于 NeedGC 创建
    // GC 过程不会访问 NonGC Object，它们也不能有指向 NeedGC 的引用
    // 这样可以加快 GC 速度，因为只需遍历较少 Object。
    check(Index >= ObjFirstGCIndex && Index > ObjLastNonGCIndex);
  }
  FUObjectItem* ObjectItem = IndexToObject(Index);
  // 根据 Index 获取 ObjectArray 中的 Item，进行一些初始化工作
  ...
  UnlockInternalArray();

  // 最后挨个通知订阅了 ObjectCreated 事件的 Listener
  ...
}
```

#### HashObject()

这个函数是利用 FName 的唯一性，求出 FName 的哈希值 Hash 后，建立 Hash 到 Object 的映射，从而实现根据名字访问对象。

```cpp
void HashObject(UObjectBase* Object)
{
  FName Name = Object->GetFName();
  if (Name != NAME_None)
  {
    ...
    int32 Hash = 0;

    FUObjectHashTables& ThreadHash = FUObjectHashTables::Get();
    FHashTableLock HashLock(ThreadHash);

    // 因为一个 FName 唯一确定一个 Object
    // 所以可以直接用 FName 进行 Hash
    Hash = GetObjectHash(Name);
    ...
    ThreadHash.AddToHash(Hash, Object);
    if (PTRINT Outer = (PTRINT)Object->GetOuter())
    {
      // 这次 Hash 会加入 Outer 的信息
      Hash = GetObjectOuterHash(Name, Outer);
      ...
      ThreadHash.HashOuter.Add(Hash, Object->GetUniqueID());
      // ObjectOuterMap(Outer).Add(Object)
      AddToOuterMap(ThreadHash, Object);
    }
    // ClassToObjectListMap(Object.Class).Add(Object)
    AddToClassMap( ThreadHash, Object );
  }
}
```

#### FreeUObjectIndex()

该函数和 `AllocateUObjectIndex()` 对应，但是只在析构函数中调用，作用是回收 `GUObjectArray` 中的 item。

```cpp UObjectArray.cpp
void FUObjectArray::FreeUObjectIndex(UObjectBase* Object)
{
  ...
	// This should only be happening on the game thread (GC runs only on game thread when it's freeing objects)
	check(IsInGameThread() || IsInGarbageCollectorThread());

	// No need to call LockInternalArray(); here as it should already be locked by GC
	int32 Index = Object->InternalIndex;
	FUObjectItem* ObjectItem = IndexToObject(Index);
  // 将 ObjectItem 重置回默认值
	...
	if (Index > ObjLastNonGCIndex && !GExitPurge && bShouldRecycleObjectIndices)
	{
		ObjAvailableList.Add(Index);
	}
}
```

### UObject 的创建

因为 UObject 将其所有构造函数都设为了 private，所以我们只能通过以下两种方式构造一个 UObject：

- `NewObject<ObjectClass>()`
- `CreateDefaultSubobject<ObjectClass>()`

实际上内部都是将参数统一打包成一个 `FStaticConstructObjectParameters` 结构体，传入并调用 `StaticConstructObject_Internal()` 函数。

```cpp 
UObject* StaticConstructObject_Internal(const FStaticConstructObjectParameters& Params)
{
	...
	UObject* Result = NULL;
	// Subobjects are always created in the constructor,
  //   no need to re-create them unless their archetype != CDO
  //   or they're blueprint generated.
	// If the existing subobject is to be re-used
  //   it can't have BeginDestroy called on it
  //   so we need to pass this information to StaticAllocateObject.	
	const bool bIsNativeClass = InClass->HasAnyClassFlags(CLASS_Native | CLASS_Intrinsic);
	const bool bIsNativeFromCDO = bIsNativeClass &&
		  (
			!InTemplate ||
			(InName != NAME_None && (Params.bAssumeTemplateIsArchetype || InTemplate == UObject::GetArchetypeFromRequiredInfo(InClass, InOuter, InName, InFlags)))
			);
	const bool bCanRecycleSubobjects = bIsNativeFromCDO && (!(InFlags & RF_DefaultSubObject) || !FUObjectThreadContext::Get().IsInConstructor);

	bool bRecycledSubobject = false;	
	Result = StaticAllocateObject(InClass, InOuter, InName, InFlags, Params.InternalSetFlags, bCanRecycleSubobjects, &bRecycledSubobject, Params.ExternalPackage);

	// Don't call the constructor on recycled subobjects, they haven't been destroyed.
	if (!bRecycledSubobject)
	{
    ...
		(*InClass->ClassConstructor)(FObjectInitializer(Result, Params));
	}
  ...
	return Result;
}
```

这里的逻辑相对来说比较复杂。首先看最开始的三个 `const bool`。

首先看第一个 `bIsNativeClass`，其内容比较好理解，就是判断当前的类是不是 `CLASS_Native`/`CLASS_Intrinsic` 二者之一。前者代表这个类是在 C++ 而不是蓝图中定义的，而后者则表示该类是由 C++ 直接声明，未经过 UHT 生成反射代码，一般是引擎内部的类才会用到。

第二个 `bIsNativeFromCDO` 指的是是否根据**类默认对象(Class Default Object, CDO)**创建。

第三个 `bCanRecycleSubobjects` 指的是是否可以重复利用**子对象(Subobject)**。其中 `RF_DefaultSubObject` 标签只会在 CreateDefaultSubobject 时被赋予。也就是说如果一个对象不是通过 CDO 创建，且不是一个创建中的 Subobject，那么就可以对原来的 Subobject 进行重复利用。

至于为什么有「重复利用」一说，还得接着看后续的 `StaticAllocateObject()` 函数做了什么。

#### StaticAllocateObject()

这个函数实际做的工作是创建一个 Object 实例或者替换一个已经存在的 Class/Outer/Name 都一样的 Object。执行替换操作时，原 Object 将会被销毁，新 Object 将会占用其内存空间。

```cpp
UObject* StaticAllocateObject(...)
{
	...
	UObject* Obj = NULL;
	if(InName == NAME_None)
	{ // 如果创建时没有设置 Name，则生成一个独一无二的 Name
    ...
		InName = MakeUniqueObjectName(InOuter, InClass);
	}
	else
	{
		// 查找是否存在 Outer Name 一样的 Object
		Obj = StaticFindObjectFastInternal( /*Class=*/ NULL, InOuter, InName, true );
		// 类型必须一致，否则 fatal
		if (Obj && !Obj->GetClass()->IsChildOf(InClass)) { ... }
	}

	...
	if( Obj == nullptr )
	{	// 如果不存在上述 Object，就调用 AllocateUObject() 进行内存分配
		...
		Obj = (UObject *)GUObjectAllocator.AllocateUObject(...);
	}
	else
	{ // 否则，直接替换	
		if (!bCreatingCDO && (!bCanRecycleSubobjects || !Obj->IsDefaultSubobject()))
		{ // 如果不是 CDO ，或者是蓝图类，那就要进行 Destory
			if(!Obj->HasAnyFlags(RF_FinishDestroyed))
			{
				// 如果没完成 Destroy，则销毁原来的 Object
				Obj->ConditionalBeginDestroy();
				...
				Obj->ConditionalFinishDestroy();
			}
			...
			Obj->~UObject();
			...
		}
		else
		{
			bSubObject = true;
		}
	}
  ...
	if (!bSubObject)
	{ // 在此之前已经在这块内存上调用过析构函数，故需要重新格式化一下
    // 并用 placement new 构造一个 Object
		FMemory::Memzero((void *)Obj, TotalSize);
		new ((void *)Obj) UObjectBase(...);
	}
	else
	{ // 反之，只需要修改原 Object 的一些变量即可，也就是进行了重用
		Obj->SetFlags(InFlags);
		Obj->SetInternalFlags(InternalSetFlags);
	}
  ...
	return Obj;
}
```

在 placement new 的过程中，就会执行 `UObject` 的构造函数，进而执行一些和 `GUObjectArray` 的交互行为。随着 `return Obj;` 的执行，至此，一个新的 UObject 就被创建好了。

### UObject 的销毁

#### 自动销毁

可以将指向 UObject 的指针置空，这样后续就会被 UE 自动回收掉

```cpp 自动销毁
Obj = NewObject<UObject>(this, TEXT("Obj"));
Obj = nullptr;
```

#### 主动销毁

UObject::ConditionalBeginDestroy()

异步执行且对象在当前帧内持续有效
等待下次GC
Obj->ConditionalBeginDestroy();
Obj = nullptr;
MarkPendingKill()

标记为PendingKill，等待回收。指向此实例的指针将设置为NULL，并在下一次GC时删除。
IsPendingKill 判断是否处于 PendingKill 状态
ClearPendingKill 清除 PendingKill 状态
Obj->MarkPendingKill();
Obj = nullptr;
Engine\Config \BaseEngine.ini 更改下面参数，设置销毁时间间隔

gc.TimeBetweenPurgingPendingKillObjects=60
强制垃圾回收
UWorld::ForceGarbageCollection 弃用

GEngine->ForceGarbageCollection

GEngine->ForceGarbageCollection(true);

## UClass

