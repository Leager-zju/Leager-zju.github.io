---
title: Action Rouge by Unreal Engine(3):攻击与投射物
author: Leager
mathjax: true
date: 2024-08-17 12:00:00
summary:
categories:
  - unreal
tags:
  - unreal
  - gameplay
img:
---

现在需要为角色实现「攻击」。

1. 用户按下攻击键 `Mouse Left`，触发攻击事件；
2. 角色播放攻击动画，并在角色手掌前生成一个投射物；
3. 投射物有初速度，射向前方；
4. 投射物会在接触到阻挡体时触发 `OnHit` 事件；
5. 激活酷炫的粒子效果，然后将自身销毁；

<!-- more -->

## 战斗组件

为了使设计更加优雅，不妨在项目新文件夹 `Components` 下创建一个 C++ Actor Component 类，并命名为 `RCombatComponent`，专门用于处理战斗相关的逻辑，这样就不需要在角色类中加入一大堆函数和成员变量了。之后这个文件夹下还可以放负责其它逻辑的组件。

```cpp Components/RCombatComponent.h
class ARCharacter;

UCLASS( ClassGroup=(Custom), meta=(BlueprintSpawnableComponent) )
class ACTIONROUGE_API URCombatComponent final : public UActorComponent
{
  GENERATED_BODY()

public:
  URCombatComponent();

protected:
  virtual void BeginPlay() override;

private:
  ARCharacter* RCharacter; // 用于组件间通信
};
```

## 攻击键与攻击事件

可以直接绑定到成员组件的函数上。

```cpp RCharacter.cpp
void ARCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
  ...
  PlayerInputComponent->BindAction("NormalAttack", EInputEvent::IE_Pressed,
                                   CombatComponent, &URCombatComponent::NormalAttack);
}
```

### 投射物类定义

我们可以新建一个 C++ Actor 类，并命名为 `RMagicProjectile`。我们希望它能够自行移动，同时也希望能够具备检测是否触碰到敌人的能力，同时还要有**酷炫**的粒子效果。

这就需要在类中定义三个新的组件，分别是**投射物移动组件**(`UProjectileMovementComponent`)，**球形组件**(`USphereComponent`)和**粒子系统组件**(`UParticleSystemComponent`)。

相应代码如下：

```cpp RMagicProjectile.cpp
#include "GameFramework/ProjectileMovementComponent.h"
#include "Components/SphereComponent.h"

ARMagicProjectile::ARMagicProjectile()
{
  ...
  ProjectileMovement = CreateDefaultSubobject<UProjectileMovementComponent>("Projectile Movement");
  CollisionSphere = CreateDefaultSubobject<USphereComponent>("Collision Sphere");
  ProjectileParticle = CreateDefaultSubobject<UParticleSystemComponent>("Project Particle");

  if (ProjectileMovement)
  {
    ProjectileMovement->InitialSpeed = 2000.0f;
    ProjectileMovement->MaxSpeed = 2000.0f;
    ProjectileMovement->bRotationFollowsVelocity = true;
    ProjectileMovement->bInitialVelocityInLocalSpace = true; // 始终朝向特定方向
    ProjectileMovement->ProjectileGravityScale = 0.0f;       // 禁用重力
  }

  if (CollisionSphere)
  {
    RootComponent = CollisionSphere;
    CollisionSphere->SetRelativeLocation(FVector(0.0f, 0.0f, 0.0f));
    CollisionSphere->SetCollisionProfileName("Projectile");
    CollisionSphere->InitSphereRadius(15.0f);
  }

  if (ProjectileParticle)
  {
    ProjectileParticle->SetupAttachment(CollisionSphere);
  }
}
```

之后新建派生蓝图 `RMagicProjectileBP`，在蓝图中进行粒子系统的选择，这里可以直接用之前载入到工程的 `Gideon` 中的粒子。

### 发射 Magic Projectile

发射的预期行为是

1. 从手心生成；
2. 往相机正对方向发射；

生成 Actor 的函数是 `GetWorld()->SpawnActor()`，它接受三个参数，分别是 Actor 的类型、Actor 的变换信息（位置、旋转）以及一些额外的参数 `FActorSpawnParameters`。

因为投射物是蓝图类，所以这里需要我们手动设置投射物的类型。首先在 `RCombatComponent` 类中添加如下成员变量：

```cpp Components/RCombatComponent.h
UPROPERTY(EditDefaultsOnly)
TSubclassOf<AActor> ProjectileClass;
```

接下来是设置投射物的「生成位置」。为了在手心设置初始位置，有两种方法。

第一种是新增一个组件，但是需要随人物运动而实时改变位置；第二种方法更为方便，是借助「骨骼网格体」。

