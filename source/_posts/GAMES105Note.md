---
title: 计算机角色动画基础（GAMES105）の 笔记
author: Leager
mathjax:
  - true
date: 2025-06-18 16:20:53
summary:
categories:
  - Note
tags:
img:
---

无论是渲染还是动画都离不开**数学**这一道坎，于是单独拎出来记录。

<!--more-->

## 线性代数基础

线性代数的基础是二维的**向量**和三维的**矩阵**。向量可以用来获取方向和长度，也可以认为是点在坐标系中的位置；而矩阵则一般被视为某种变换手段，左乘一个列向量可以将其转变成新的向量。

### 向量相关

已知三维向量 $\mathbf{a}=[a_x, a_y, a_z]^T$ 和三维向量 $\mathbf{b} = [b_x, b_y, b_z]^T$。

#### 向量运算

已知向量之间的夹角为 $\theta$。

**点乘**：$\mathbf{a}·\mathbf{b} = \lVert\mathbf{a}\rVert \lVert\mathbf{b}\rVert\cos\theta = a_x b_x + a_y b_y + a_z b_z$

> 可以视为向量在另一个向量上的投影长度。

**叉乘**：$\mathbf{a}\times\mathbf{b} = \lVert\mathbf{a}\rVert \lVert\mathbf{b}\rVert\sin\theta ·\mathbf{u} = \left[\begin{matrix} a_y b_z - a_z b_y \\ a_z b_x - a_x b_z \\ a_x b_y - a_y b_x \end{matrix}\right] = \det\left[\begin{matrix} \mathbf{i} & \mathbf{j} & \mathbf{k} \\ a_x & a_y & a_z \\ b_x & b_y & b_z\end{matrix}\right]$

> 可以视为两个向量基于**右手定则**计算出的两个向量所在平面的法向量，其中 $\mathbf{u}$ 是单位法向量。

叉乘运算也可以等价为一个**反对称矩阵**乘运算符右侧的向量，即

$$
\mathbf{a}\times\mathbf{b}=
\left[\begin{matrix}
  0 & -a_z & a_y \\
  a_z & 0 & -a_x \\
  -a_y & a_x & 0
\end{matrix}\right]
\left[\begin{matrix}
  b_x \\
  b_y \\
  b_z
\end{matrix}\right]
=
[\mathbf{a}]_{\times}\mathbf{b}
$$

> 这里的 $[\mathbf{a}]_{\times}$ 一般称为向量 $\mathbf{a}$ 的**叉乘矩阵**。

#### 罗德里格斯旋转公式(Rodrigues' Rotation Formula)

该公式旨在解决这一问题：求向量 $\mathbf{a}$ 绕旋转轴 $\mathbf{u}$ 旋转角度 $\theta$ 得到的新向量 $\mathbf{b}$

<details>
<summary>👈推导过程自行点击查看</summary>

> <img src="rodrigues.png"/>
> 
> 我们可以将旋转看成是向量端点在某个平面上产生的位移，此时不妨令向量 $\mathbf{b} = \mathbf{a} + \mathbf{v} + \mathbf{t}$，其中 $\mathbf{v}, \mathbf{t}$ 分别与向量 $\mathbf{u}\times\mathbf{a}$ 与 $\mathbf{u}\times(\mathbf{u}\times\mathbf{a})$ 共向，且在该旋转平面上。
>
> 因为端点运动轨迹在平面上是一个圆，所以向量 $\mathbf{a}, \mathbf{b}$ 在该平面上的投影长度实际上是圆的半径，二者相等，为 $\lVert\mathbf{a}\rVert\sin(\mathbf{u}, \mathbf{a}) = \lVert\mathbf{u}\times\mathbf{a}\rVert$
>
> 此时可以得出向量 $\mathbf{v}, \mathbf{t}$ 的长度，分别如图所示。
> 
> 将长度乘上对应的方向单位向量，能得到
>
> $$
> \begin{align}
>  \mathbf{v} &= \sin\theta\ \mathbf{u}\times\mathbf{a}\\
>  \mathbf{t} &= (1-\cos\theta)\ \mathbf{u}\times(\mathbf{u}\times\mathbf{a})
> \end{align}
> $$

</details>

结论为

$$
\mathbf{b} = \mathbf{a} + \sin\theta\ \mathbf{u}\times\mathbf{a} + (1-\cos\theta)\ \mathbf{u}\times(\mathbf{u}\times\mathbf{a})
$$

专成对应的叉乘矩阵形式就是

$$
\mathbf{b} = [\mathbf{I} + \sin\theta[\mathbf{u}]_{\times} + (1-\cos\theta)[\mathbf{u}]_{\times}^2]·\mathbf{a}
$$


最终得到绕单位向量 $\mathbf{u}$ 旋转角度 $\theta$ 对应的变换矩阵为

$$
\mathbf{R}(\mathbf{u}, \theta) = \mathbf{I} + \sin\theta[\mathbf{u}]_{\times} + (1-\cos\theta)[\mathbf{u}]_{\times}^2
$$

### 矩阵相关

游戏中用到最多的变换操作就是**平移**、**旋转**、**缩放**，而其中的难点在于旋转操作。

#### 旋转变换

旋转本质上是对列向量左乘一个矩阵 $\mathbf{R}$（或行向量右乘）。

考虑到对物体的旋转是可逆的，且旋转及其逆操作并不会改变物体，因此有 $\mathbf{R}^{-1}\mathbf{R} = \mathbf{I}$，即旋转矩阵是一个**正交矩阵**。

特别的，我们可以得到绕 $\mathbf{x}, \mathbf{y}, \mathbf{z}$ 三个坐标轴旋转的旋转矩阵如下：

$$
\mathbf{R_x}(\alpha) = 
\left[
  \begin{matrix}
  1 & 0 & 0\\
  0 & \cos{\alpha} & -\sin{\alpha}\\
  0 & \sin{\alpha} & \cos{\alpha}
  \end{matrix}
\right]
\\[5ex]
\mathbf{R_y}(\beta) =
\left[
  \begin{matrix}
  \cos{\beta} & 0 & \sin{\beta}\\
  0 & 1 & 0\\
  -\sin{\beta} & 0 & \cos{\beta}
  \end{matrix}
\right]
\\[5ex]
\mathbf{R_z}(\gamma) =
\left[
  \begin{matrix}
  \cos{\gamma} & -\sin{\gamma} & 0\\ \sin{\gamma} & \cos{\gamma} & 0\\ 0 & 0 & 1
  \end{matrix}
\right]
$$

而绕非坐标轴的某个向量 $\mathbf{u}$ 旋转，则可以通过前文提到的 Rodrigues 公式进行计算。

## 更多旋转操作

