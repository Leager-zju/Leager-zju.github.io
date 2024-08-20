---
title: Action Rouge by Unreal Engine(2):按键绑定与移动
author: Leager
mathjax: true
date: 2024-08-16 12:00:00
summary:
categories:
  - unreal
tags:
  - unreal
  - gameplay
img:
---

现在需要实现以下内容：

1. 按 `WASD` 控制角色移动；
2. 移动鼠标控制视角；
3. 按空格跳跃；

<!-- more -->

## 将移动函数与输入绑定

### 事件与 C++ 函数绑定

按下按键，使角色移动，这一功能是在 `SetupPlayerInputComponent()` 函数中进行的，通常用于设置输入绑定。

在 UE 中，键盘输入会先绑定到一个「命名事件」上，然后再执行该事件上绑定的函数，这样就实现了「按键」与「行为」的解耦，也方便用户后续自定义按键设置。在 C++ 代码中，我们进行的是将函数与事件的绑定。

之前在创建角色蓝图类的时候，发现视口中有一个蓝色的箭头，这是一个特殊的变量 forward vector，永远指向玩家正前方。在实现移动时就需要用到这个矢量。这里先尝试实现前后移动。

```cpp RCharacter.cpp
void ARCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
  Super::SetupPlayerInputComponent(PlayerInputComponent);

  // 将连续输入事件 MoveForward 与 MoveForward() 函数进行轴绑定
  if (PlayerInputComponent)
  {
    PlayerInputComponent->BindAxis("MoveForward", this, &ARCharacter::MoveForward);
  }
}

void ARCharacter::MoveForward(float value)
{
  // 往 forward vector 方向位移 value 单位长度
  AddMovementInput(GetActorForwardVector(), value);
}
```

这样在触发「MoveForward」事件时，就会调用 `MoveForward()` 函数，使得玩家向 forward vector 方向移动。

> 头文件中对 `MoveForward()` 的声明略。
>
> 这里会发现除了 `BindAxis()` 还有一个 `BindAction()` 函数，区别在于，前者通常会映射到游戏中的连续运动或者数值变化，比如角色的移动速度、镜头的旋转等；后者则用于处理离散的输入，比如按键的按下或者释放，通常会映射到游戏中的离散动作，比如跳跃、开火、交互等。

### 输入与事件绑定

而键盘输入与事件的绑定则是在编辑器中进行。点击`编辑` -> `项目设置` -> `输入` -> `轴映射`，设置事件名和相应的按键，如下图所示。这里 `W` 的 scale 设为 1 是因为我们想往 forward vector 正向移动，`S` 设为 -1 同理。

<img src="moveforward.png" alt="前后移动" style="zoom:75%">

角色左右移动、鼠标旋转视角和跳跃也是同理的。只不过跳跃是 Action 映射。最终我们得到的代码以及输入映射如下。

```cpp RCharacter.cpp
void ARCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
  Super::SetupPlayerInputComponent(PlayerInputComponent);

  if (PlayerInputComponent)
  {
    PlayerInputComponent->BindAxis("MoveForward", this, &ARCharacter::MoveForward);
    PlayerInputComponent->BindAxis("MoveRight", this, &ARCharacter::MoveRight);
    PlayerInputComponent->BindAxis("TurnAround", this, &ARCharacter::AddControllerYawInput);
    PlayerInputComponent->BindAxis("LookUp", this, &ARCharacter::AddControllerPitchInput);

    // IE_Pressed 指的是按下时触发事件，这里绑定的 callback 就不需要传入参数了
    PlayerInputComponent->BindAction("Jump", EInputEvent::IE_Pressed, this, &ARCharacter::JumpAction);
  }
}

void ARCharacter::MoveForward(float value)
{
  AddMovementInput(GetActorForwardVector(), value);
}

void ARCharacter::MoveRight(float value)
{
  AddMovementInput(GetActorRightVector(), value);
}

void ARCharacter::JumpAction()
{
  Jump();
}
```

<img src="keymap.png" alt="最终结果" style="zoom:75%">

