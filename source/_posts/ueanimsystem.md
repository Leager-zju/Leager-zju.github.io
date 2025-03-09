---
title: Unreal Engine の 动画系统
author: Leager
mathjax: true
date: 2025-03-06 13:02:50
summary:
categories:
  - unreal
tags:
  - unreal
  - gameplay
img:
---

> 「**动画系统**」由多个动画工具和编辑器构成，其将基于骨架的变形与基于变形的顶点变形相结合，从而构建出复杂的动画。该系统可以用于播放和混合预先准备好的动画序列让基本玩家运动显得更加真实，创建自定义特殊动作，如伸缩台阶和墙壁（使用动画蒙太奇），通过变形目标应用伤害效果或面部表情，使用骨架控制直接控制骨骼变形，或创建基于逻辑的 状态机 来确定角色在指定情境下应该使用哪个动画。——[虚幻官方文档](https://dev.epicgames.com/documentation/zh-cn/unreal-engine/animation-system-overview?application_version=4.27)

<!-- more -->

## 骨架网格体(Skeleton Mesh)

### 骨骼(Bones)与骨架(Skeleton)

在虚幻引擎中，**骨架**通常是一个数字层级架构，用于定义角色中的**骨骼**或关节，并以诸多方式模仿真实的生物骨架。同时，骨架资源将关联动画数据，从而驱动动画。

骨骼是骨架的基本组成单元。在骨架中，骨骼以层级结构组织，形成一个树状结构。**根骨骼**是骨架层级结构的根节点。它是整个骨架的父骨骼，控制着整个骨架的位置和方向。除了根骨骼外，每个骨骼都有一个**父骨骼**，并且可以有多个子骨骼。此外，每个骨骼还有用于唯一标识符的**名称**以及用于确定在空间中状态的**变换信息**。

> 变换信息指的是**位置**、**旋转**、**缩放**这些信息。如果每个骨骼记录的变换信息都基于世界坐标，那么角色在运动时几乎所有骨骼都需要进行更新。可以将父骨骼的局部坐标系作为参照，只记录相对变换，从而降低开销。

在 C++ 中，骨架被定义为类 `USkeleton`。骨骼完整的信息存放在 `FReferenceSkeleton` 类型的成员变量 `ReferenceSkeleton` 中。该变量的部分内容如下

```C++ ReferenceSkeleton
struct FMeshBoneInfo
{
	// Bone's name.
	FName Name;

	// INDEX_NONE if this is the root bone. 
	int32 ParentIndex;
}

struct FReferenceSkeleton
{
  ...
	//RAW BONES: Bones that exist in the original asset
	/** Reference bone related info to be serialized **/
	TArray<FMeshBoneInfo>	RawRefBoneInfo;
	/** Reference bone transform **/
	TArray<FTransform>		RawRefBonePose;

	//FINAL BONES: Bones for this skeleton including user added virtual bones
	/** Reference bone related info to be serialized **/
	TArray<FMeshBoneInfo>	FinalRefBoneInfo;
	/** Reference bone transform **/
	TArray<FTransform>		FinalRefBonePose;

	/** TMap to look up bone index from bone name. */
	TMap<FName, int32>		RawNameToIndexMap;
	TMap<FName, int32>		FinalNameToIndexMap;
  ...
}
```

每个骨骼的信息用 `FMeshBoneInfo` 结构体描述，有名称以及父骨骼在 TArray 中的索引。此外 `FReferenceSkeleton` 中还有骨骼的变换信息以及名称到数组索引的映射。

### 骨架网格体

单有骨架还不行，我们还需要为其赋予血肉，这就得到了**骨架网格体**。骨架网格体本质上是将**几何数据**、**骨架信息**、**蒙皮权重**进行结合得到的产物。

其中，几何数据指的是模型**顶点**、三角形表面、UV 坐标、法线、切线等用于图像渲染的数据。在这里，我们只关注顶点这一概念。

而蒙皮权重是骨架网格体中最重要的概念之一。在骨架网格体中，每根骨骼都与骨架网格体的一部分顶点相关联。当骨骼移动或旋转时，与其关联的顶点也会随之移动，从而实现模型的变形。其中，蒙皮权重定义了每个骨骼应用变换时对每个顶点的影响程度。权重越高，顶点受该骨骼的影响越大。

## 动画(Animation)

### 动画序列(Animation Sequence)

在任一时间点，一个骨架网格体中所有骨骼变换信息的集合又被称为**姿势(Pose)**。而**动画序列**，正是一系列姿势随时间变化的集合，通过在关键姿势之间进行插值，生成连续的动画效果。

> 每个动画序列专门针对一个特定骨架，且只能在该骨架上播放。换言之，为了能在多个骨架网格体之间共享动画，每个网格体必须使用相同的骨架资源。

### 动画蒙太奇



### 动画混合(Animation Blend)

**混合**是指将两个或多个值或状态组合在一起的过程，以产生一个平滑的过渡或最终结果。而**动画混合**，指的就是多个动画序列里的每一条变换信息相互之间基于权重的运算过程，本质上是对每个时间点的姿势进行混合。

通过动画混合，我们能够平滑地过渡和组合不同的动画姿势，从而创造出更自然的角色动画。比如根据角色的速度和方向，动态地在行走和跑步之间平滑过渡；或者将换弹与跑步相混合，得到一个奔跑时换弹的融合动作。

#### 变换信息运算方式

变换信息的运算有以下两种方式：**覆写**和**叠加**。

覆写是直接将目标变换设置为`源变换 * 权重`。

```C++ Overrite Transform
template<>
FORCEINLINE void BlendTransform<ETransformBlendMode::Overwrite>(const FTransform& Source, FTransform& Dest, const float BlendWeight)
{
	const ScalarRegister VBlendWeight(BlendWeight);
	Dest = Source * VBlendWeight;
}
```

而叠加是在目标变换的基础上加上`源变换 * 权重`。

```C++ Accumulate Transform
template<>
FORCEINLINE void BlendTransform<ETransformBlendMode::Accumulate>(const FTransform& Source, FTransform& Dest, const float BlendWeight)
{
	const ScalarRegister VBlendWeight(BlendWeight);
	Dest.AccumulateWithShortestRotation(Source, VBlendWeight);
}
```

#### 姿势混合(Pose Blending)

姿势混合将两个或多个动画的姿势组合在一起，以创建新的姿势，从而得到混合后的新的动画。

虚幻引擎中的动画蓝图提供了以下几种基于混合节点的姿势混合方式：

1. **叠加混合**。对应于动画蓝图中的 `Apply Additive`/`Apply Mesh Space Additive` 节点。这种方式下，节点会根据权重值 Alpha 在 Base 姿势上叠加 Additive 姿势，即 Dest = Additive + Base * Alpha。其中，Additive 姿势记录的是相对于参考姿势的**偏移量**，而不是绝对姿势。

2. **线性插值混合**。对应于动画蓝图中的 `Blend` 节点。这种方式下，节点会根据权重值 Alpha 简单地混合两个输入姿势 A 和 B，即 Dest = A * (1-Alpha) + B * Alpha。

3. **骨骼分层混合**。对应于动画蓝图中的 `Layered blend per bone` 节点。这种方式下，节点会根据权重值 Alpha 仅针对某一部位的骨骼进行线性插值混合。在虚幻引擎中，该混合方式有以下两种不同模式：

	- **Branch Filter**。选择骨架上的某个骨骼，该骨骼及其子骨骼都会受到影响。为了进一步控制效果，引入了 `Blend Depth` 这一参数。参数为 0 时，整条骨骼链完全参与混合；参数为 N 时，从指定骨骼起，到第 N 层子骨骼为止，逐渐从 0 到 Alpha 进行混合，越往下混合程度越深；参数为 -1 时，从指定骨骼开始往下的所有子骨骼都不参与混合，起到「屏蔽」的作用。

	- **Blend Mask**。可以自定义一个 Blend Mask 配置，该配置为每个骨骼单独定义一个 0~1 的数值，0 意味着动画不会在该骨骼上播放，而 1 代表动画完全播放，从而精确控制哪些骨骼参与混合，哪些骨骼不参与混合。

#### 混合空间(Blend Space)

**混合空间**能够通过一个或多个输入参数在多个动画序列之间平滑地混合。这些参数通常是角色的属性，例如速度、方向、攻击角度等。

混合空间由一系列采样点组成。每个采样点对应于一个特定的输入参数值，并指定要播放的动画序列。当输入参数的值发生变化时，混合空间会根据当前输入参数值，在*相邻*的采样点之间进行混合。

> 比如在混合空间 1D 中，设置「速度」为参数，在数值 0 处设置动画序列「Idle」的采样点，在数值 1 处设置动画序列「Walk」的采样点，在数值 3 处设置动画序列「Run」的采样点。那么在速度为 0~1 时，混合空间会采用**线性插值**的方式，驱动网格体的姿势从 Idle 平滑过渡到 Walk。在速度为 1~3 时同理。
>
> 而在混合空间 2D 中，则会采用**双线性插值**的方式来混合。

虽然都是进行「混合」，但与混合节点不同，混合空间更像是“参数驱动的过渡工具”，确保动画连续性，



### 动画实例



### 动画通知

