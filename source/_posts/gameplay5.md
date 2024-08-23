---
title: Gameplay Study(5)：Gameplay Ability System(GAS)
author: Leager
mathjax: true
date: 2024-08-23 12:00:00
summary:
categories:
  - unreal
tags:
  - unreal
  - gameplay
img:
---

接下来是重头戏，要基于**虚幻技能系统(Gameplay Ability System, GAS)**设计角色技能玩法了。

<!-- more -->

## 技能系统 GAS

> Gameplay 技能系统 是一个高度灵活的框架，可用于构建你可能会在 RPG 或 MOBA 游戏中看到的技能和属性类型。你可以构建可供游戏中的角色使用的动作或被动技能，使这些动作导致各种属性累积或损耗的状态效果，实现约束这些动作使用的"冷却"计时器或资源消耗，更改技能等级及每个技能等级的技能效果，激活粒子或音效，等等。简单来说，此系统可帮助你在任何现代 RPG 或 MOBA 游戏中设计、实现及高效关联各种游戏中的技能，既包括跳跃等简单技能，也包括你喜欢的角色的复杂技能集。—— 虚幻官方文档

技能系统主要有以下几个主要核心部件

- **技能系统组件(Ability System Component, ASC)**: 是 Actor 和**游戏玩法系统(Gameplay Ability System)**之间的桥梁，负责处理许多事务包括授予技能、激活技能等。
- **属性集(Attribute Set, AS)**: 存储角色的游戏属性（生命值、攻击力等），管理游戏属性与系统其他部分之间的交互，并将自己注册到角色的技能系统组件中。
- **技能(Gameplay Ability)**: 对「技能」的封装，定义技能效果、技能消耗，以及释放条件等。并异步运行角色动画、粒子和声效等。
- **技能任务(Ability Task)**: 异步执行技能相关的工作（播放施法动画、激发投射物粒子效果等），可以通过调用 `EndTask()` 函数自行终止。
- **效果(Gameplay Effect)**: 执行与属性相关的多种功能，这些效果可以是即时效果，比如施加伤害，也可以是持续效果，比如毒杀，在一定的时间内对角色造成伤害。
- **提示(Gameplay Cue)**: 负责处理音效、粒子效果等。
- **标签(Gameplay Tag)**: 使用层次结构，执行 Identify 的功能，同时比 bool、enum、string 更加灵活。