此时将蓝图拖到场景中，运行游戏时发现我们并不能控制玩家移动，这是因为控制器并没有分配给玩家。需要做的是选中该实例，在「细节」栏中搜索「**自动控制玩家**」，将「已禁用」改为「玩家0」（就是我们创建的实例，单机游戏中直接这么设置就好了）。

<img src="autopawn.png" style="zoom:75%">

## 优化玩家移动

### 视角旋转优化

编译编辑器，运行，发现依然存在问题，那就是在鼠标左右移动时，角色也在进行自转，这并不符合预期——我们只希望相机绕角色旋转。

这是因为每个用户的输入实际上是送到「玩家控制器」的，然后由其控制角色的运动。当我们创建蓝图类时，其实会默认启用「**使用控制器旋转 Yaw**」，所以在鼠标移动时，触发上面绑定的 `TurnAround` 事件，调用 `AddControllerYawInput`，使得控制器产生 `Yaw` 轴上的偏转，同时带动玩家的 `RootComponent` 旋转（同理可以想想启用「使用控制器旋转 Pitch」会发生什么），这样所有的子组件也都一起转了。

正确的做法是**禁用**该选项，同时在弹簧臂组件中启用「**使用 Pawn 控制旋转**」，此时弹簧臂组件会继承控制器的所有偏角输入，从而达到鼠标控制视角但角色不动的效果。

### 前进优化

不仅如此，我们还希望按下 `W` 键时，同时无论鼠标怎么移动，角色能够**始终**面朝相机正对方向前进。

首先要用到**角色移动组件(Character Movement Component)**中的一个叫「**将旋转朝向移动**」的变量，它能够使当用户移动时，将 forward vector 旋转至与移动方向对齐，这样角色能够始终面朝移动方向。

> 所谓移动方向其实就是「**控制器方向**」

其次，要想角色朝着控制器方向移动，就需要将 `MoveForward()` 中 `AddMovementInput()` 传入的向量改为控制器相关的向量。只需要调用 `GetControllerRotation()` 即可获得控制器的旋转信息。由于我们只关心 `Yaw`，所以需要将 `Pitch` 和 `Roll` 置零，然后调用 `Vector()` 获取对应的向量，就是需要的结果了。

### 左右转优化

前进的问题解决了，但是又引入了新的问题，那就是在按下 `A`/`D` 时，受「旋转朝向移动」的影响，角色会旋转至使得 forward vector 朝向移动方向（左/右），但是我们的右移基于的是 right vector，角色的旋转必然会导致这一向量跟着旋转，所以结果就是在运行游戏时，角色一直旋转。而预期是角色逐渐旋转然后朝一个方向前进。

这样就不能用角色的 right vector 了，而是将移动方向（`AddMovementInput()` 的第一个参数）改为控制器的 right vector。这两者是有本质区别的。这里要引入 UE 内置的一个 `UKismetMathLibrary` 库了，里面提供了许多旋转体、向量互相转换的函数，其中就有一个我们需要的根据旋转体获取右侧向量的 `GetRightVector()` 函数，直接使用即可。

<img src="vectors.png" alt="W/D 同时按下时角色的各个向量状态" style="zoom:75%">

### 代码修改

在 C++ 中应当进行如下修改：

```cpp RCharacter.cpp
#include "GameFramework/CharacterMovementComponent.h"
#include "Kismet/KismetMathLibrary.h"

ARCharacter::ARCharacter()
{
  ...
  GetCharacterMovement()->bOrientRotationToMovement = true;
  bUseControllerRotationYaw = false;
  ...
  CameraBoom->bUsePawnControlRotation = true;
  ...
}

void ARCharacter::MoveForward(float value)
{
  FRotator ControllerRotation = GetControlRotation();
  ControllerRotation.Pitch = 0.0f;
  ControllerRotation.Roll = 0.0f;
  // 这里也使用了库函数，查看函数实现会发现和我们之前说的完全一致
  AddMovementInput(UKismetMathLibrary::GetForwardVector(ControllerRotation), value);
}

void ARCharacter::MoveRight(float value)
{
  FRotator ControllerRotation = GetControlRotation();
  ControllerRotation.Pitch = 0.0f;
  ControllerRotation.Roll = 0.0f;
  AddMovementInput(UKismetMathLibrary::GetRightVector(ControllerRotation), value);
}
```
