---
title: Action Rouge by Unreal Engine(1):人物与视角
author: Leager
mathjax: true
date: 2024-08-15 12:00:00
summary:
categories:
  - unreal
tags:
  - unreal
  - gameplay
img:
---

一个基于 Unreal Engine 开发的 demo，试图学习 GamePlay with UE 基本设计。

<!-- more -->

参考资料：

- [视频资料：bilibili](https://www.bilibili.com/video/BV1Rt421V7r2/?p=2&spm_id_from=pageDriver&vd_source=6c9ee957ce4e9589cb06ddc343edf771)
- [课程原始链接](https://courses.tomlooman.com/p/unrealengine-cpp)
- [这个作者写的有用的教程](https://www.tomlooman.com/)
- [官方文档](https://www.unrealengine.com/zh-CN)

## 准备工作

### 下载 Unreal Engine 与 Visual Studio

[这是 Unreal Engine 的下载链接](https://www.unrealengine.com/zh-CN/download)。

> 最终得到的是 Epic Games，可以用 steam 登录，之后下载最新版虚幻引擎。此时是 **5.4.3** 版本。

[这是 Visual Studio 的下载链接](https://visualstudio.microsoft.com/zh-hans/vs/)。

> 下载 Community 2022 版。

根据[这个教程](https://dev.epicgames.com/documentation/zh-cn/unreal-engine/setting-up-visual-studio-development-environment-for-cplusplus-projects-in-unreal-engine)进行 VS 相关组件的安装。

同时去虚幻商城搜索并安装「Visual Studio Tools」。

> 🍕可选：安装 [Visual Assist 破解版](https://zhuanlan.zhihu.com/p/661815368)。

### 创建新项目

打开引擎后会出现这个界面。选择「空白项目」，在项目默认设置中选择「C++」，并取消勾选「初学者内容包」，选择项目位置和项目名称，如下图所示：

<img src="createProject.png" alt="创建新项目">

点击创建，经过亿点时间后，我们就能在编辑器中看到我们新建的项目了。

## 创建角色

### 新建 C++ 类

点击编辑器最上方的「工具」选项，然后是「新建 C++ 类」，选择「角色」，选择类的类型为「公有」，然后进行一个命名。这里命名为 `RCharacter`，`R` 为 `Rouge` 缩写。如下图所示：

<img src="addClass.png" alt="添加类">

<img src="addCharacter.png" alt="新建角色">

创建之后会进行热重载，经过亿点时间后，我们就能在 VS 中看到引擎利用模板为我们生成了相应的 `.cpp` 和 `.h` 文件了。

### 新建蓝图类

> 虚幻引擎的蓝图是一种视觉化脚本系统，允许开发人员和设计师在不编写代码的情况下创建游戏逻辑和交互。蓝图系统使用图形化的节点和连线来表示代码逻辑，使得游戏开发变得更加直观和可视化。这使得非程序员也能够参与游戏开发过程，从而加快了开发周期并且降低了技术门槛。—— ChatGPT 3.5

C++ 类的作用是允许我们进行一些功能的开发，但是为了将我们实现的角色以可视化的方式放到游戏中，还需要建立对应的**蓝图(BluePrint)**类。

点击编辑器左下角的「内容侧滑菜单」，可以打开「内容编辑器」，以后经常会用到，相当于一个内置的文件夹系统。内容编辑器的左上方有个「添加」按钮，点击并选择「蓝图类」，在「所有类」中搜索我们之前创建的 C++ 类 `RCharacter`，选中后就会在内容编辑器中看到新生成的蓝图了。这里为了便于辨别，将其命名为 `RCharacterBP`（后续的蓝图类都会在对应的 C++ 类名后加上 `BP` 后缀）。

<img src="addBP.png" alt="新建蓝图">

双击蓝图类，可以看到进入一个新的编辑器视图，这就是其存在形式了——一个带箭头的胶囊体。

右侧有「细节」栏，可以设置组件的属性。之后都会用到。

### 两个基本组件：相机 & 弹簧臂

在游玩如第三人称视角游戏的过程中，不难注意到无论角色怎么移动，我们的屏幕视角都是固定的，也就是总能看到玩家的背部。但又不是正中央，不然就只能看到一个后脑勺，完全没法看到玩家前方的情况。这一特性是通过在玩家胶囊体上「固定」一个「相机」实现的。

这里用到的组件分别是**相机**（`UCameraComponent`）和**弹簧臂**（`USpringArmComponent`）。回到代码中，我们需要在 `RCharacter` 类中加入以下内容：

```cpp RCharacter.h
class USpringArmComponent;
class UCameraComponent;

UCLASS()
class ACTIONROUGE_API ARCharacter : public ACharacter
{
	GENERATED_BODY()
	...

protected:
  UPROPERTY(VisibleAnywhere)
  USpringArmComponent* CameraBoom;

  UPROPERTY(VisibleAnywhere)
  UCameraComponent* FollowCamera;
};
```

同时修改类的构造函数，使得角色在世界中创建时能够生成这两个组件。

```cpp RCharacter.cpp
#include "Camera/CameraComponent.h"						// UCameraComponent 定义文件
#include "GameFramework/SpringArmComponent.h"	// USpringArmComponent 定义文件

ARCharacter::ARCharacter()
{
	...
	CameraBoom = CreateDefaultSubobject<USpringArmComponent>("Camera Boom");
	FollowCamera = CreateDefaultSubobject<UCameraComponent>("Follow Camera");

	if (CameraBoom)
	{
		CameraBoom->SetupAttachment(RootComponent);
		// 设置属性值，使得相机位于正确的位置，而不是角色正背后
		CameraBoom->SetRelativeLocation(FVector(0.0f, 0.0f, BaseEyeHeight));
		CameraBoom->TargetArmLength = 300.0f;
		CameraBoom->SocketOffset.Y = 90;
	}
	if (FollowCamera)
	{
		FollowCamera->SetupAttachment(CameraBoom);
	}
}
```

> 这里涉及到一些**知识点**。
> 
> 首先是关于类名前面多了个大写字母 `A`，这是因为 UE 会根据一定**命名规则**为类型添加相应的字母前缀，以更好地辨认一个类名。常见的有以下几种：
> 
> - `A`：`Actor` 的派生类。
> - `U`：`Object` 的派生类。
> - `F`：非虚幻对象的类，通常是一些辅助类或数据结构。
> - `I`：Interface，接口类。
> - `T`：Template，模板类。
> - `S`：Slate UI，`SWidget` 的派生类，
> - `E`：Enum，枚举类。
> 
> 然后是 `UCLASS()` 这个**宏**，其用于定义一个类，告诉引擎如何处理这个类，以便它能够在编辑器中使用并在蓝图中被继承和实例化，同时能够与反射系统进行交互，使其能够在运行时被识别和操作。我们在编辑器中新建 C++ 类时，引擎会帮我们自动生成代码；但是如果是手动加入 `.h` 文件时，则不要忘记加入该宏。
> 
> 而 `GENERATED_BODY()` 宏就比较简单，会生成一些额外的代码，包括 `new`/`delete` 操作符重载、拷贝构造、移动构造、析构函数等基础函数，以及一些额外的 UE 功能。
> 
> `UPROPERTY()` 宏则是根据指定的「**属性说明符**」，将其修饰的变量标记为虚幻引擎的反射系统可见，从而使其可以在编辑器中进行编辑、序列化和其他操作。常用的有以下属性说明符：
>
> - **VisibleDefaultsOnly**：指示此属性仅在**原型**的属性窗口中可见，不能编辑。
> - **VisibleInstanceOnly**：指示此属性仅在**实例**的属性窗口中可见，不能编辑。
> - **VisibleAnywhere**：指示此属性在**所有**属性窗口中都可见，但无法编辑。
> - **EditDefaultsOnly**：指示此属性可由属性窗口编辑，但只能在**原型**上编辑。
> - **EditInstanceOnly**：指示此属性可由属性窗口编辑，但只能在**实例**上编辑。
> - **EditAnywhere**：指示此属性可由属性窗口编辑，且能对**原型和实例**编辑。
> - **BlueprintReadOnly**：在蓝图中可见但只读。
> - **BlueprintReadWrite**：在蓝图中可见且可编辑。
>
> `CreateDefaultSubobject()` 是一个工厂函数，用于创建特定类型的 UObject，字符串是生成的组件名字。
>
> `SetupAttachment()` 则将一个组件绑定到另一个组件上，形成一种树状结构，根组件的移动会使得所有子组件一起移动。这里 `RootComponent` 是 `AActor` 类的一个成员变量，它定义了 Actor 的位置、旋转和缩放。如果不进行 `SetupAttachment()`，则三者之间并不会产生联系，相当于在创建 `RCharacter` 时凭空创建了弹簧臂和相机，并不会随玩家移动而移动。

按 F5 构建后，打开编辑器，发现蓝图类中已经出现了这两个组件，并且往世界场景中拖入 `RCharacterBP` 后运行游戏，发现相机正常运作了。

### 设置骨骼网格体

在虚幻商城中有许多免费资源可以下载，我这里使用的是「Paragon: Gideon」这一素材。下载后添加到工程。

> 路径 `/All/Game/ParagonGideon/Characters/Heroes/Gideon` 下的蓝图 `GideonPlayerCharacter` 是素材为我们提供的，编译时会报蓝图编译错误，无需理会，不使用就好了。

回到 `RCharacterBP` 中，选中「网格体」，在「细节」栏中设置「骨骼网格体资产」与「动画类」，同时修改「变换」使得该骨骼能够面朝视口中的 forward vector。

<img src="setupcharacter.png">