---
title: GAMES101（现代图形学入门）の 笔记
author: Leager
mathjax: true
date: 2024-03-31 21:10:06
summary:
categories: note
tags: GAMES
img:
---

[>>>课程主页传送门<<<](https://sites.cs.ucsb.edu/~lingqi/teaching/games101.html)

<!--more-->

## 变换(Transformation)

变换分为两种：Modeling（平移、旋转、缩放等）和 Viewing（3D 投影到 2D）

### 模型变换(Modeling)

先讨论二维的情况。

> 在二维平面图上，所有的 modeling 都是基于原点 $(0, 0)$ 的。

#### 缩放(Scale)

对于原图像上任意一个点 $(x, y)$，其缩放后的坐标为 $(x', y') = (s_x·x, s_y·y)$。其中 $s_x, s_y$ 分别表示 $\mathbf{x}, \mathbf{y}$ 方向上的缩放倍率。

用线性代数的方式表示就是：

$$
\left(\begin{matrix}
x'\\ y'
\end{matrix}\right)
=
\left(\begin{matrix}
s_x & 0\\
0 & s_y
\end{matrix}\right)
\left(\begin{matrix}
x\\ y
\end{matrix}\right)
$$

#### 镜像(Reflection)

考虑下面这张图

<img src="reflection.png" style="zoom:50%"/>

我们也可以得到下面这样一个线性表达式：

$$
\left(\begin{matrix}
x'\\ y'
\end{matrix}\right)
=
\left(\begin{matrix}
-1 & 0\\
0 & 1
\end{matrix}\right)
\left(\begin{matrix}
x\\ y
\end{matrix}\right)
$$

#### 旋转(Rotate)

考虑下面这张图：

<img src="rotate.png" style="zoom:70%"/>

我们可以采用特值法，$(1, 0)\rightarrow(\cos{\alpha}, \sin{\alpha})\quad(0, 1)\rightarrow(-\sin{\alpha}, \cos{\alpha})$，代入 $\vec{a'}=\mathbf{M}\vec{a}$ 求解，从而得到：

$$
\left(\begin{matrix}
x'\\ y'
\end{matrix}\right)
=
\left(\begin{matrix}
\cos{\alpha} & -\sin{\alpha}\\
\sin{\alpha} & \cos{\alpha}
\end{matrix}\right)
\left(\begin{matrix}
x\\ y
\end{matrix}\right)
$$

> 这里如果改变旋转方向，从逆时针改为顺时针，那么矩阵 $\mathbf{M}$ 应该代入 $-\alpha$，得到
>
> $$
> \mathbf{M(-\alpha)} =
> \left(\begin{matrix}
> \cos{\alpha} & \sin{\alpha}\\
> -\sin{\alpha} & \cos{\alpha}
> \end{matrix}\right) = \mathbf{M}(\alpha)^T
> $$
>
> 事实上改变方向，角度不变的两个旋转应该互为逆操作，所以也有 $\mathbf{M(-\alpha)} = \mathbf{M(\alpha)}^{-1}$
>
> 易得，**旋转矩阵是一个正交矩阵**。

#### 切变(Shear)

考虑下面这张图：

<img src="shear.png" style="zoom:70%"/>

坐标在 $\mathbf{x}$ 方向上的偏移量与其纵坐标的大小有关，并且呈线性关系，同时纵坐标又不会发生偏移，那么很容易能够得到下面这个关系：

$$
\left(\begin{matrix}
x'\\ y'
\end{matrix}\right)
=
\left(\begin{matrix}
1 & a\\
0 & 1
\end{matrix}\right)
\left(\begin{matrix}
x\\ y
\end{matrix}\right)
$$

#### 齐次坐标与平移(Translation)

上面这些都属于线性变换，都可以通过 $\vec{a} = \mathbf{M}\vec{a}$ 的方式来表示，但这并不适用于“平移”操作，比如下面这张图：

<img src="translation.png" style="zoom:50%"/>

我们之前讨论的变换，不难发现图像在变换前后，$(0, 0)$ 处的点是不动的，但平移不然。我们似乎不能通过 $\vec{a} = \mathbf{M}\vec{a}$ 使得 $(x', y') = (x+t_x, y+t_y)$。换句话说，平移并非线性变换，其需要的“变换”应当为

$$
\left(\begin{matrix}
x'\\ y'
\end{matrix}\right)
=
\left(\begin{matrix}
a & b\\
c & d
\end{matrix}\right)
\left(\begin{matrix}
x\\ y
\end{matrix}\right)
+
\left(\begin{matrix}
t_x\\ t_y
\end{matrix}\right)
\tag{1}
$$

于是科学家引入了“齐次坐标”，对于二维的点/向量，为其增加第三个坐标 $w$。当 $w=1$ 时，表示点；$w=0$ 时，表示向量。

那么对于图像上任意一个点，对其进行平移操作，相当于做了下面这样的变换：

$$
\left(\begin{matrix}
x'\\ y'\\ w'
\end{matrix}\right)
=
\left(\begin{matrix}
1 & 0 & t_x\\
0 & 1 & t_y\\
0 & 0 & 1
\end{matrix}\right)
\left(\begin{matrix}
x\\ y\\ 1
\end{matrix}\right)
=
\left(\begin{matrix}
x+t_x\\ y+t_y\\ 1
\end{matrix}\right)
$$

得到的结果依然是一个“点”的形式。而对于向量而言，因为 $w=0$，那么有

- vector ± vector = vector
- point - point = vector
- point + vector = point

从而能够满足向量的平移不变性。

> 那么 point + point 呢？我们定义当 $w\neq0$ 时，$\left(\begin{matrix}x\\ y\\ w\end{matrix}\right)$ 等同于点 $\left(\begin{matrix}x/w\\ y/w\\ 1\end{matrix}\right)$。易得**两点相加得到该两点所成线段的中点**。

#### 仿射变换(Affine)

根据齐次坐标，我们能够把式(1)改写为：

$$
\left(\begin{matrix}
x'\\ y'\\ 1
\end{matrix}\right)
=
\left(\begin{matrix}
a & b & t_x\\
c & d & t_y\\
0 & 0 & 1
\end{matrix}\right)
\left(\begin{matrix}
x\\ y\\ 1
\end{matrix}\right)
=
\left(\begin{matrix}
ax+by+t_x\\ cx+dy+t_y\\ 1
\end{matrix}\right)
$$

即线性变换+平移。这样就用一个形式统一了所有的变换。

- **缩放**: $\mathbf{S}(s_x, s_y) = \left(\begin{matrix}s_x & 0 & 0\\ 0 & s_y & 0\\0 & 0 & 1\end{matrix}\right)$
- **旋转**: $\mathbf{R}(\alpha) = \left(\begin{matrix}\cos{\alpha} & -\sin{\alpha} & 0\\ \sin{\alpha} & \cos{\alpha} & 0\\0 & 0 & 1\end{matrix}\right)$
- **平移**: $\mathbf{T}(t_x, t_y) = \left(\begin{matrix}s_x & 0 & 0\\ 0 & s_y & 0\\0 & 0 & 1\end{matrix}\right)$

#### 逆变换(Inverse)

相当于左乘一个逆矩阵。

<img src="inverse.png" style="zoom:80%"/>

#### 对变换进行压缩(Composing Transforms)

根据上面的结论，**左乘**一个仿射矩阵相当于进行相应的变换。我们知道矩阵是有结合律的，一系列变换相当于不断左乘对应的矩阵，那么左侧所有矩阵的乘积就是这一系列变换的总和。

<img src="compose.png" style="zoom:60%"/>

再考虑下面两种情况：

1. 先平移后旋转；
2. 先旋转后平移；

两者得到的结果并不一样。这是**矩阵不满足交换律**导致的，即 $\mathbf{R}(\alpha)·\mathbf{T}(t_x, t_y) \neq \mathbf{T}(t_x, t_y)·\mathbf{R}(\alpha)$

如果希望图像围绕一个特定的点 $(x_0, y_0)$ 进行旋转，那么可以先平移至与原点对齐，旋转后再回到原来的位置，即

<img src="trt.png" style="zoom:60%"/>

#### 推广到三维空间

也是一样的，都需要进行一个坐标的拓展。对于三维坐标系而言，其仿射变换长下面这样：

$$
\left(\begin{matrix}
x'\\ y'\\ w'\\ 1
\end{matrix}\right)
=
\left(\begin{matrix}
a & b & c & t_x\\
d & e & f & t_y\\
g & h & i & t_z\\
0 & 0 & 0 & 1
\end{matrix}\right)
\left(\begin{matrix}
x\\ y\\ z\\ 1
\end{matrix}\right)
$$

- **缩放**: $\mathbf{S}(s_x, s_y, s_z) = \left(\begin{matrix}s_x & 0 & 0 & 0\\ 0 & s_y & 0 & 0\\ 0 & 0 & s_z & 0\\ 0 & 0 & 0 & 1\end{matrix}\right)$
- **旋转**（往轴负方向看逆时针）:

  - 绕 $x$ 轴：$\mathbf{R_x}(\alpha) = \left(\begin{matrix}1 & 0 & 0 & 0\\ 0 & \cos{\alpha} & -\sin{\alpha} & 0\\ 0 & \sin{\alpha} & \cos{\alpha} & 0\\ 0 & 0 & 0 & 1\end{matrix}\right)$
  - 绕 $y$ 轴：$\mathbf{R_y}(\alpha) = \left(\begin{matrix}\cos{\alpha} & 0 & \sin{\alpha} & 0\\ 0 & 1 & 0 & 0\\ -\sin{\alpha} & 0 & \cos{\alpha} & 0\\ 0 & 0 & 0 & 1\end{matrix}\right)$
  - 绕 $z$ 轴：$\mathbf{R_z}(\alpha) = \left(\begin{matrix}\cos{\alpha} & -\sin{\alpha} & 0 & 0\\ \sin{\alpha} & \cos{\alpha} & 0 & 0\\ 0 & 0 & 1 & 0\\ 0 & 0 & 0 & 1\end{matrix}\right)$
- **平移**: $\mathbf{T}(t_x, t_y, t_z) = \left(\begin{matrix}1 & 0 & 0 & t_x\\ 0 & 1 & 0 & t_y\\ 0 & 0 & 1 & t_z\\ 0 & 0 & 0 & 1\end{matrix}\right)$

三维空间的旋转比较特殊，因为需要考虑绕某个轴旋转（二维旋转可以视为有一条虚拟的 $z$ 轴，方向垂直纸面向外，所有的旋转都是绕该轴进行的）。

> 有的科学家用飞机来模拟三维空间的旋转，并为其进行命名：**roll**，**pitch**，**yaw**。
>
> <img src="eularangles.png" style="zoom:60%">

#### 罗德里格斯旋转公式(Rodrigues' Rotation Formula)

<details><summary>👈推导过程自行点击查看</summary>

设向量 $\mathbf{v}$ 绕**单位向量** $\mathbf{k}$ 旋转角度 $\theta$ 得到新向量 $\mathbf{v}_{rot}$

<img src="rodrigues.png"/>

如果将向量 $\mathbf{v}$ 分解为平行和垂直轴 $\mathbf{k}$ 的两个分量 $\mathbf{v_{\parallel}}$ 和 $\mathbf{v_{\bot}}$，不难发现只是对 $\mathbf{v_{\bot}}$ 作绕轴旋转，而 $\mathbf{v_{\parallel}}$ 不变，所以问题转换为求 $\mathbf{v}_{rot}$ 的垂直分量，记为 $\mathbf{v}_{rot\bot}$。可以很容易得到

$$
\mathbf{v}_{rot\bot} = \sin{\theta}(\mathbf{k}\times\mathbf{v}) + \cos{\theta}\mathbf{v}_{\bot}

$$

与此同时

$$
\mathbf{k}\times\mathbf{v} = \mathbf{k}\times(\mathbf{v}_{\parallel}+\mathbf{v}_{\bot}) = \mathbf{k}\times\mathbf{v}_{\parallel}+\mathbf{k}\times\mathbf{v}_{\bot} = \mathbf{0} + \mathbf{k}\times\mathbf{v}_{\bot} = \mathbf{k}\times\mathbf{v}_{\bot}

$$

继而问题又转换为求 $\mathbf{v_{\bot}}$。这里有一个比较 tricky 的性质：对于单位向量 $\mathbf{k}$ 而言，$\mathbf{k}\times\mathbf{v_{\bot}}$ 仅仅是将 $\mathbf{v_{\bot}}$ 绕轴旋转 90°。易得 $\mathbf{k}\times(\mathbf{k}\times\mathbf{v_{\bot}})$ 是绕轴旋转了 180°，所以有

$$
\mathbf{v}_{\bot} = -\mathbf{k}\times(\mathbf{k}\times\mathbf{v}_\bot) = -\mathbf{k}\times(\mathbf{k}\times\mathbf{v})

$$

那么我们就可以得到结论了

$$
\begin{align}
\mathbf{v}_{rot}
&= \mathbf{v}_{\parallel} + \mathbf{v}_{rot\bot}\\
&= \mathbf{v}-\mathbf{v}_{\bot} + \sin{\theta}(\mathbf{k}\times\mathbf{v}) + \cos{\theta}\mathbf{v}_{\bot}\\
&= \mathbf{v} + \sin{\theta}(\mathbf{k}\times\mathbf{v}) - (\cos{\theta}-1)\mathbf{k}\times(\mathbf{k}\times\mathbf{v})\\
&= \mathbf{v} + \sin{\theta}(\mathbf{k}\times\mathbf{v}) + (1-\cos{\theta})\mathbf{k}\times(\mathbf{k}\times\mathbf{v})\\
&= \mathbf{v} + \sin{\theta}\mathbf{K}·\mathbf{v} + (1-\cos{\theta})\mathbf{K}^2\mathbf{v}\\
&= [\mathbf{I} + \sin{\theta}\mathbf{K} + (1-\cos{\theta})\mathbf{K}^2]·\mathbf{v}
\end{align}

$$

</details>

最终得到绕单位向量 $\mathbf{k}$ 旋转角度 $\theta$ 对应的变换矩阵为

$$
\mathbf{R}(\mathbf{k}, \theta) = \mathbf{I} + \sin{\theta}\mathbf{K} + (1-\cos{\theta})\mathbf{K}^2

$$

其中 $\mathbf{K}$ 为由单位向量 $\mathbf{k}$ 生成的反对称矩阵，三维坐标下表示为

$$
\left(
    \begin{matrix}
    0 & -k_z & k_y \\
    k_z & 0 & -k_x \\
    -k_y & k_x & 0
    \end{matrix}
\right)

$$

### 观测变换(View)

#### 相机的放置

要做观测变换，首先要解决“**如何放置相机**”这一问题。一般由以下三个属性在空间中唯一确定一个相机：

1. **位置**(position)：$\vec{e}$；
2. **朝向**(gaze direction)：$\hat{g}$；
3. **上方**(up direction)：$\hat{t}$；

另外还有一个关键属性：**相对不变**。即如果相机和所有的物体保持同样的移动，那么得到的观测（照片）永远一致。常用的做法是将相机变换到下面这样的初始状态，其它物体也做同样的变换。

$$
\begin{aligned}
\vec{e} &= (0, 0, 0)\\
\hat{g} &= -\mathbf{z}\\
\hat{t} &= \mathbf{y}
\end{aligned}

$$

> 把人头当作相机，观测结果就是我们日常画的**二维坐标系**。上面这个是约定俗成的，能够使观测变容易。

#### 相机变换

为了让任意位置的相机都能达到初始状态，需要进行一定的变换（称之为 $\mathbf{M}_{view}$）

1. 将 $\vec{e}$ 移至原点；
2. 将 $\hat{g}$ 旋转至 $-\mathbf{z}$；
3. 将 $\hat{t}$ 旋转至 $\mathbf{y}$；
4. 将 $\hat{g}\times\hat{t}$ 旋转至 $\mathbf{x}$；

不难得到 $\mathbf{M}_{view} = \mathbf{R}_{view}\mathbf{T}_{view}$（先平移后旋转）。

其中

$$
\mathbf{T}_{view} =
\left(\begin{matrix}
1 & 0 & 0 & -x_e\\
0 & 1 & 0 & -y_e\\
0 & 0 & 1 & -z_e\\
0 & 0 & 0 & 1
\end{matrix}\right)
$$

那么旋转矩阵要如何表示呢？发现正着来不太好写，那不如倒着来，先考虑逆操作，即 $\mathbf{x}\rightarrow\hat{g}\times\hat{t},\quad \mathbf{y}\rightarrow\hat{t},\quad \mathbf{z}\rightarrow-\hat{g}$，分别代入特殊值可以得到

$$
\mathbf{R}_{view}^{-1} =
\left(\begin{matrix}
x_{\hat{g}\times\hat{t}} & x_{\hat{t}} & x_{-\hat{g}} & 0\\
y_{\hat{g}\times\hat{t}} & y_{\hat{t}} & y_{-\hat{g}} & 0\\
z_{\hat{g}\times\hat{t}} & z_{\hat{t}} & z_{-\hat{g}} & 0\\
0 & 0 & 0 & 1
\end{matrix}\right)
$$

之前我们讨论过，二维旋转矩阵是**正交矩阵**，其实这一性质对三维同样成立，所以有

$$
\mathbf{R}_{view} =
(\mathbf{R}_{view}^{-1})^T =
\left(\begin{matrix}
x_{\hat{g}\times\hat{t}} & y_{\hat{g}\times\hat{t}} & z_{\hat{g}\times\hat{t}} & 0\\
x_{\hat{t}} & y_{\hat{t}} & z_{\hat{t}} & 0\\
x_{-\hat{g}} & y_{-\hat{g}} & z_{-\hat{g}} & 0\\
0 & 0 & 0 & 1
\end{matrix}\right)
$$

### 投影变换(Projection)

<img src="projections.png" style="zoom:80%"/>

> 透视投影会形成视角锥，正交投影假设相机置于无穷远处。

#### 正交投影(Orthographic projection)

在计算机图形学中，为了节省计算资源，会定义一个**可视空间**，只有可视空间内的物体才需要进行绘制。正交投影定义的可视空间是一个**盒状可视空间**，本质上是三维物体的外切立方体，其长宽高分别由区间 $[f, n], [l, r], [b, t]$ 确定。

所谓正交投影，其实就是已知该可视空间内的任意点，将其垂直投影到 $xOy$ 平面并求解对应点的坐标。一种朴素的思路是直接舍弃 $z$ 坐标，但这样做在有前后遮挡的情况下会出现错误的绘制结果。

<img src="orth.png" style="zoom:50%"/>

现代化做法是像上图这样。首先将可视空间平移至以原点为空间中心，再对长宽高进行归一化。

不难得到两步操作之和的变换矩阵为

$$
\mathbf{M}_{ortho} =
\left(\begin{matrix}
\frac{2}{r-l} & 0 & 0 & 0\\
0 & \frac{2}{t-b} & 0 & 0\\
0 & 0 & \frac{2}{n-f} & 0\\
0 & 0 & 0 & 1
\end{matrix}\right)
\left(\begin{matrix}
1 & 0 & 0 & -\frac{r+l}{2}\\
0 & 1 & 0 & -\frac{t+b}{2}\\
0 & 0 & 1 & -\frac{n+f}{2}\\
0 & 0 & 0 & 1
\end{matrix}\right)
=
\left(\begin{matrix}
\frac{2}{r-l} & 0 & 0 & -\frac{r+l}{r-l}\\
0 & \frac{2}{t-b} & 0 & -\frac{t+b}{t-b}\\
0 & 0 & \frac{2}{n-f} & -\frac{n+f}{n-f}\\
0 & 0 & 0 & 1
\end{matrix}\right)
$$

> 归一化是因为，现实情况几乎所有的图形系统都把坐标系的空间范围限定在 $(-1,1)$ 范围内，这么做是为了方便移植，使坐标系独立于各种尺寸的图形设备。

> 我们这里是**右手系**，所以有反直觉的 $n>f$，有的引擎采用左手系（相机看向 $\mathbf{z}$ 正向），从而 $f>n$，更加符合直觉。

#### 透视投影(Perspective projection)

透视投影符合我们日常视角，即**近大远小**，且平行线不再平行，视觉效果看会收束到一个点。

闫神提供的解法是，将相机视锥形成的四棱台**压缩(squish)**成盒状，再应用正交投影即可。

<img src="squish.png" style="zoom:80%"/>

<details><summary>👈推导过程自行点击查看</summary>

对于视锥范围内的任意一点 $A(x, y, z)$，从原点作一条直线经过该点的直线（即视线），与近裁切面相交于点 $A'(x', y', z'=n)$。基于正交投影的性质，我们希望点 $A$ 在经过 squish 后的点 $B$ 满足 $x_B=x', y_B=y'$。

<img src="similarTriangle.png" style="zoom:60%"/>

根据相似三角形，不难得到

$$
\begin{aligned}
x'&=\frac{n}{z}x\\[2em]
y'&=\frac{n}{z}y
\end{aligned}
$$

在齐次坐标下，我们得到这样一个变换关系：

$$
\mathbf{M}_{squish}
\left(
\begin{matrix}
x \\ y \\ z \\ 1
\end{matrix}
\right)
=
\left(
\begin{matrix}
nx/z \\ ny/z \\ ? \\ 1
\end{matrix}
\right)
\overset{\times z}{\Longleftrightarrow}
\left(
\begin{matrix}
nx \\ ny \\ ? \\ z
\end{matrix}
\right)
$$

从而有

$$
\mathbf{M}_{squish}
=
\left(
\begin{matrix}
n & 0 & 0 & 0\\
0 & n & 0 & 0\\
? & ? & ? & ?\\
0 & 0 & 1 & 0
\end{matrix}
\right)
\overset{不妨设为}{==}
\left(
\begin{matrix}
n & 0 & 0 & 0\\
0 & n & 0 & 0\\
A & B & C & D\\
0 & 0 & 1 & 0
\end{matrix}
\right)
$$

接下来就是求 squish 矩阵的第三行元素。由于在 squish 前后，近裁切面和远裁切面上的所有点保持不变，所以我们可以代入两个特殊点进行求解，一个是近裁切面上的点 $(x, y, n)$，一个是远裁切面上的点 $(x, y, f)$，从而得到

$$
\left(
\begin{matrix}
n & 0 & 0 & 0\\
0 & n & 0 & 0\\
A & B & C & D\\
0 & 0 & 1 & 0
\end{matrix}
\right)
\left(
\begin{matrix}
x \\ y \\ n \\ 1
\end{matrix}
\right)
=
\left(
\begin{matrix}
nx \\ ny \\ Ax+By+Cn+D \\ n
\end{matrix}
\right)
=
\left(
\begin{matrix}
nx \\ ny \\ n^2 \\ n
\end{matrix}
\right)
\Leftrightarrow
\left(
\begin{matrix}
x \\ y \\ n \\ 1
\end{matrix}
\right)
$$

得到 $Cn+D = n^2$，同理 $Cf+D = f^2$，最终解得

$$
A=B=0,\ C=n+f,\ D=-nf
$$

即

$$
\mathbf{M}_{squish}
=
\left(
\begin{matrix}
n & 0 & 0 & 0\\
0 & n & 0 & 0\\
0 & 0 & n+f & -nf\\
0 & 0 & 1 & 0
\end{matrix}
\right)
$$

</details>

最终得到透视投影变换矩阵为

$$
\mathbf{M}_{persp} = \mathbf{M}_{ortho}\mathbf{M}_{squish}
\left(\begin{matrix}
\frac{2}{r-l} & 0 & 0 & -\frac{r+l}{r-l}\\
0 & \frac{2}{t-b} & 0 & -\frac{t+b}{t-b}\\
0 & 0 & \frac{2}{n-f} & -\frac{n+f}{n-f}\\
0 & 0 & 0 & 1
\end{matrix}\right)
\left(
\begin{matrix}
n & 0 & 0 & 0\\
0 & n & 0 & 0\\
0 & 0 & n+f & -nf\\
0 & 0 & 1 & 0
\end{matrix}
\right) \\
$$

> ❗提问：视锥内任意一点 $x, y, z$ 在 squish 后是靠近 $xOy$ 平面还是远离？
>
> 不妨代入式子求解，计算得到新的点为 $(nx/z, ny/z, n+f-nf/z)$，我们只需要判断 $n+f-nf/z$ 和 $z$ 的大小关系即可。
>
> 令 $f(z) = n+f-nf/z-z = -[z^2-(n+f)z+nf]/z = -[(z-n)(z-f)]/z$
>
> 当 $f \leq z \leq n < 0$ 时，$f(z) <= 0$ 恒成立，即 $n+f-nf/z \leq z$，表示**远离**。结论呼之欲出。

在上面我们定义了远近裁切面，并对其作了相应映射操作。但还有一个问题我们没有解决，那就是**如何定义近裁切面的大小**。

近裁切面其实就是相机的**视口(View Port)**，可以用两个参数：**视角(fovY, Field of View)**和**宽高比(Aspect Ratio)**来定义。

<img src="viewport.png" style="zoom:80%">

<img src="lrbt.png" style="zoom:80%">

当近裁切面在 $\mathbf{z}$ 轴上的坐标 $n$ 确定后，我们就能得到 squish 后的盒状可视空间的上下左右裁切面坐标值，从而正确应用正交投影的平移/缩放。

$$
\begin{aligned}
t &= |n|\tan{\frac{(fovY)}{2}} \\
b &= -t \\[1.5em]
r &= t·(aspect) \\
l &= -r
\end{aligned}
$$

## 光栅化(Rasterization)

### 屏幕映射

**屏幕**其实就是一个二维数组，数组的每一个元素是一个**像素(Pixel, Picture Element)**，可以用坐标 $(x, y)$ 表示，其像素中心坐标实际上是 $(x+0.5, y+0.5)$。

对于一个分辨率为 width\*height 的屏幕而言，其屏幕空间大小就是 width\*height，对应了 width\*height 大小的二维像素数组。

<img src="pixels.png" style="zoom:80%">

我们经过正交/透视投影变换后得到了一个归一化的立方体盒状可视空间（$[-1,1]^3$），需要将其 $xOy$ 平面上的点映射到屏幕空间（$[0, width]*[0, height]$）中。这一步很简单，缩放+平移即可，对应的变换矩阵为。

$$
\mathbf{M}_{viewport}
\left(
\begin{matrix}
\frac{width}{2} & 0 & 0 & \frac{width}{2}\\
0 & \frac{height}{2} & 0 & \frac{height}{2}\\
0 & 0 & 1 & 0\\
0 & 0 & 0 & 1
\end{matrix}
\right) \\
$$

万事俱备，我们只差将其变成真正的**图**，也就是说，要将视口中的多边形打散成像素，得到每个像素的值，真正将其画在屏幕上，这就是光栅化。

### 光栅化

大部分物体都会采用三角形来组合成对应的多边形，这是因为三角形：

1. 是最基础的多边形，任意多边形都可以拆分为若干三角形；
2. 能够唯一确定一个平面；
3. 有明确的内外之分，不存在凹三角形和凸三角形，所以**给定一个点可以唯一确定在三角形内部还是外部**；
4. **缺点**在于无法完美还原曲线；

<img src="dolphinTriangle.png" style="zoom:70%">

下面就以三角形为例，讲述光栅化的过程。

🙋‍♂️ 先进行一个提问：**已知屏幕空间内三个点的坐标值，如何根据这三个点构成的三角形，为像素数组赋合理的值呢？**

#### 采样(Sampling)

采样其实就是一个**离散化**的过程。比如下图，采样的思路是：如果一个像素的像素中心落在三角形的内部，那么就为这个像素赋予相应的值（三角形 RGB）。

<img src="sample.png" style="zoom:70%">

> 判断一个点 $O$ 是否落在三角形 $P_0P_1P_2$ 内很简单，只需要**三次叉乘**，如果 $\vec{OP_0}\times\vec{P_0P_1}, \vec{OP_1}\times\vec{P_1P_2}, \vec{OP_2}\times\vec{P_2P_0}$ 同号，则认为在内部，反之在外部。

> 实际上去遍历屏幕上的所有像素是没必要的，像上图左边的白色区域是肯定不会碰到三角形的，三角形肯定不会填充到这些像素上，只要考虑蓝色区域即可。蓝色区域就叫三角形的**轴对齐包围盒**，简称 **AABB(Axis-aligned bounding box)**。

#### 反走样(Antialiasing)

由于一个像素实际上会被填充为一个正方形，大部分情况下，采样的结果并不能完美地还原一个图形，反而容易产生**锯齿(Jaggies)**，比如下图。

<img src="jaggies.png" style="zoom:70%">

锯齿是**走样(Aliasing)问题**的其中一种表现形式，此外还有摩尔纹（空间采样）、车轮错觉（时间采样）等。本质原因都是：`<u>`信号（函数）变化太快，以至于采样速度跟不上`</u>`。

**反走样(Antialiasing)**就是为了解决这一问题所提出的。以三角形锯齿问题为例，我们可以先将其**模糊处理(Blurring)**，或者说**滤波(Pre-Filtering)**，再对模糊结果进行采样，这样就会有一些边界被采样成粉红色，而不是说只要像素中心不落在三角形内部就被采样成白色。

<img src="blur.png" style="zoom:70%">

❗ 注意**顺序不能颠倒**，这涉及到一些**频域(frequency domain)**相关的知识。可以明确的一点是：`<u>`采用同样的间隔进行采样，频率越高采样越不准确，所以更高频率的函数需要更密集的采样点`</u>`。比如下面，用相同的手段分别对黑色和蓝色的曲线进行采样，得到的结果是一样的，也就无法对其进行区分，从而导致走样。

<img src="diff.png" style="zoom:50%">

而模糊处理其实就是**低通滤波**，将高频信息滤掉，只通过低频分量，这样再做采样操作，就不容易在频域上发生混叠。

<img src="filter.png" style="zoom:50%">

最简单的操作就是，根据三角形在一个像素区域中的覆盖面积来决定采样结果。

<img src="sample2.png" style="zoom:50%">

那如何计算三角形覆盖的区域呢？有一种近似方法叫 **MSAA(MultiSampling Anti-Aliasing)**：对于任何一个像素 $P$，考虑其被划分成 $n$ 个小的像素 $p_i$，求 $P$ 被三角形覆盖的面积，实际上就是求有多少 $p_i$ 落在三角形内部，最后对结果除以 $n$，这就得到了一个近似的结果。比如下图，将像素划分为 4 个小像素。

<img src="22supersample.png" style="zoom:50%">
<img src="afterss.png" style="zoom:50%">
<img src="result.png" style="zoom:50%">

> 虽然效果不错，但实际上增加了 $n$ 倍的开销。实际上从工业的角度，人们并不是把一个像素规则的划分为 $n$ 个点，而是会用更加有效的图案去分布这些点，邻近的点还会被相邻的像素所复用，以减少开销。
>
> 还有一些重要的反走样方法，如 **FXAA(Fast Approximate AA)**、**TAA(Temporal AA)**。

这部分内容并没有“变换”那样涉及到大量公式，都是一些理论上的知识点，所以相对来说篇幅不是那么大。

## 着色(Shading)

在本课程中，着色的定义为：<u>对不同物体应用不同材质的过程</u>。

### 可见性(Visibility)

在屏幕映射这一部分中，我们说到将直接将多边形 $xOy$ 平面上的点映射到屏幕空间，但并没有考虑 $\mathbf{z}$ 轴方向上会出现的**遮挡(Occlusion)**问题。

#### 画家算法(👎)

这是人们最开始想到的一种朴素的做法：维护一个**帧缓存(Frame Buffer)** 存放屏幕空间的临时像素值，不断用更近的点覆盖原有的像素值，就像油画家的做法一样，最后将得到的 Frame Buffer 写入屏幕空间对应的像素数组，得到结果图像。

这种做法需要将所有的三角形进行排序（多边形拆成若干三角形），需要 $O(n\log{n})$ 的时间复杂度。**缺点**在于，一旦出现**循环覆盖**的情况，画家算法就失效了，比如下图，无法判断哪个三角形更近。

<img src="painter.png" style="zoom:50%">

#### Z-Buffer(👍)

Z-Buffer 是经过实践检验的优秀算法。它的基本思路是这样的：在维护**帧缓存(Frame Buffer)**的同时，额外维护一个**深度缓存(Depth Buffer, Z-Buffer)**。我们需要遍历可视空间内的所有三角形，对其进行采样，并保留被采样点的完整坐标信息。对于一个三角形的所有采样点，如果发现某个点 $(x, y, z)$ 对应的深度 $|z|$ 超过 $\text{Z-Buffer}(x, y)$，那么就将其舍弃，反之用该点信息更新两个 Buffer。虽然牺牲了一部分空间，却换来了**速度**（线性时间复杂度，无需关心顺序）与**鲁棒性**（解决了循环覆盖问题）。

> 同时，还可以根据像素深度进行额外的处理，如着色深浅。

<details> <summary>🤳伪代码</summary>

```pseudocode
for each triangle T
    for each sample(x, y, z) in T
        if (z < ZBuffer[x, y])
            FrameBuffer[x, y] = RGB
            ZBuffer = z
```

</details>

### Blinn-Phong 模型——Shading is Local

Blinn-Phong Model 是一个简单的着色模型，它计算<u>从点光源射出，在物体表面的一个点（即**着色点(Shading Point)**）上反射向相机的光</u>。

> 它将着色完全理想化，而不考虑物理真实性，因而没有太大的现实借鉴意义。

这里认为在一个局部比较小的范围内，着色点永远是一个平面。那么关于光的反射，需要定义以下内容：

1. 平面法线 $\mathbf{n}$；
2. 观测方向 $\mathbf{v}$；
3. 光照方向 $\mathbf{l}$；
4. 物体表面属性（如下面要提到的漫反射系数）；

<img src="shadingpoint.png" style="zoom:50%">

> **Shading is Local**，这句话的意思是，着色只会考虑这个着色点，以及光照和观测方向，不考虑其他物体的存在，所以没有阴影。

#### 漫反射(Diffuse Reflection)

对于**漫反射(Diffuse Reflection)**而言，光在着色点**均匀**地向四面八方反射，故此时观测结果与观测方向无关。

另外我们发现，当着色点平面法线方向和光线的夹角变化时，得到的观测结果明暗程度也会发生变化。根据光的波粒二象性，<u>光是具有能量的</u>，所以当 $\theta{\mathbf{n}, \mathbf{l}}$ 变化时，着色点在单位面积收到的**能量值**（光强度）也会有所变化。具体而言，光强度与 $\cos{\theta}=\mathbf{n}·\mathbf{l}$ 呈正相关。<u>我们判断物体的明暗程度，本质上就是判断该物体表面能接收到多少能量</u>。

<img src="nl.png" style="zoom:50%">

除了角度以外，点光源与着色点的**距离**也是决定光强度的一个重要因素。根据能量守恒定律，假设光的传播不会发生能量损耗，则以点光源为中心，半径 1 个单位长度的球体表面和半径 r 个单位长度的球体表面，两者所具有的能量应该是相等的。假设前者的光强度为 $I$，那么后者的光强度应该为

$$
I' = \frac{4\pi}{4\pi r^2} I = \frac{I}{r^2}
$$

基于以上讨论，Blinn-Phong 模型给出如下的漫反射公式：

$$
L_d = k_d·\frac{I}{r^2}·\max{(0, \mathbf{n}·\mathbf{l})}
$$

其中

- $L_d$ 为漫反射光强；
- $k_d$ 为**漫反射系数**，表示这个点对光的吸收率；
  
  > 对于一个点，它之所以会有颜色，是因为这个点会吸收一部分的颜色（能量），将那部分不吸收的能量进行反射。那不同的物体表面材质不同，因而有不同的**吸收率**，就会产生不同的反射光。当这个系数为 1 时，表示这个点完全不吸收能量；为 0 就表示所有能量都被吸收了。如果把这个系数表示为一个三通道的 RGB 颜色向量，那就可以在着色点上定义一个颜色了。
  >
  > 控制变量法得到的结果大概是下面这样
  >
  > <img src="diffuseresult.png" style="zoom:50%">

#### 高光(Specular)

当观测方向和光反射方向一致（或者说接近）时，能观测到高光。

> 这里不考虑漫反射，只谈**镜面反射**。

那么如何定义“接近”呢？假设反射光方向为 $\mathbf{R}$，则 $\theta{\mathbf{R},\mathbf{v}}$ 越小，表示越接近。但是 $\mathbf{R}$ 比较难求，Blinn-Phong 模型改为求解**半程向量** $\mathbf{h}$ 与法线 $\mathbf{n}$ 之间的夹角 $\alpha$。所谓半程向量，其实就是 $\mathbf{v}$ 与 $\mathbf{l}$ 的角平分线，有 $\displaystyle \mathbf{h}=\frac{\mathbf{v}+\mathbf{l}}{||\mathbf{v}+\mathbf{l}||}$ 。

<img src="specular.png" style="zoom:50%">

基于以上讨论，Blinn-Phong 模型给出如下的高光项公式：

$$
L_s = k_s\frac{I}{r^2}\max{(0, \mathbf{n}·\mathbf{h})}^p
$$

其中

- $L_s$ 为高光项光强；
- $k_d$ 为**高光项系数**，决定观测到的高光明暗程度；

> 🙋‍♂️ 之所以有一个指数 $p$，是因为需要对“接近程度”设置一个阈值，当 $p=1$ 时，即便 $\mathbf{h}$ 与 $\mathbf{n}$ 夹角达到了 45°，此时我们认为已经是相当偏离了，但余弦值为 $\sqrt{2}/2\approx 0.7$，还是能观测到比较明显的高光，这完全不符合我们的预期吧！
>
> 所以需要加入指数 $p$ 进行控制，使得夹角增大时，$(\cos{\alpha})^p$ 能够快速衰减，比如下图
>
> <img src="cosinePower.png" style="zoom:50%">
>
> 控制变量法得到的结果大概是下面这样（加入漫反射项）：
>
> <img src="specularresult.png" style="zoom:50%">

#### 环境光照(Ambient)

虽然有些点因为遮挡等因素，不会接收点光源的直射光，但是存在来自四面八方的、反射自其它物体表面的光，这就是**环境光(Ambient)**。

<img src="ambient.png" style="zoom:50%">

Blinn-Phong 模型给出的环境光项公式很简单：

$$
L_a = k_aI_a
$$

其中

- $L_a$ 为环境光强；
- $k_a$ 为**环境光系数**；
- $I_a$ 为光强，且假设任何一个点接收到来自环境的光强永远都是相同的；

不难发现，该模型的环境光强和 $\mathbf{l}, \mathbf{n}, \mathbf{v}$ 无关，是一个**常数**，保证了没有一个地方完全是黑的。事实上不是这么一回事，正如我之前说的，Blinn-Phong 只是一个简单的模型，如果要对环境光做精确求值，需要运用到**全局光照**的知识。

#### 总结

Blinn-Phong 模型下，我们最终能观测到的光强是以上三大项之和，即

$$
L = L_a+L_d+L_s = k_aI_a + k_d\frac{I}{r^2}\max{(0, \mathbf{n},\mathbf{l})}+k_s\frac{I}{r^2}\max{(0, \mathbf{n}·\mathbf{h})}^p 
$$

下面是一个简单的示例

<img src="blinnphongresult.png" style="zoom:50%">

❗ 再次强调，**Blinn-Phong 只是一个简单的模型，不具备物理真实性，没有太大的现实借鉴意义**。

### 着色频率(Shading Frequency)

选择着色频率，本质上是“如何选择着色点”的问题。下面的讨论中，我们认为物体表面由若干三角形的平面组成。

<img src="shadingFreq.png" style="zoom:50%">

#### Flat Shading

将着色应用到整个三角形上。对于一个三角形，我们只需对任意两条边作叉乘，即可求得法线，最后对三角形内部所有点作同样的着色处理。缺点是不够平滑。

#### Gouraud Shading

将着色应用到顶点上。对于物体表面任意一个顶点，其相邻的所有三角形为 $T_1, T_2, \dots$，这些三角形面积为 $S_1, S_2, \dots$，法线为 $\mathbf{n}_1, \mathbf{n}_2, \dots$，那么此顶点为着色点对应的法线为

$$
\mathbf{n} = \frac{S_1\mathbf{n}_1 + S_2\mathbf{n}_2 + \dots}{S_1 + S_2 + \dots}
$$

> 本质上是对所有法线作一个**加权平均**，权值为其面积，故面积越大的三角形，影响/贡献越大。

对于一个三角形，其三个顶点的着色已知，那么三角形内部应用插值即可。缺点是一旦某个三角形过大，着色效果就会不明显。

#### Phong Shading

将着色应用到像素上。首先对于三角形的每个顶点求出各自的法线，在三角形内部每一个像素上都插值出一个法线方向，对每一个像素进行一次着色，就会得到一个相对比较好的效果。

> 🤔 注意和 Blinn-Phong 区分。虽然都是同一个人发明的。

#### 总结

根据一开始放的图，在顶点数较少，即模型比较简单时，Phong 的效果无疑是最好的，但也要一定的开销。而当顶点数增大，模型逐渐复杂时，即便用相对简单的 Flat Shading 也能得到一个比较好的效果，因为此时一个平面的大小可能已经接近像素大小了。

### 实时渲染管线(Real-time Rendering PipeLine)

<img src="gpipe.png" style="zoom:50%">

1. 输入空间中的若干点；
2. 将这些点投影到屏幕上，定义连接关系，生成相应三角形；
3. 光栅化，形成不同的离散的**片元(fragment)**；
4. 考虑可见性与着色频率，将不同的片元进行着色；
5. 输出到显示器；

以上就是从三维场景到最后渲染出二维图片的基本操作，这些都是已经在 GPU 里写好了的。

> 🙋‍♂️ 提问：**为什么在管线中是先把三维空间中的点投影到屏幕上去，然后再把它连成三角形呢？**
>
> 定义空间物体时，首先定义顶点，再进行若干次定义由哪三个顶点构成小平面，这两步是将**直接定义所有的三角形**进行拆分，本质上是一样的，且三维空间投影到二维屏幕时，点与点之间的连接关系是不变的，所以我们只要对顶点进行操作就行。

### 纹理映射(Texture Mapping)

纹理映射解决了这样一个问题：**给定三角形，我们希望观察到的结果为，三角形内部填充了某一张图片**。

前面提到，对于一个表面，我们能够观察到不同颜色以及不同明暗程度，实际上是这个物体表面的属性发挥了作用——吸收一部分光，反射剩下的部分。我们能够看到物体表面仿佛填充了一张图片，本质上是**这个物体表面的不同点具有不同的属性**，这才是决定了不同观测结果的重要因素。

所以纹理映射的根本作用，就是**定义物体表面属性**。

那么如何定义呢？对于任意一个三维物体，其表面都可以通过某种方式转变成大小为 $1\times 1$ 的二维图像，那么只要我们得到任意一张图，就可以通过逆操作将其“贴”到三维物体上，这就是赋予纹理的过程。只要将三维物体表面的所有三角形平面，都在这个二维图像找到一一对应关系，那么我们就可以把“定义三维物体表面属性”简化为“定义二维图像表面属性”了。

<img src="texturemap.png" style="zoom:50%">

假设这种映射关系已经找到了。不难发现，任意一个三角形的顶点，在二维纹理图像 $\mathbf{uv}$ 上都有对应的坐标，