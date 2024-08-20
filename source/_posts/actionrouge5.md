---
title: Action Rouge by Unreal Engine(5):属性组件与生命条
author: Leager
mathjax: true
date: 2024-08-19 12:00:00
summary:
categories:
  - unreal
tags:
  - unreal
  - gameplay
img:
---

现在需要为角色实现属性机制，以及生命条 UI，当属性中的生命值发生变化时，生命条的百分比填充也会相应变化。

<!-- more -->

## 属性组件

可以新建一个属性组件 `RAttributeComponent`，并作为战斗组件的成员变量。这个组件就负责属性值相关的逻辑了，比如生命值、经验值、等级这些。这里首先要实现的是生命值，由**当前生命值**(`CurHealth`)和**最大生命值**(`MaxHealth`)两者共同构成，以及一个 `ApplyHealthChange()` 的函数，用于修改当前生命值。

```cpp Components/RAttributeComponent.h
UCLASS( ClassGroup=(Custom), meta=(BlueprintSpawnableComponent) )
class ACTIONROUGE_API URAttributeComponent final : public UActorComponent
{
  GENERATED_BODY()

public:
  URAttributeComponent();

  bool ApplyHealthChange(AActor* Instigator, float Delta);

private:
  UPROPERTY(VisibleAnywhere)
  float CurHealth;

  UPROPERTY(EditDefaultsOnly)
  float MaxHealth;
};
```

```cpp Components/RAttributeComponent..cpp
bool URAttributeComponent::ApplyHealthChange(AActor* Instigator, float Delta)
{
  CurHealth = FMath::Clamp(CurHealth-Delta, 0.0f, MaxHealth);
  return CurHealth == 0.0f;
}
```

### 多播委托

为了将属性中的生命值变化实时反映到 UI 中，一种可能的方法是在 UI 类中逐帧轮询 `RAttributeComponent` 的值，然后更新自己的值。这种方法太消耗性能，因为如果在相当一段时间内角色生命值没有变化的话，这种查询方式是毫无必要的。不难想到可以仅在「生命值发生变化时」，利用某种机制通知 UI，令其更新。这种机制就是**委托**。

其实前面也接触过委托，比如按键事件、碰撞事件等，这是通过一个 `DECLARE_DYNAMIC_MULTICAST_DELEGATE` 宏实现的，它会定义一个委托类，并且实现**订阅**(`Add()`)、**通知**(`BroadCast()`)等功能。具体用法如下：

```cpp Components/RAttributeComponent.h
// 声明一个委托类 FOnHealthChanged，以及绑定在该类的通知函数参数列表
DECLARE_DYNAMIC_MULTICAST_DELEGATE_FourParams(FOnHealthChanged, AActor*, Instigator, float, CurHealth, float, MaxHealth, float, Delta);

UCLASS( ClassGroup=(Custom), meta=(BlueprintSpawnableComponent) )
class ACTIONROUGE_API URAttributeComponent final : public UActorComponent
{
  ...
public:
  UPROPERTY(BlueprintAssignable)
  FOnHealthChanged OnHealthChanged;
};
```

```cpp Components/RAttributeComponent.cpp
bool URAttributeComponent::ApplyHealthChange(AActor* Instigator, float Delta)
{
  ...
  // 对所有通过 Add 绑定在该变量上的函数，以声明的参数列表进行调用
  OnHealthChanged.Broadcast(Instigator, CurHealth, MaxHealth, Delta);
  ...
}
```

后续可以通过访问 `URAttributeComponent::OnHealthChanged.Add()` 函数订阅生命变化事件，从而在事件发生时得到通知。

## 实现生命条 UI

这里要接触到全新的知识了，那就是「用户控件」，这是一种用于创建用户界面的工具。它允许开发者通过蓝图或 C++ 代码设计和实现交互式界面，支持多种控件和布局，如按钮、文本框和图像等。

### 创建 UserWidget

首先添加一个派生自 UserWidget 的 C++ 类，命名为 `RCombatInterfaceWidget`，并放在 `UI` 文件夹下。之后战斗界面相关的 UI（生命条、经验条、技能栏之类）都在这个类中实现。

值得注意的是，在 C++ 中创建的 UserWidget 只实现逻辑，不进行实际的子控件布局，而是将布局交给派生蓝图类实现。所以只需要告诉蓝图类有哪些控件是需要强制实现的即可。这类控件需要使用 `UPROPERTY(meta = (BindWidget))` 修饰，并且蓝图类的控件命名要与 C++ 类中的**完全一致**。如下所示，要用一个 `UCanvas` 作为整个背景板，然后用 `UProgressBar` 作为生命条。