因为每个角色都有相应的 Skeletal Mesh，就和人类的关节、骨骼是一样的，当手动的时候，对应的骨骼也会随之运动，所以只需要找到一个合适的骨骼就行。

> 这里采用了名为 `Muzzle_01` 的插槽。插槽是绑定在骨骼上的，所以结果必然是符合预期的。

获取插槽位置可以用 `GetMesh()->GetSocketLocation()` 方法，只需传入插槽名即可。而控制器方向就简单多了，直接 `GetControlRotation()`。

现在，就可以先对攻击函数进行一个简陋的实现了。

```cpp Components/RCombatComponent.h
#include "RMagicProjectile.h"

void URCombatComponent::NormalAttack()
{
  if (RCharacter && ProjectileClass)
  {
    FTransform ProjectileTransform(RCharacter->GetControlRotation(),
                                   RCharacter->GetMesh()->GetSocketLocation("Muzzle_01"));

    FActorSpawnParameters SpawnParam;
    SpawnParam.Instigator = this;
    // 指定新生成的 Actor 在产生碰撞时的处理方式的枚举类型
    SpawnParam.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

    GetWorld()->SpawnActor<ARMagicProjectile>(ProjectileClass, ProjectileTransform, SpawnParam);
  }
}
```

### 攻击动画

攻击动画可以通过**蒙太奇(Montage)**来实现，相关函数为 `PlayAnimMontage()`。

> 所谓蒙太奇，简单来说就是一种可以在**运行时**摆脱动画状态机的控制，独立地播放一段动画片段的方法。

为了使用特定蒙太奇资产，我们需要在编辑器中指定。首先在头文件中加入 `UAnimMontage* AttackMontage` 变量并声明为 EditAnywhere，然后进入编辑器的角色蓝图，选择 `Primary_Attack_A_Medium_Montage`。

修改攻击函数后，运行游戏，发现虽然会播放攻击动画，但是投射物生成的位置不对。准确来说，生成的时间点不对——预期是在抬手时创建，这样能够保证在正确的位置发射。一个简单的做法是使用定时器，只要攻击动画不变，那么只要在固定时间点触发投射物生成即可。

但是考虑到可拓展性，一旦后续尝试修改角色的攻击速度，相应的会修改蒙太奇的播放速率，那么第一个方法就不起效了。于是考虑采用「动画通知」机制。当蒙太奇播放到某一帧时，调用该帧上通知类的 `Notify()` 函数，最后执行投射物生成的行为。

为此，我们首先需要创建一个继承自 `UAnimNotify` 的 C++ 类，并且进行接收通知函数的重载。

```cpp RAttackSpawnProjectileNotify.cpp
void URAttackProjectileNotify::Notify(USkeletalMeshComponent* MeshComp, UAnimSequenceBase* Animation, const FAnimNotifyEventReference& EventReference)
{
  Super::Notify(MeshComp, Animation, EventReference);

  ARCharacter* RCharacter = Cast<ARCharacter>(MeshComp->GetOwner());
  if (RCharacter)
  {
    RCharacter->OnNotifySpawnProjectile();
  }
}
```

```cpp RCharacter.cpp
void ARCharacter::OnNotifySpawnProjectile()
{
  CombatComp->OnNotifySpawnProjectile();
}
```

接下来就是在蒙太奇中的一个特定帧创建通知，设置通知类为 `URAttackProjectileNotify`，这样一来，当蒙太奇播放到该帧时，就会触发通知类的该函数，从而生成投射物。同样的，战斗组件的攻击函数也要进行相应修改。

```cpp Components/RCombatComponent.h
void URCombatComponent::NormalAttack()
{
  if (RCharacter)
  {
    RCharacter->PlayAnimMontage(AttackMontage);
  }
}

void URCombatComponent::OnNotifySpawnProjectile()
{
  if (RCharacter && ProjectileClass)
  {
    FTransform ProjectileTransform(RCharacter->GetControlRotation(),
                                   RCharacter->GetMesh()->GetSocketLocation("Muzzle_01"));

    FActorSpawnParameters SpawnParam;
    SpawnParam.Instigator = RCharacter;
    SpawnParam.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

    GetWorld()->SpawnActor<ARMagicProjectile>(ProjectileClass, ProjectileTransform, SpawnParam);
  }
}
```

### CoolDown

为了避免连续多次按下攻击键，导致无法播放到蒙太奇的 `AttackProjectileNotify` 帧，需要在每次攻击时先禁止攻击，直到动画播放完（或者到某一特定帧）后才允许下一次攻击，相当于为攻击设置了一个冷却时间。这就需要再创建一个通知类 `RAllowAttackNotify` 了，旨在启用玩家的下次攻击。

