---
title: GAMES101（现代图形学入门）の 作业记录
author: Leager
mathjax: true
date: 2024-04-19 17:16:19
summary:
categories: lab
tags: GAMES
img:
---

[>>> Github 传送门<<<](https://github.com/Leager-zju/GAMES101)

<!--more-->

## 环境搭建

使用平台：**Windows** + Vscode + MSYS2 + MinGW

### Eigen 库安装 & 编译

进入[下载地址](https://gitlab.com/libeigen/eigen/-/releases/)进行下载并解压。

```bash
cd /your/path/to/Eigen
mkdir build && cd build
cmake -G "Unix Makefiles" .. # windows 下默认生成 ninja，需要改为生成 makefile
make install -j8
```

然后会自动在 `C:/Program Files(x86)` 下生成一个名为 `eigen3` 的文件夹。也可以移到自己喜欢的地方，记为 `/your/path/to/eigen3`。

### opencv 库安装 & 编译

进入[下载地址](https://sourceforge.net/projects/opencvlibrary/files/opencv-win/)进行下载并双击 .exe 文件解压。

```bash
cd /your/path/to/opencv
cd sources
mkdir build && cd build
cmake -G "Unix Makefiles" -D WITH_OPENGL=ON -D ENABLE_CXX11=ON -D WITH_IPP=OFF -D ENABLE_PRECOMPILED_HEADERS=OFF ..
```

接下来用管理员权限运行 `make -j8 && make install -j8`。

会在 `sources/build/` 目录下生成一个名为 `install` 的目录，这就是我们所需要的目录，其他都可以忽略，记为 `your/path/to/opencv`

### 编译

CMakelists 参见相应分支。

❗ 注意：需要将 `your/path/to/opencv/x64/mingw/bin` 加入系统变量 PATH，否则链接阶段会找不到对应的动态库。

## Assignment1 透视投影

第一个作业要求实现透视投影的 MVP 三个矩阵。

### 旋转矩阵(Model)

这里要求实现按 $\mathbf{z}$ 轴旋转的矩阵。注意 `get_model_matrix(float rotation_angle)` 的参数是角度制，而使用 C++ 函数 `sin()`/`cos()` 时要转为弧度制。

实现如下：

```C++
// 角度转弧度
float angleToRadians(float angle) { return MY_PI*angle/180; }

// Create the model matrix for rotating the triangle around the Z axis.
// Then return it.
Eigen::Matrix4f get_model_matrix(float rotation_angle)
{
    // transform angle to radians
    float cosValue = cos(angleToRadians(rotation_angle));
    float sinValue = sin(angleToRadians(rotation_angle));
    Eigen::Matrix4f rotate;
    rotate << cosValue, -sinValue, 0, 0,
              sinValue, cosValue,  0, 0,
              0,        0,         1, 0,
              0,        0,         0, 1;
    return rotate;
}
```

### 平移矩阵(View)

这里其实就是将世界中所有物体同时平移，使得相机位于世界坐标的原点。`get_view_matrix(Eigen::Vector3f eye_pos)` 的参数是相机的初始位置。

实现如下

```C++
Eigen::Matrix4f get_view_matrix(Eigen::Vector3f eye_pos)
{
    Eigen::Matrix4f translate;
    translate << 1, 0, 0, -eye_pos[0],
                 0, 1, 0, -eye_pos[1],
                 0, 0, 1, -eye_pos[2],
                 0, 0, 0, 1;
    return translate;
}
```

### 投影矩阵(Projection)

这里需要我们实现透视投影矩阵，也是本次任务的难点所在。虽然课程中已经用数学方法推导出了矩阵，但这里还有一些不一样的地方：课程中的推导采用右手系，即相机在原点往 $\mathbf{z}$ 轴负方向看，此时矩阵中的 $n$ 和 $f$ 都应为负值。

而通过观察 `main()` 我们发现，这里 `get_projection_matrix(float eye_fov, float aspect_ratio, float zNear, float zFar)` 的两个参数 `zNear`/`zFar` 传入的都是正数。如果直接用这两个作为 $n$ 和 $f$，会发现结果出现三角形上下颠倒的问题（准确来说是与预期值在 $\mathbf{z}$ 轴上偏移了 180°）。

导致这一结果的原因在于，我们在推导过程中认为可视空间内某一点 $(x, y, z)$ 与近平面上的点 $(x', y', n)$ 应当存在这样一个关系

$$
x' = \frac{n}{z}x
$$

一旦 $n$ 和 $z$ 符号相反，就会出现 $x'$ 的值也相反，同理 $y'$ 的值也反了，那不就使得观测结果不符合预期了么。

我的做法是：依然采用**右手系**，不同的是需要将这两个参数理解为近/远平面离原点的距离，$n$ 和 $f$ 各取相应的负值，这样就能解决这一问题了。

```C++
Eigen::Matrix4f get_projection_matrix(float eye_fov, float aspect_ratio,
                                      float zNear, float zFar)
{
    // eye_fov: viewing angle in the range of [-eye_fov, eye_fov]
    // aspect_ratio: the height:width of viewing plane
    Eigen::Matrix4f squish;
    Eigen::Matrix4f translation;
    Eigen::Matrix4f scale;

    float n = -zNear;
    float f = -zFar;

    squish << n, 0, 0,   0,
              0, n, 0,   0,
              0, 0, n+f, -n*f,
              0, 0, 1,   0;
    
    float top = abs(n)*tan(angleToRadians(eye_fov/2));
    float bottom = -top;

    float right = top*aspect_ratio;
    float left = -right;

    translation << 1, 0, 0, -(left+right)/2,
                   0, 1, 0, -(top+bottom)/2,
                   0, 0, 1, -(n+f)/2,
                   0, 0, 0, 1;

    scale << 2/(right-left), 0,              0,       0,
             0,              2/(top-bottom), 0,       0,
             0,              0,              2/(n-f), 0,
             0,              0,              0,       1;

    return scale*translation*squish;
}
```

### BONUS: 按任意轴 axis 旋转

按照课程推导结果代入即可

```C++
Eigen::Matrix4f get_rotation(Vector3f axis, float angle)
{
    Eigen::Matrix4f K = Eigen::Matrix4f::Identity();
    float sinValue = sin(angleToRadians(angle));
    float cosValue = cos(angleToRadians(angle));
    float kx = axis[0];
    float ky = axis[1];
    float kz = axis[2];
    K << 0,   -kz, ky,
         kz,  0,   -kx,
         -ky, kx, 0;
    return Eigen::Matrix4f::Identity() + sinValue*K + (1-cosValue)*K*K;
}
```

### 总结

第一个作业难度甚至可以说低。唯一的难点在于对 `zNear` 和 `zFar` 的理解是否有误，这一点当时卡了我一定时间，解决该问题的同时对整个透视投影的理解也加深了许多。

## Assignment2 光栅化

## Assignment3 纹理与插值