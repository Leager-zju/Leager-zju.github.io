---
title: Gameplay Study(5)：Gameplay Ability System(GAS)
author: Leager
mathjax:
  - false
date: 2024-08-23 12:00:00
summary:
categories:
  - unreal
tags:
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

| Replication Mode | 描述                              | 使用场景                 |
| :--------------- | :-------------------------------- | :----------------------- |
| Full             | 每个 Effect 都会复制到所有 client | 单机                     |
| Mixed            | Effect 只会被复制到持有它的 Actor | 多人游戏中玩家控制的角色 |
| Minimal          | 永不复制 Effect                   | 多人游戏中 AI 控制的角色 |

> ⚠️**注意**: Mixed 期望 OwnerActor 的 Owner 是 Controller。PlayerState 的 Owner 在默认情况下是 Controller，但 Character 不是。如果在 OwnerActor 不是 PlayerState 的时候使用 Mixed 模式，那么必须在 OwnerActor 上调用 `SetOwner()`（PlayerState 的 Owner 会自动设置为 Controller）。

对于本项目而言，敌怪就是 **AI-Controlled Pawn**，它会直接持有 ASC 和 AS。

```cpp Character/Enermy/REnermyBase.cpp
#include "Components/GAS/RGASComponent.h"
#include "Components/GAS/RGASAttributeSet.h"

AREnermyBase::AREnermyBase()
{
  ...
  AbilitySystemComponent = CreateDefaultSubobject<URGASComponent>("GAS Comp");
  ensure(AbilitySystemComponent);
  AttributeSet = CreateDefaultSubobject<URGASAttributeSet>("GAS Attribute Set");
  ensure(AttributeSet);

  AbilitySystemComponent->SetIsReplicated(true);
  AbilitySystemComponent->SetReplicationMode(EGameplayEffectReplicationMode::Mixed);
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

/**
也可以用宏

#define SETUP_ONREP_FUNCTION_DECLARATION(ClassName, Attr)\
		  void ClassName::OnRep_##Attr(const FGameplayAttributeData& Old##Attr) const\
		  {\
			GAMEPLAYATTRIBUTE_REPNOTIFY(ClassName, Attr, Old##Attr);\
		  }
*/
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
cod
第四个参数指明了 client 触发 OnRep 的条件。`REPNOTIFY_Always` 是一个枚举值，表明无论什么情况都会触发 OnRep，而默认是仅当 server 下发的值和 client 不同时才触发 OnRep，如果相同（意味着进行了正确的预测）则不会触发。

> `DOREPLIFETIME*` 宏实际上会调用 `DOREPLIFETIME_WITH_PARAMS` 宏，并传入一个 `FDoRepLifetimeParams` 类型的额外参数，最后调用的是 `RegisterReplicatedLifetimeProperty()` 函数，根据函数名也可以知道，是进行了**需要复制**的变量的**注册**行为。

之后可以通过命令行 `showdebug abilitysystem` 来进行 GAS 的调试。

### 订阅 Attribute 变化

以玩家为例，ASC 和 AS 均放在 Player State 中，那么就由 Player State 管理 Attribute 发生变化时的行为，这在语义上也是说得通的。具体要怎么做呢？答案是用 ASC 的一个叫 `GetGameplayAttributeValueChangeDelegate()` 的函数。这个函数会获取一个**委托(Delegate)**变量。所谓委托就是允许其它类在其上订阅它们感兴趣的事件，一旦某事件 SomeEvent 发生，委托就会通过广播的行为，告知那些关注 SomeEvent 的类，这通常是以在委托类中绑定 callback 实现的。用法如下：

```cpp Character/RCharacterBase.cpp
void ARPlayerState::BeginPlay()
{
  Super::BeginPlay();

  if (AbilitySystemComponent && AttributeSet)
  {
    // 就是下面这一行，返回的 Handle 可以设为成员变量。
    // AddUObject 就是在绑定 callback
    // 一旦 CurHealth 发生变化，就会调用 OnCurHealthChanged()
    OnCurHealthChangedDelegateHandle = AbilitySystemComponent->GetGameplayAttributeValueChangeDelegate(AttributeSet->GetCurHealthAttribute()).AddUObject(this, &ARPlayerState::OnCurHealthChanged);
  }
}
```

> 课程中的实现太繁琐，我直接参考了 GAS Documentation 来做的。



## Gameplay Effect

**Gameplay Effect(GE)** 是 Ability 修改其自身和其他 Attribute 和 GameplayTag 的容器，其可以立即修改 Attribute（比如伤害或治疗）或应用长期的状态 buff/debuff（如加速或眩晕）。`UGameplayEffect` 只是一个定义单一游戏效果的数据类，不应该在其中添加额外的逻辑。通常会创建 `UGameplayEffect` 的派生蓝图类而非 C++ 类。

### 持续时间

Effect 可分为三种，**即刻(Instant)**、**有持续时间(Has Duration)**和**无限(Infinite)**。其中 Instant 修改的是 BaseValue，通常用于伤害或治疗效果；其余两个修改的是 CurrentValue，通常用于 buff/debuff 之类的效果。

一旦将 Effect 设置为 Has Duration 或 Infinite，就可以进而为其设置**生效周期(Period)**，并且可以指定「对应用执行周期影响」，表示是否在应用时立即生效。

### 修饰符(Modifier)

修饰符指明了**目标属性**、**操作类型**、**修改幅度**，以及 Gameplay Tags 的过滤。

#### 操作类型

- 「加」「乘」「除」: 这仨都是字面意思，多个对同一属性的操作，会通过聚合公式对属性的 CurrentValue 进行修改，结果为  `CurrentValue = (BaseValue + Add) * Mutiply / Divide`，其中 `Add` 为所有设置为「加」的 Modifier 的幅度；
- 「重载」: 用当前值覆盖最后一个应用的修饰符的结果；
- 「无效」: 

#### 修改幅度

- 「可扩展浮点」: 硬编码一个固定值；
- 「属性基础」: 最简单来说就是允许根据 Attribute 代入某个公式进行计算求出最终结果；
  - **支持属性**中可以指定基于 Source 还是 Target，也可以指定 Attribute，若设置为**快照**，则会捕获 Effect **创建**时刻的数据，否则捕获**施加**时刻的数据；
  - **属性计算幅度**可以指定 `Value` 取 `BaseValue` 还是 `CurrentValue`，还是 `CurrentValue - BaseValue`；

    > 可以分别用于对应**最大生命值**、**当前生命值**、**已损失生命值**。 

  - 最后按照 `(Value + PreMultiplyAdditiveValue) * Coeffcient + PostMultiplyAdditiveValue` 得出最终修改值；

#### 曲线表

曲线表就是用于实现不同等级的 Effect 能施加不同程度的 Modify，并且会在「修改幅度」的基础上再乘上曲线上当前 Level 的值。

#### 标签过滤

根据 Source 和 Target 的标签情况，决定 Modifier 是否生效。比如可以实现类似「目标中毒时，降低 50% 防御力」的效果。

### 堆叠(Stack)

在英雄联盟这个游戏里，有很多技能/物品在使用后会获得一个「状态」。

部分技能连续使用时或许还会叠加「状态」层数，有些可以无限叠加，如邪恶小法师的 Q 技能「黑暗祭祀」；有些有叠加上限，并且一旦持续时间消失会逐渐降低层数，如战争之影的 Q 技能「暴走」；有些一旦持续时间结束会失去所有层数，如诺克萨斯之手的被动技能「出血」；而有些并不能叠加层数，也就是最高只有一层……在 Gameplay Effect 里面，我们可以用「堆叠」功能实现同样的效果。这一功能通常搭配 `Has Duration` 的 Effect 使用。

#### 堆叠样式(Stacking Type)

默认是「无」，即可以无限叠加，施加的每个 GameplayEffectSpec 都视为相互**独立**；

还有两种是「按源聚合」与「按目标聚合」，将样式设置为这两种才能开启完整功能，并可以设置「堆栈限制次数」。前者是每个 Source 最多施加 n 个 Effect，后者是每个 Target 最多**被**施加 n 个 Effect。

#### 堆栈持续时间刷新策略(Stacking Duration Refresh Policy)

- 「成功应用时刷新」: 当有新的 Effect 成功入栈时，栈中其它 Effect 会刷新自身的持续时间；
- 「永不刷新」: 不会刷新持续时间；

#### 堆栈周期重设策略(Stacking Period Refresh Policy)

- 「成功应用后重设」: 当有新的 Effect 成功入栈时，栈中其它 Effect 会更新自身的周期时间，即如果设置了周期，则会将下次触发的时间修改为 `now + period`；
- 「永不刷新」: 不会更新周期时间；

#### 堆栈过期策略(Stack Expiration Policy)

每当栈内的某个 Effect 持续时间到了，就会应用该策略。

- 「清除整个堆栈」: 字面意思；
- 「移除单一堆栈并刷新持续时长」: 将过期的移除，剩下的 Effect 刷新自身的持续时间；
- 「刷新时长」: 用这个能实现 Infinite，并且可以通过 `OnStackCountChange()` 手动实现栈计数减少的行为；


### 施加 Effect

#### 生命恢复药水

>「药水」本质上是一个放置在世界中的 Actor，自带碰撞范围，当角色 Overlap 时为其施加「立即恢复生命」的效果。

首先可以创建一个 Actor 类 `REffectActor`，表示所有能够为具有 ASC 的角色施加 GameplayEffect 的物体的基类。这一基类实现了一个公有的方法 `ApplyEffectToTarget()`，语义为对目标施加 Effect。

很多时候一个 Actor 可以施加多种效果，比如造成伤害（Instant）后施加一个持续若干秒的 debuff（Duration），所以就需要在类中定义一个 `TArray<>`，用于存放该 Actor 能够施加的所有 Effect 的类型。

```cpp Actor/EffectActor.cpp
bool AREffectActor::ApplyEffectToTarget(AActor* TargetActor, FEffectInfo& EffectInfo, bool bMayCancelLater)
{
  UAbilitySystemComponent* ASCOfTarget = UAbilitySystemBlueprintLibrary::GetAbilitySystemComponent(TargetActor);
  if (!IsValid(ASCOfTarget) || !EffectInfo.GameplayEffectClass)
  {
    return false;
  }

  float EffectLevel = EffectInfo.EffectLevel;
  TSubclassOf<UGameplayEffect> GameplayEffectClass = EffectInfo.GameplayEffectClass;

  // 创建一个 Effect Context，用于后续生成 Effect
  FGameplayEffectContextHandle EffectContextHandle = ASCOfTarget->MakeEffectContext();
  // 设置 Effect 的施加者 Source，保存在 Effect Context 中
  EffectContextHandle.AddSourceObject(this);
  
  // 根据 Effect class 和 Effect Context 生成一个 EffectSpec
  const FGameplayEffectSpecHandle EffectSpecHandle = ASCOfTarget->MakeOutgoingSpec(GameplayEffectClass, EffectLevel, EffectContextHandle);

  // 施加到 Target 的 ASC 上，并返回一个 Active Gameplay Effect Handle
  const FActiveGameplayEffectHandle ActiveEffectHandle = ASCOfTarget->ApplyGameplayEffectSpecToSelf(*(EffectSpecHandle.Data));

  return true;
}
```

然后在编辑器中创建一个派生蓝图类 `BP_HealthPotion`，设置 Static Mesh 和 Sphere Collision 以后，在蓝图中实现碰撞球体的 `BeginOverlap` 和 `EndOverlap` 方法。

此时还需要填充 `EffectInfo` 成员。需要做的就是创建一个派生自 `UGameplayEffect` 的蓝图类，命名为 `GE_HealthPotion`，进行相关设置，如「Instant」「加」「RAttributeSet.CurHealth」「某个值」。创建完毕后即可进行类型的填充。这样就实现了一个简单的药水效果。

基于上面这种创建流程，还可以设计「持续恢复生命值的药水」「一旦进入其中就会持续扣血的燃烧区域」等等。

#### Pre/Post 函数

在施加 Effect 与实际修改 Attribute 前后，AS 分别会调用以下六个函数。

```cpp
/**
 * PreGameplayEffectExecute -> PreAttributeBaseChange -> PreAttributeChange -> (ATTRIBUTE BE CHANGED) ->
 * PostAttributeChange -> ON_ATTRIBUTE_CHANGED DELEGATE -> PostAttributeBaseChange -> PostGameplayEffectExecute
 */