> 具体可以参考 [GAS Documentation](https://github.com/tranek/GASDocumentation)

## Ability System Component

ASC 和 AS 需要附加到 Actor 上才能被访问并发挥出效果，并且该 Actor 称之为 `OwnerActor`。

通常有两种 attach 方案：

1. 第一种是 attach 到一个叫「PlayerState」的类里。这个类是持久化的，Game Mode 会在玩家加入游戏时或游戏开始时，为每个玩家创建一个新的 Player State 对象，并在需要时将其分配给对应的玩家（事实上 Pawn 可以通过 `GetPlayerState()` 获取指向该类实例的指针）。即便 Pawn 死亡被销毁，该对象也依然存在，这也就意味着它和 Pawn 是**独立**的。所以如果需要用到这一特性，则可以考虑将 ASC/AS attach 到 Player State 上；
2. 当然，如果不需要用到相关特性，比如一旦 Pawn 死亡之后就不会再用到其技能/属性了，常见的有 Moba 游戏中的小兵，那就可以直接 attach 到 Character 上；

> Most Actors will have the ASC on themselves. If your Actor will respawn and need persistence of Attributes or GameplayEffects between spawns (like a hero in a MOBA), then the ideal location for the ASC is on the PlayerState.

除了 `OwnActor`，GAS 的实际使用者称之为 `AvatarActor`。这里我们选择第一种方案来 attach ASC 和 AS。

### Player State 与 Replication in multi-player

现在我们已经有了 Controller 类和 Character 类，那么接下来就是实现 PlayerState 类。步骤依然是创建 C++ 类 `RPlayerState` 与对应的蓝图类 `BP_RPlayerState`，并且在 Game Mode 中设置默认「玩家状态类」。我们可以在构造函数中为 `NetUpdateFrequency` 赋值，从而自定义 Play State 的复制速率。

```cpp Components/RPlayerState.cpp
ARPlayerState::ARPlayerState()
{
  NetUpdateFrequency = 100.0f; // 100 updates per second
}
```

什么是复制速率？事实上，在多人游戏中，在某一时刻，clients 可能会持有不同的数据版本，此时就需要有一个 Authority 来决定正确的数据版本。这个 Authority 可以是 server，也可以是 client 中的「房主」，它负责会持有所有 Pawn 的 Player State，并且单向复制到其它的 client 上，从而实现同步。那么如果复制速率太低，就容易出现不一致的情况；如果太高，则会影响性能。

> 每个 client 上只会有**一个**属于自己 Pawn 的 Controller，只有 server 有所有 Controller。
> 
> 但每个 client 会拥有所有的 Pawn 及其 Player State，毕竟我们需要知道其它玩家的生命值、等级这些信息。这些信息就是由 Authority 负责同步了。

### ASC 设置与初始化

> 首先要新建 ASC 和 AS 的 C++ 类。步骤略。

如果 ASC 是 attach 到 Player State 上的，那么它也会跟着一起复制，并且根据 Replication Mode 实现不同的复制效果。其中 Tag 和 Cue 永远会复制到其它 client 上，唯一区别在于 Effect 是否被复制。

|Replication Mode|描述                           |使用场景               |
|:---------------|:------------------------------|:---------------------|
|Full            |每个 Effect 都会复制到所有 client|单机                  |
|Mixed           |Effect 只会被复制到持有它的 Actor|多人游戏中玩家控制的角色|
|Minimal         |永不复制 Effect                 |多人游戏中 AI 控制的角色|

> ⚠️**注意**: Mixed 期望 OwnerActor 的 Owner 是 Controller。PlayerState 的 Owner 在默认情况下是 Controller，但 Character 不是。如果在 OwnerActor 不是 PlayerState 的时候使用 Mixed 模式，那么必须在 OwnerActor 上调用 `SetOwner()`（PlayerState 的 Owner 会自动设置为 Controller）。

对于本项目而言，敌怪就是 **AI-Controlled Pawn**，它会直接持有 ASC 和 AS。

```cpp Character/Enermy/REnermyBase.cpp
#include "Components/GAS/RGASComponent.h"
#include "Components/GAS/RGASAttributeSet.h"

AREnermyBase::AREnermyBase()
{
  ...
  GASComponent = CreateDefaultSubobject<URGASComponent>("GAS Comp");
  ensure(GASComponent);
  GASAttributeSet = CreateDefaultSubobject<URGASAttributeSet>("GAS Comp");
  ensure(GASAttributeSet);

  GASComponent->SetIsReplicated(true);
  GASComponent->SetReplicationMode(EGameplayEffectReplicationMode::Minimal);
}
```

并且在 `PossessedBy()` 函数中进行初始化就行。这个函数会在游戏为每个 Pawn 分配 Controller 时调用。

而对于 **Player-Controlled Pawn**，则是在 `RPlayerState` 中持有（创建组件的步骤略）。

但是初始化的时机略有不同。考虑到 Player State 会在运行时由上层分配给 Pawn，所以不仅需要在 `PossessedBy()` 函数中进行初始化，还需要在 Pawn 的 `OnRep_PlayerState()` 也进行初始化。这样一来就能得到实现思路了。

```cpp Character/RCharacterBase.cpp
#include "Components/RPlayerState.h"
#include "AbilitySystemComponent.h"

void ARCharacterBase::PossessedBy(AController* NewController)
{
  Super::PossessedBy(NewController);

  if (GASComponent)
  {
    GASComponent->InitAbilityActorInfo(this, this);
  } 
  else
  {
    InitAbilityActorInfo();
  }
}

void ARCharacterBase::OnRep_PlayerState()
{
  Super::OnRep_PlayerState();

  InitAbilityActorInfo();
}

void ARCharacterBase::InitAbilityActorInfo()
{
  if (ARPlayerState* PS = GetPlayerState<ARPlayerState>())
  {
    if (UAbilitySystemComponent* ASC = PS->GetAbilitySystemComponent())
    {
      ASC->InitAbilityActorInfo(PS, this);
    }
  }
}
```

## Attribute Set

### Attribute

我们熟知的属性（生命值、等级）都是由一个叫 `FGameplayAttributeData` 的结构体表示的。这个结构体包含两个浮点数，`BaseValue` 和 `CurrentValue`，前者是属性的永久值，后者是在前者的基础上，由 Effect 修改得到的临时值，在 Effect 过期时变回 `BaseValue`。

> 但是并不能这么用——Base Value 表示最大生命值，Current Value 表示当前生命值。
> 
> 比如英雄联盟里蒙多的 R 技能是一段时间内获得最大生命值，持续时间过后复原，这就要用到两个浮点数来维护了「最大生命值」这个属性了。所以应该用两个 `FGameplayAttributeData` 分别对应当前生命值和最大生命值。

### 在 Attribute Set 中设置 Attribute

AS 负责所有 Attribute 的管理，一个 ASC 可以有多个 AS，但是**同一类**的 AS 只能有一个。因为 AS 的内存开销并不大（两倍于属性个数的浮点数），可以选择让游戏中的每个角色共享一个大的单一的 AS，如果用不到某些属性，直接忽略即可。

> 在 OwnerActor 的构造函数中创建 AS 会自动将其注册到其 ASC 中。

为了在 AS 中设置 Attribute，需要使用 `UPROPERTY(ReplicatedUsing = FunctionName**)` 修饰，这指定了一个 callback，该函数在属性通过网络更新时执行，同时要在当前类实现该 callback。比如当前生命值属性：

```cpp Components/GAS/RGASAttributeSet.h
UCLASS()
class ACTIONRPG_API URGASAttributeSet : public UAttributeSet
{
	GENERATED_BODY()

public:
	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_CurHealth)
  FGameplayAttributeData CurHealth;

  UFUNCTION()
  void OnRep_CurHealth(const FGameplayAttributeData& OldCurHealth) const;
};
```

同时为了将相关的 CRUD 接口暴露给外部，可以添加下面这个宏到头文件最前面

```cpp Components/GAS/RGASAttributeSet.h
#include "AbilitySystemComponent.h" // 必须加上
#define ATTRIBUTE_ACCESSORS(ClassName, PropertyName) \
	      GAMEPLAYATTRIBUTE_PROPERTY_GETTER(ClassName, PropertyName) \
	      GAMEPLAYATTRIBUTE_VALUE_GETTER(PropertyName) \
	      GAMEPLAYATTRIBUTE_VALUE_SETTER(PropertyName) \
	      GAMEPLAYATTRIBUTE_VALUE_INITTER(PropertyName)
```

并且加上类似于 `ATTRIBUTE_ACCESSORS(URGASAttributeSet, CurHealth)` 这样的语句。之后，需要用 `GAMEPLAYATTRIBUTE_REPNOTIFY` 宏填充 `On_Rep*` 函数，如下所示：

```cpp Components/GAS/RGASAttributeSet.cpp
void URGASAttributeSet::OnRep_CurHealth(const FGameplayAttributeData& OldCurHealth) const
{
  GAMEPLAYATTRIBUTE_REPNOTIFY(URGASAttributeSet, CurHealth, OldCurHealth);
}
```

This is a helper macro that can be used in RepNotify functions to handle attributes that will be predictively modified by clients. 这句话是源码中对宏的 comment，意思是加上这个宏就可以处理将被客户端预测修改的属性。

> 所谓「预测」，指的就是 client 在被一个 Effect 影响时，可以把对相关值的修改放在「将修改请求发到 server 等其**认可**并同步」之前。而如果 server 认为该修改**不合理**（不认可），则会将 client 的修改 rollback。
> 
> 预测机制使得多人游戏更加流畅。因为很少会出现「不合理」的修改请求，所以这种**乐观**的策略能大大减少对属性值修改的时延——如果没有预测机制，则需要等到下次 server 进行同步时才会对属性值进行修改。

当 Attribute 被复制时的行为已经做好了，接下来还要指定一个 Attribute 如何被复制，这是在函数 `GetLifetimeReplicatedProps()` 中实现的。该函数负责复制我们使用 Replicated 说明符指派的任何属性，并可用于配置属性的复制方式。

```cpp Components/GAS/RGASAttributeSet.cpp
void URGASAttributeSet::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
  Super::GetLifetimeReplicatedProps(OutLifetimeProps); // 这一行必不可少

  DOREPLIFETIME_CONDITION_NOTIFY(URGASAttributeSet, CurHealth, COND_None, REPNOTIFY_Always);
}
```

其中 `DOREPLIFETIME_CONDITION_NOTIFY` 宏的前两个参数很容易理解，分别是类名和类中的属性名，关键在于后两个参数。

第三个参数指明了 server 进行复制的条件。`COND_NONE` 是默认值，即无条件复制。

第四个参数指明了 client 触发 OnRep 的条件。`REPNOTIFY_Always` 是一个枚举值，表明无论什么情况都会触发 OnRep，而默认是仅当 server 下发的值和 client 不同时才触发 OnRep，如果相同（意味着进行了正确的预测）则不会触发。

> `DOREPLIFETIME*` 宏实际上会调用 `DOREPLIFETIME_WITH_PARAMS` 宏，并传入一个 `FDoRepLifetimeParams` 类型的额外参数，最后调用的是 `RegisterReplicatedLifetimeProperty()` 函数，根据函数名也可以知道，是进行了**需要复制**的变量的**注册**行为。

之后可以通过命令行 `showdebug abilitysystem` 来进行 GAS 的调试。

## Effect