可以借鉴之前的思路，在蒙太奇某一帧创建通知。这里要额外在战斗组件中声明一个变量 `bCanAttack`，表示当前能否攻击。每次攻击时，将其置 false，并在收到通知时置 true，这样就能达到效果。

```cpp Components/RCombatComponent.h
void URCombatComponent::NormalAttack()
{
  if (RCharacter && bCanAttack)
  {
    bCanAttack = false;
    RCharacter->PlayAnimMontage(AttackMontage);
  }
}

void URCombatComponent::OnNotifyAllowAttack()
{
  bCanAttack = true;
}
```

## 碰撞检测

之前我们为了碰撞检测加入了一个组件 `USphereComponent`，它有一个球形范围(sphere)，并能利用该 sphere 以及一些**配置项**检测是否能与世界中的其它 Actor 进行交互。这个配置项就是「碰撞预设」，它规定了这个 sphere **本身类型(self)**，以及对**其它类型(other)**的 Actor 的响应模式：Ignore、Overlap 和 Block。 

> 关于碰撞的处理方式，需要记住几点规则：
>
> - 如果对另一个 Actor 设置了 Ignore，那么无论其碰撞预设如何，双方都不会触发事件。
> - Overlap 和 Ignore 唯一的区别在于，前者可以启用「生成重叠事件」，这样在重叠时（并且另一个对象没有 Ignore 自己）会触发「重叠事件」（如 `OnComponentBeginOverlap`、`OnComponentEndOverlap`）。
> - 仅当两个 Actor 之间都对对方 Block 时才有阻挡效果，但是需要启用「模拟生成命中事件」才能触发「命中事件」（如 `OnComponentHit`）。
>   - 如果希望两个 Actor 彼此阻挡，就都需要设置为阻挡相应的对象类型。
>   - 即使一个 Actor 会阻挡另一个 Actor，也可以生成重叠事件。
>   - 对于两个或更多模拟对象：如果一个设置为重叠对象，另一个设置为阻挡对象，则发生重叠，而不会发生阻挡。
> - 不建议一个对象同时拥有碰撞和重叠事件。虽然可以，但需要手动处理的部分太多。
>
> ——参考自[虚幻引擎官方文档：碰撞概述](https://dev.epicgames.com/documentation/zh-cn/unreal-engine/collision-in-unreal-engine---overview)

这里介绍两种设置碰撞预设的方式。

第一种是在 C++ 中借助 `CollisionSphere->SetCollisionResponseTo*()` 函数手动设置。

第二种是在编辑器的「项目设置」->「碰撞」->「预设」中加入自定义碰撞预设规则，比如命名一个自定义的预设描述文件为 `Projectile`，然后在 C++ 中调用 `SetCollisionProfileName("Projectile")` 即可。这里设置对所有物体都是 Block。

<img src="collisionprofile.png" style="zoom:50%">

## 碰撞事件

之后就是绑定 `OnComponentHit` 事件，做法是在 `BeginPlay()` 函数中绑定，同时设置对玩家实例 Ignore（防止误伤自己）。

> 如果在构造函数中绑定则不会生效。

```cpp RMagicProjectile.cpp
void ARMagicProjectile::BeginPlay()
{
  Super::BeginPlay();
  if (CollisionSphere)
  {
    // 这里可以通过在 SpawnActor() 中的 SpawnParam 参数里设置 Instigator 为玩家自身，从而方便投射物直接通过 GetInstigator() 获取玩家实例。 
    CollisionSphere->IgnoreActorWhenMoving(GetInstigator(), true);

    FScriptDelegate OnHitDelegate;
    OnHitDelegate.BindUFunction(this, FName("OnProjectileHit"));
    CollisionSphere->OnComponentHit.AddUnique(OnHitDelegate);
  }
}

void ARMagicProjectile::OnProjectileHit(UPrimitiveComponent* HitComponent, AActor* OtherActor, UPrimitiveComponent* OtherComp, FVector NormalImpulse, const FHitResult& Hit)
{
  // 粒子声明如下：
  // UPROPERTY(EditAnywhere)
  // UParticleSystem* BurstOnHitWorldParticle;
  // 从而能在编辑器中修改粒子效果
  UGameplayStatics::SpawnEmitterAtLocation(GetWorld(), BurstOnHitWorldParticle, GetActorTransform());
  Destroy();

  // TODO: 判断碰撞对象，如果是敌人，则实现「造成伤害」逻辑，以及生成其它粒子
}
```

我们自定义的命中事件触发函数必须是 UFUCNTION 修饰的，同时函数签名也需要和规定的一致。因为暂时没有设计战斗玩法，所以只是单纯地令其命中世界场景后生成 `BurstOnHitWorldParticle` 粒子，然后将自身销毁。