/**
 * Called just before any modification happens to an attribute's base value which is modified by Instant Gameplay Effects.
 */
void PreAttributeBaseChange(const FGameplayAttribute& Attribute, float& NewValue) const override;

/**
 * Called just after any modification happens to an attribute's base value which is modified by Instant Gameplay Effects.
 */
void PostAttributeBaseChange(const FGameplayAttribute& Attribute, float OldValue, float NewValue) const override;

/**
 * Called just before any modification happens to an attribute's current value which is modified by Duration based Gameplay Effects.
 * 
 * This function is meant to enforce things like "Health = Clamp(Health, 0, MaxHealth)" and NOT things like "trigger this extra thing if damage is applied, etc".
 */
void PreAttributeChange(const FGameplayAttribute& Attribute, float& NewValue) override;

/**
 * Called just after any modification happens to an attribute.'s current value which is modified by Duration based Gameplay Effects.
 */
void PostAttributeChange(const FGameplayAttribute& Attribute, float OldValue, float NewValue) override;

/**
 * Called just before the Gameplay Effect is executed.
 * 
 * Return true to continue, or false to throw out the modification.
 */
bool PreGameplayEffectExecute(struct FGameplayEffectModCallbackData& Data) override;

/**
 * Called just after the Gameplay Effect is executed.
 * 
 * When PostGameplayEffectExecute() is called, changes to the Attribute have already happened,
 * but they have not replicated back to clients yet so clamping values here will not cause two network updates to clients.
 * Clients will only receive the update after clamping.
 */
