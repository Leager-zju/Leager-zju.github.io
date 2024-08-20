---
title: Action Rouge by Unreal Engine(4):交互与宝箱
author: Leager
mathjax: true
date: 2024-08-18 12:00:00
summary:
categories:
  - unreal
tags:
  - unreal
  - gameplay
img:
---

现在需要为角色实现「交互」。

1. 用户按下交互键 `E`；
2. 如果角色前方一定距离内有可交互物体，则进行交互；

<!-- more -->

## 创建可交互类

基于 `Is-a` 原则，所有可交互物体应继承自同一个抽象类 `RInteractable`，它声明若干纯虚函数并将实现交给派生类进行。这里要用到 UE 里的 **Unreal Interface** 了，它用于定义一组函数签名，有助于确保一组（可能）不相关的类实现一组通用函数，并且方便其它 Actor 通信时进行统一类型转换。

```cpp RInteractable.h
UINTERFACE(MinimalAPI)
class URInteractable : public UInterface {...};

class ACTIONROUGE_API IRInteractable {...};
```

创建后得到这样一个文件内容，有两个不同的类 `URInteractable` 和 `IRInteractable`。其中 `URInteractable` 类是一个空白类，它的存在只是为了向 UE 反射系统确保可见性。将由类 `IRInteractable` 进行实际接口的声明，同时被其他类继承。

这里我们先为其添加一个交互函数，同时添加一个 `UFUNCTION()` 的修饰。这是为了声明为「**蓝图可调用接口函数**」，以便后续在蓝图中可见可调用。这里我们指定了 `BlueprintNativeEvent` 为函数说明符，目的是为了允许在蓝图和 C++ 中都进行实现（优先蓝图，如果蓝图没实现就去 C++ 里找）。此时 C++ 的派生类实现需在函数名后加上 "**_Implementation**" 后缀。

```cpp RInteractable.h
class ACTIONROUGE_API IRInteractable
{
	...
public:
	UFUNCTION(BlueprintNativeEvent)
	void Interact(APawn* Instigator);
};
```
> `UFUNCTION` 宏指定的函数说明符有下面几个。
> 
> | 函数说明符 | 效果 |
> | --- | --- |
> | `BlueprintAuthorityOnly` | 如果在具有网络权限的机器上运行（服务器、专用服务器或单人游戏），此函数将仅从蓝图代码执行。|
> | `BlueprintCallable` | 此函数可在蓝图或关卡蓝图图表中执行。|
> | `BlueprintCosmetic` | 此函数为修饰性的，无法在专用服务器上运行。|
> | `BlueprintImplementableEvent` | 此函数可在蓝图或关卡蓝图图表中实现。|
> | `BlueprintNativeEvent` | 此函数允许被蓝图覆盖，但是也允许添加 C++ 实现，须在函数末尾添加"_Implementation"。如果未找到任何蓝图覆盖，该自动生成的代码将调用 C++ 方法。|
> | `BlueprintPure` | 此函数不对拥有它的对象产生任何影响，可在蓝图或关卡蓝图图表中执行。早默认情况下，带有 const 标记的函数将作为纯函数公开。要将常量函数变成非纯函数，你可以做以下声明：BlueprintPure=false |

## 从打开宝箱开始

C++ 类创建过程略。在世界中生成宝箱类 `RChest` 实例，同时允许玩家「交互」，交互结果为「宝箱打开」，所以需继承自 `IRInteractable` 类，同时实现 `Interact_Implementation()` 方法。

### 外观设置

宝箱的外观由三部分组成，一是箱体，二是箱盖，三是箱中宝藏。所以需要在类 `RChest` 中添加三个 `UStaticMeshComponent` 组件，用于设置 Skeletal Mesh 和 Texture，并表示箱体、箱盖和宝藏。创建派生蓝图类 `RChestBP`，完成设置后如下所示。

<img src="chest.png" style="zoom:50%">

### 交互函数实现

对于宝箱打开，希望实现为「箱盖」以 Pitch 轴在一定时间内（如 0.5s）旋转一定角度，同时在完全打开时激活金币爆发的粒子效果。

