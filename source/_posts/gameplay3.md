---
title: Gameplay Study(3)：View Control
author: Leager
mathjax:
  - false
date: 2024-08-21 12:00:00
summary:
categories:
  - unreal
tags:
img:
---

前面实现移动后，发现我们的视野是有问题的，同时角色虽然能够进行平移，但身体永远面朝同一个方向。所以接下来要实现视角控制。

<!-- more -->

视角控制最关键的两个组件是**弹簧臂组件(Spring Arm Component)**与**相机组件(Camera Component)**。前者用于固定相机和角色的相对位置关系，后者则是用于将可视范围显示到屏幕上。在角色类中加入以下变量

```cpp Character/Player/RPlayerBase.h
class USpringArmComponent;
class UCameraComponent;

UCLASS(Abstract)
class ACTIONRPG_API ARPlayerBase : public ARCharacterBase
{
  ...
protected:
  UPROPERTY(EditDefaultsOnly, Category = "View")
  TObjectPtr<USpringArmComponent> CameraBoom;

  UPROPERTY(EditDefaultsOnly, Category = "View")
  TObjectPtr<UCameraComponent> FollowCamera;
};
```

并且在构造函数中创建组件。在这之前需要了解一下 Pawn 和 Character 的朝向问题。

因为在 Move 函数中我们只是令 Pawn 平移，并没有修改朝向（改变 Rotation），所以可以认为 Pawn 永远朝某一方向。这也就是为什么之前运行游戏时，Character 朝向不变了。

但是由于 Character 自带 Mesh，所以在我们肉眼看来 Character 的「朝向」其实就是 Mesh 的面对方向（即蓝图编辑器中的「箭头组件」指向）。

对于这个俯视角第三人称 RPG 游戏而言，我们希望玩家在移动时，人物能够面朝移动方向，同时视角又不会随人物转向而变化，这就要用到两个关键变量 `bOrientRotationToMovement` 和 `bUsePawnControlRotation` 了。

`bOrientRotationToMovement` 这个变量在 Character Movement Component 中定义，意思是「旋转角色朝向加速变量」，如果速度（矢量）方向向右，则玩家会自动调整转向，使得 Character 朝向右方。使用这个变量时，需要将 `bUseControllerRotation*` 设为 false，从而使角色旋转脱离 Controller。

`bUsePawnControlRotation` 则是对于组件而言的，如果设为 true，则会改为与 Pawn 的旋转一致，否则就是默认跟随 Character 一起旋转。因为这里 Pawn 的不转的，所以组件也不会转，从而实现我们需要的「视角固定」效果。

> 如果设置 `bUsePawnControlRotation` 为 true，则对组件相对旋转的自定义设置会无效。所以如果要实现俯视角，可以使用「插槽偏移」，即结束位置的偏移量。
>
> 或者也可以和 `bInherit*` 一起都设为 false，这样就不会被根组件的旋转干扰了，也就可以直接设置相对旋转，不用使用插槽偏移。

```cpp Character/Player/RPlayerBase.cpp
ARPlayerBase::ARPlayerBase()
{
  ...
  
  bUseControllerRotationRoll = false;
  bUseControllerRotationPitch = false;
  bUseControllerRotationYaw = false;
  
  // 旋转朝向运动
  GetCharacterMovement()->bOrientRotationToMovement = true;
  // 设置转身速率
  GetCharacterMovement()->RotationRate = FRotator(0.0f, 400.0f, 0.0f);
  // 限制对象在特定平面上的运动
  GetCharacterMovement()->bConstrainToPlane = true;
  // 在对象初始化时，它会被立即捕捉到指定平面上
  GetCharacterMovement()->bSnapToPlaneAtStart = true;

  // 创建组件
  CameraBoom = CreateDefaultSubobject<USpringArmComponent>("Spring Arm");
  check(CameraBoom);
  FollowCamera = CreateDefaultSubobject<UCameraComponent>("Camera");
  check(FollowCamera);

  // 绑定到胶囊体
  CameraBoom->SetupAttachment(GetCapsuleComponent());
  CameraBoom->bUsePawnControlRotation = false;
  CameraBoom->bInheritRoll = false;
  CameraBoom->bInheritPitch = false;
  CameraBoom->bInheritYaw = false;
  CameraBoom->TargetArmLength = 750.0f;
  CameraBoom->SetRelativeRotation(FRotator(0.0f, 0.0f, -45.0f));

  // 相机绑定到弹簧臂
  FollowCamera->SetupAttachment(CameraBoom);
  FollowCamera->bUsePawnControlRotation = false;
}
```