void PostGameplayEffectExecute(const struct FGameplayEffectModCallbackData& Data) override;
```

其中主要关注 `PreAttributeChange()` 和 `PostGameplayEffectExecute()` 这两个。

前者用于对 `NewValue` 进行 Clamp 操作，后者主要获取 Effect 的 Source 实现相关逻辑（比如反伤等等）。

### 移除 Effect

为了移除施加到 ASC Of Target 上的 Effect，需要调用的函数是 `RemoveActiveGameplayEffect()`。该函数需要两个参数：一个 `FActiveGameplayEffectHandle` 和一个浮点数。

前者是通过调用 `ApplyGameplayEffectSpecToSelf()` 返回的，后者则表明了当移除该 Effect 时，要移除栈内多少个 Effect。默认为 `-1`，即全部移除。

所以为了正确调用，需要由一定数据结构保存施加 Effect 时返回的那个 `FActiveGameplayEffectHandle`。常用的是 `TMap<>`，存储 Active Handle 到 ASC 的映射。

### 监听 Effect 行为

```cpp AbilitySystemComponent.h
/** Delegate for when an effect is applied */
DECLARE_MULTICAST_DELEGATE_ThreeParams(
  FOnGameplayEffectAppliedDelegate,
  UAbilitySystemComponent*,
  const FGameplayEffectSpec&,
  FActiveGameplayEffectHandle
);

