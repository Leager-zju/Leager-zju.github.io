---
title: Gameplay Study(6)：UI
author: Leager
mathjax:
  - false
date: 2024-08-24 12:00:00
summary:
categories:
  - unreal
tags:
img:
---

既然有了属性，我们就要一些 UI 控件来对关心的属性进行可视化。

<!-- more -->

在 Game Mode 的默认类中会发现一个叫 HUD 的类。所谓 **HUD(Heads-Up Display)**，指的就是在游戏或应用程序中以某种方式显示信息给玩家或用户的技术和概念。而在 UE 中，HUD 可以包括诸如玩家的健康状态、武器信息、地图、任务目标等重要信息。这些信息通常以图形、文本或图标的形式显示在屏幕上，使玩家能够实时了解游戏中的关键信息，并且会在游戏开始时被创建，可被 Player Controller 访问。

## 创建类

这样一来，就可以令 HUD 管理所有 UI 控件了。首先需要创建一个 HUD 类 `RHUD`，接着是一个派生自 `UserWidget` 的用于显示生命值和魔法值的 UI 控件 `RStatusBarWidget`。

### HUD

`RHUD` 类做的事很简单，定义控件成员，在构造时将控件输出到屏幕上，并且提供一个访问控件的接口（用于其它类在 Attribute 变化时更新）。

```cpp UI/RHUD.h
class URStatusBarWidget;

UCLASS()
class ACTIONRPG_API ARHUD : public AHUD
{
  GENERATED_BODY()

public:
  URStatusBarWidget* GetStatusBar() { return StatusBar; }
	
protected:
  virtual void BeginPlay() override;

private:
  UPROPERTY(VisibleAnywhere)
  TObjectPtr<URStatusBarWidget> StatusBar;

  // 因为需要在蓝图中绘制控件，所以会生成一个控件蓝图类。就必须用一个蓝图中可编辑的变量来表示这个蓝图类。
  UPROPERTY(EditDefaultsOnly)
  TSubclassOf<URStatusBarWidget> StatusBarClass;
};
```

```cpp UI/RHUD.cpp
#include "UI/RHUD.h"
#include "UI/Widget/RStatusBarWidget.h"

void ARHUD::BeginPlay()
{
  Super::BeginPlay();

  StatusBar = CreateWidget<URStatusBarWidget>(GetWorld(), StatusBarClass);
  StatusBar->AddToViewport();
}
```

### Status Bar Widget

一个控件中可能有许多子控件，比如图像、按钮、进度条等等。最开始我们可以简单地只关注「进度条」这一个控件，而无需在意它用的是什么贴图和什么颜色。当人物 Attribute 发生变化时，可以通过设置进度条的百分比来达到效果。而真正显示的是派生出的蓝图类。为了让蓝图类知道在自己这里绘制的某个控件是继承自基类的，需要在基类中用 `UPROPERTY(meta=(BindWidget))` 修饰，并且蓝图类中创建的控件名必须和基类一致，这就实现了**绑定**。当执行 C++ 中设置进度条百分比的逻辑时，用于显示的蓝图类也会应用一样的修改。

```cpp UI/Widget/RStatusBarWidget.h
class UProgressBar;

UCLASS()
class ACTIONRPG_API URStatusBarWidget : public UUserWidget
{
  GENERATED_BODY()
	
public:
  // 暴露给 HUD 的接口
  void SetHealthBarPercentage(float Percentage);

private:
  UPROPERTY(meta = (BindWidget))
  TObjectPtr<UProgressBar> HealthBar;
};
```

```cpp UI/Widget/RStatusBarWidget.cpp
#include "UI/Widget/RStatusBarWidget.h"
#include "Components/ProgressBar.h"

void URStatusBarWidget::SetHealthBarPercentage(float Percentage)
{
  HealthBar->SetPercent(Percentage);
}
```

### 何时设置进度条百分比？

之前我们已经进行了 Attribute 变化事件的 callback 绑定，对应的函数是 `RPlayerState::OnCurHealthChanged`。所以也就是在这个函数中，Player State 获取当前角色使用的 HUD。

```cpp Components/RPlayerState.cpp
void ARPlayerState::BeginPlay()
{
  ...
  if (ARPlayerController* PC = Cast<ARPlayerController>(GetOwner()))
  {
    HUD = Cast<ARHUD>(PC->GetHUD());
  }
}

void ARPlayerState::OnCurHealthChanged(const FOnAttributeChangeData& Data)
{
  if (URStatusBarWidget* StatusBar = HUD->GetStatusBar())
  {
    StatusBar->SetHealthBarPercentage(Data.NewValue / GetMaxHealth());
  }
}
```

这里简单地认为 Owner 保持不变。如果应用场景中会发生变化，则可以将 HUD 的获取推迟到 `On..Changed()` 中来。


## 结果

绘制过程就略过了，总之用的是课程的素材。结果如下

<img src="hudres.png">