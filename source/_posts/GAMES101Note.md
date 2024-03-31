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

对于原图像上任意一个点 $(x, y)$，其缩放后的坐标为 $(x', y') = (s_x·x, s_y·y)$。其中 $s_x, s_y$ 分别表示 $\vec{x}, \vec{y}$ 方向上的缩放倍率。

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

<img src="reflection.png"/>

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

<img src="rotate.png"/>

我们可以采用特值法，$(1, 0)\rightarrow(\cos{\theta}, \sin{\theta})\quad(0, 1)\rarr(-\sin{\theta}, \cos{\theta})$，代入 $\vec{a'}=\mathbf{M}\vec{a}$ 求解，从而得到：

$$
\left(\begin{matrix}
x'\\ y'
\end{matrix}\right)
=
\left(\begin{matrix}
\cos{\theta} & -\sin{\theta}\\
\sin{\theta} & \cos{\theta}
\end{matrix}\right)
\left(\begin{matrix}
x\\ y
\end{matrix}\right)
$$

#### 切变(Shear)

考虑下面这张图：

<img src="shear.png"/>

坐标在 $\vec{x}$ 方向上的偏移量与其纵坐标的大小有关，并且呈线性关系，同时纵坐标又不会发生偏移，那么很容易能够得到下面这个关系：

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

<img src="translation.png"/>

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

- **旋转**: $\mathbf{R}(\theta) = \left(\begin{matrix}\cos{\theta} & -\sin{\theta} & 0\\ \sin{\theta} & \cos{\theta} & 0\\0 & 0 & 1\end{matrix}\right)$

- **平移**: $\mathbf{T}(t_x, t_y) = \left(\begin{matrix}s_x & 0 & 0\\ 0 & s_y & 0\\0 & 0 & 1\end{matrix}\right)$

#### 逆变换(Inverse)

相当于左乘一个逆矩阵。

<img src="inverse.png"/>

#### 对变换进行压缩(Composing Transforms)

根据上面的结论，**左乘**一个仿射矩阵相当于进行相应的变换。我们知道矩阵是有结合律的，一系列变换相当于不断左乘对应的矩阵，那么左侧所有矩阵的乘积就是这一系列变换的总和。

<img src="compose.png"/>

再考虑下面两种情况：

1. 先平移后旋转；
2. 先旋转后平移；

两者得到的结果并不一样。这是**矩阵不满足交换律**导致的，即 $\mathbf{R}(\theta)·\mathbf{T}(t_x, t_y) \neq \mathbf{T}(t_x, t_y)·\mathbf{R}(\theta)$

如果希望图像围绕一个特定的点 $(x_0, y_0)$ 进行旋转，那么可以先平移至与原点对齐，旋转后再回到原来的位置，即

<img src="trt.png"/>

#### 高维仿射

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

四维五维同理。