/**
 * Called on server whenever a GE is applied to self.
 * This includes instant and duration based GEs.
 */
FOnGameplayEffectAppliedDelegate OnGameplayEffectAppliedDelegateToSelf;

/**
 * Called on server whenever a GE is applied to someone else.
 * This includes instant and duration based GEs.
 */
FOnGameplayEffectAppliedDelegate OnGameplayEffectAppliedDelegateToTarget;

/**
 * Called on both client and server whenever a duration based GE is added
 * (E.g., instant GEs do not trigger this).
 */
FOnGameplayEffectAppliedDelegate OnActiveGameplayEffectAddedDelegateToSelf;

/**
 * Called on server whenever a periodic GE executes on self
 */
FOnGameplayEffectAppliedDelegate OnPeriodicGameplayEffectExecuteDelegateOnSelf;

/**
 * Called on server whenever a periodic GE executes on target
 */
FOnGameplayEffectAppliedDelegate OnPeriodicGameplayEffectExecuteDelegateOnTarget;
```

上面这些就是当 Effect 施加时可能进行广播的委托对象，在类 `UAbilitySystemComponent` 中定义。当我们要实现一些诸如「受到某些技能效果时触发某些事件」的功能，就需要用到这些了。

可以在 `RGASComponent` 类的 `BeginPlay()` 函数中执行 callback 的注册。

```cpp Components/GAS/RGASComponent.cpp
void URGASComponent::BeginPlay()
{
  Super::BeginPlay();

  OnGameplayEffectAppliedDelegateToSelf.AddUObject(this,
                                                   &URGASComponent::OnEffectApplied);
}

void URGASComponent::OnEffectApplied(UAbilitySystemComponent* AbilitySystemComponent,
                                     const FGameplayEffectSpec& EffectSpec,
                                     FActiveGameplayEffectHandle EffectHandle)
{
  ...
}
```

## Gameplay Tags

`FGameplayTag` 是由 `GameplayTagManager` 注册的形似 Parent.Child.Grandchild... 的层级 `FName`，这些标签对于分类和描述对象的状态非常有用（例如如果某个 Character 处于眩晕状态，我们可以授予其一个 State.Debuff.Stun 的 Tag）。用 GameplayTag 可以替换布尔值或枚举值，多个 GameplayTag 应被保存于一个 `FGameplayTagContainer` 中，相比 `TArray<FGameplayTag>` 做了一些很有效率的优化。可以更快地判断一个 Character 是否具有某 Tag，从而决定是否施加 Effect。