这里就要用到 UE 的时间轴功能。需要在类中添加两个组件，`UTimelineComponent` 和 `UCurveFloat`。后者是浮点数值随时间变化的曲线，通常用于在游戏中实现平滑的数值变化；前者根据浮点数变化曲线，逐帧输出一个浮点数。

然后是添加粒子效果，过程略。需要注意的是要在代码中将 `bAutoActivate = false`，这样才能在运行时控制粒子激活的时间。

最后实现如下，其中 `OpenPitch` 是一个 float 变量，可自定义旋转角度。

```cpp RChest.cpp
void ARChest::Interact_Implementation(APawn* InteractInstigator)
{
	PlayOpenAnim();
}

void ARChest::PlayOpenAnim()
{
	if (bOpen) // 幂等处理
	{
		return;
	}

	bOpen = true;
	if (ChestOpenTimelineFloatCurve)
	{
		FOnTimelineFloat UpdateFunctionFloat;
		UpdateFunctionFloat.BindUFunction(this, FName("UpdateTimelineComp"));

		ChestOpenTimeLine->AddInterpFloat(ChestOpenTimelineFloatCurve, UpdateFunctionFloat);
		ChestOpenTimeLine->PlayFromStart();

		GoldBurstParticle->Activate(); // 激活粒子效果
	}
}

void ARChest::UpdateTimelineComp(float Output)
{
	LidMesh->SetRelativeRotation(FRotator(Output * OpenPitch, 0.0f, 0.0f));
}
```

这里的 `ChestOpenTimelineFloatCurve` 变量需要在蓝图中自行添加：「内容浏览器」->「添加」->「其它」-> 「曲线」

## 角色检测面前是否存在宝箱

参考之前的设计，我们可以为角色添加一个 Actor Component，并命名为 `RInteractionComponent`，专门负责交互功能。

那么如何进行碰撞检测呢？引擎给我们提供了若干碰撞检测函数。

1. **Line Trace**: 以射线形式检测；
2. **Sphere Trace**: 与 Line Trace 类似，但使用球体来进行检测；
3. **Box Trace**: 使用一个立方体来进行碰撞检测；
4. **Overlap**: 用于检测区域内重叠，而不是沿着一条线或一个形状进行碰撞检测；
5. **Sweep**: 在运动过程中进行碰撞检测，而不仅仅是沿着一条线；

这里采用 Line Trace 射线检测。此时需要确定射线起点与方向，这里采用角色眼睛位置作为起点，控制器朝向作为射线方向。右键「添加关键帧」可以增加控制点，分别在 (0, 0) 与 (0.5, 1) 两处增加即可。

```cpp Components/RInteractionComponent.cpp
void URInteractionComponent::Interact()
{
	AActor* Owner = GetOwner();
	if (!Owner)
	{
		return;
	}

	FVector EyeLocation;
	FRotator EyeRotation;
	// 获取眼睛的 Transform 信息
	Owner->GetActorEyesViewPoint(EyeLocation, EyeRotation);
	// 设置一个比较合理的检测终点位置
	FVector End = EyeLocation + EyeRotation.Vector() * 300;

	// 设置额外参数，比如碰撞查询目标类型
	FCollisionObjectQueryParams ObjectQueryParams;
	ObjectQueryParams.AddObjectTypesToQuery(ECC_WorldDynamic);

	FHitResult HitResult;
	bool OnHit = GetWorld()->LineTraceSingleByObjectType(HitResult, EyeLocation, End, ObjectQueryParams);

	if (OnHit)
	{
		// 如果射线与 WorldDynamic 类型的 Actor 发生碰撞，则判断其是否为可交互对象
		// 若是，则执行 Interact()
		AActor* Interactable = HitResult.GetActor();
		APawn* RCharacter = Cast<APawn>(Owner);

		if (Interactable->Implements<URInteractable>() && RCharacter)
		{
			IRInteractable::Execute_Interact(Interactable, RCharacter);
		}
	}
}
```