为了让它能够正确订阅属性组件的生命值变化事件，令其由战斗组件创建，并且添加 `BindAttributeComponent()` 函数。

```cpp UI/RCombatInterfaceWidget.h
class URAttributeComponent;
class UCanvasPanel;
class UProgressBar;

UCLASS()
class ACTIONROUGE_API URCombatInterfaceWidget : public UUserWidget
{
  GENERATED_BODY()

public:
  void BindAttributeComponent(URAttributeComponent*);

protected:
  UFUNCTION()
  void UpdateHealthBar(AActor* Instigator, float CurHealth, float MaxHealth, float Delta);

  UPROPERTY(EditAnywhere, meta = (BindWidget))
  UCanvasPanel* Canvas;

  UPROPERTY(EditAnywhere, meta = (BindWidget))
  UProgressBar* HealthBar;
};
```

### 订阅生命值变化事件

```cpp UI/RCombatInterfaceWidget.cpp
void URCombatInterfaceWidget::BindAttributeComponent(URAttributeComponent* AttributeComp)
{
  // ensure 用于在调试模式下验证条件。
  // 如果条件为假，它会记录错误并在调试器中中断程序。
  // 在发布模式下不会中断。这有助于捕捉潜在问题而不影响性能。
  if (ensure(AttributeComp))
  {
    FScriptDelegate Delegate;
    Delegate.BindUFunction(this, FName("UpdateHealthBar"));
    AttributeComp->OnHealthChanged.AddUnique(Delegate);
  }
}

void URCombatInterfaceWidget::UpdateHealthBar(AActor* Instigator, float CurHealth, float MaxHealth, float Delta)
{
  if (HealthBar)
  {
    HealthBar->SetPercent(CurHealth / MaxHealth);
  }
}
```

在战斗组件的 `BeginPlay()` 中，创建该控件，并调用 `BindAttributeComponent()` 进行订阅。

### 文本与控件动画

光有血条不够，我们希望能够显示玩家的当前生命值和最大生命值的具体数值，并且在生命值变化时，给文本块一个动态效果，比如一个简单的先放大再缩小，方便玩家视觉捕获。所以需要在 UI 中增加两个变量。

```cpp UI/RCombatInterfaceWidget.h
class UTextBlock;
class UWidgetAnimation;

UCLASS()
class ACTIONROUGE_API URCombatInterfaceWidget : public UUserWidget
{
  ...
protected:
  UPROPERTY(EditAnywhere, meta = (BindWidget))
  UTextBlock* HealthText;
  
  UPROPERTY(EditAnywhere, Transient, meta = (BindWidgetAnim))
  UWidgetAnimation* HealthTextAnim;
};
```

其中 `HealthTextAnim` 的属性说明符比较特殊。`Transient` 通常用于标记临时数据或者在运行时动态生成的数据，这些数据不需要被持久化保存，`meta = (BindWidgetAnim)` 表明该类绑定到「控件动画」而非控件。

```cpp UI/RCombatInterfaceWidget.cpp
void URCombatInterfaceWidget::UpdateHealthBar(AActor* Instigator, float CurHealth, float MaxHealth, float Delta)
{
  ...
  if (HealthText)
  {
    FText FractionText = FText::Format(FText::FromString(TEXT("{0}/{1}")),
                                       FText::AsNumber(CurHealth),
                                       FText::AsNumber(MaxHealth));
    HealthText->SetText(FractionText);
    if (HealthTextAnim)
    {
      PlayAnimation(HealthTextAnim, 0.f, 1, EUMGSequencePlayMode::Forward);
    }
  }
}
```

之后在通知函数中对文本块做处理，除了用 `SetText()` 配合 `FText::Format()` 修改文本内容以外，还用 `PlayAnimation()` 播放相应的动画。

最后就是去蓝图中创建动画了。在「动画」中选择「+动画」，命名与 C++ 中定义的一致，添加轨道，在所有已命名空间中选择 `HealthText`（而不是画布面板槽）。此时点击左侧 `HealthText`，在「细节」栏中发现许多值右边多了个菱形，是「添加此属性的一个关键帧」。这里在 0s 和 1s 处添加缩放 (1.0, 1.0) 的帧，在 0.5s 处添加缩放 (1.1, 1.1) 的帧，即可实现效果。

<img src="healthanim.png">