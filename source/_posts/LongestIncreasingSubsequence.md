---
title: 最长递增子序列 の O(nlogn)
author: Leager
mathjax:
  - true
date: 2023-09-06 14:23:27
summary:
categories:
  - algorithm
tags:
img:
---

**最长递增子序列**(Longest Increasing Subsequence, LIS) 是非常经典的一个算法问题。

<!--more-->

> 在计算机科学中，**最长递增子序列**（longest increasing subsequence）问题是指，在一个给定的数值序列中，找到一个子序列，使得这个子序列元素的数值依次递增，并且这个子序列的长度尽可能地大。最长递增子序列中的元素在原序列中不一定是连续的。许多与数学、算法、随机矩阵理论、表示论相关的研究都会涉及最长递增子序列。
>
> 例如，对于以下的原始序列：
>
> `0, 8, 4, 12, 2, 10, 6, 14, 1, 9, 5, 13, 3, 11, 7, 15`
>
> 最长递增子序列为
>
> `0, 2, 6, 9, 11, 15`
>
> 值得注意的是原始序列的最长递增子序列并不一定唯一，对于该原始序列，实际上还有以下三个最长递增子序列
>
> `0, 4, 6, 9, 11, 15`
>
> `0, 4, 6, 9, 13, 15`
>
> `0, 2, 6, 9, 13, 15`
>
> 【以上摘自 [**wikipedia**](https://zh.wikipedia.org/zh-cn/%E6%9C%80%E9%95%BF%E9%80%92%E5%A2%9E%E5%AD%90%E5%BA%8F%E5%88%97)】

## 动态规划求解

动态规划所使用的时间复杂度为 $O(n^2)$

令当前元素为 `x`，对于之前的每个比其小的元素 `y`，以 `x` 结尾的最长递增子序列 $\text{LIS}_x$ 都有可能是在以 `y` 结尾的 $\text{LIS}_y$ 基础上将 `x` 执行 append，即 $\text{LIS}_x = \text{LIS}_y.\text{append}(x)$。

若要使 `LISx` 最长，就必须找到一个最长的 $\text{LIS}_y$。假设状态 $\text{LEN}_x$ 表示 $\text{LIS}_x$ 的最大长度，那么有

$$
\text{LEN}_x = \max(\text{LEN}_{y_i}) + 1, \quad y_i < x
$$

转换成代码风格就是（以 C++ 代码为例）：

```cpp LIS_dp.cpp
for (int i = 1; i < n; i++) {
  int maxLength = 0;
  for (int j = 0; j < i; j++) {
    maxLength = max(maxLength, len[y]);
  }
  len[x] = maxLength + 1;
}
```

最后遍历所有元素结尾的 `LEN`，找到最大的那个即可。

### 缺点

动态规划方法的一个缺点在于——状态的**冗余**检查。极端情况下，如果一个序列严格递增，比如 `1, 2, 3, 4, 5, 6` ，那么其 `LIS` 就是本身，但在遍历到元素 `3` 的时候，其会把 $\text{LIS}_1$ 与 $\text{LIS}_2$ 都检查一遍。事实上， $\text{LIS}_2$ 包含了 $\text{LIS}_1$，对后者的检查是完全没有必要的。

更别说后面的 `4`, `5`, `6` 了。

> 需要找到一个方法来消除该冗余，最好是遍历到某一元素 `x` 时，我们已经知道 $\text{LIS}_x$ 与前面所有元素的关系。

## nlogn

换个思路，将所要存储的状态修改为「长度为 k 的 `LIS` 的最后一个元素」，看看事情是否有所转机？

以序列 `5, 1, 4, 2, 8, 7, 9, 0, 3, 6` 为例：

- `i = 0` 时，`lastElementWithLength[1]` 为 5，这很显然；

  > lastElementWithLength: 5

- `i = 1` 时，1 比 5 小，为了使后续元素更容易得到 append，将 `lastElementWithLength[1]` 改为 3；

  > lastElementWithLength: 1

- `i = 2` 时，4 比 1 大，可以作为递增子序列 `1, 4` 的最后一个元素，所以令 `lastElementWithLength[2]` 为 4；

  > lastElementWithLength: 1, 4

- `i = 3` 时，2 比 4 小，但比 1 大，根据前面的理论，将 `lastElementWithLength[2]` 改为 2。当然这并不是说前面的 `4` 就消失了，它依然可以作为递增子序列 `1, 4` 的一部分，但是一旦后续出现数字 `3`，它会更倾向于比自己小并且长度不低的 `2`；

  > lastElementWithLength: 1, 2


以此类推，我们最终可以得到这样一个 `lastElementWithLength` 数组：

|   1   |   2   |   3   |   4   |
| :---: | :---: | :---: | :---: |
|   0   |   2   |   3   |   6   |

可以得到 LIS 的长度为 4，并且以 `6` 结尾。

> LIS 为 `1, 2, 3, 6`

我们并不用在意之前有什么，只需要知道当前的元素必须被尽可能长的子序列 append 就可以了。对于那些末尾元素比自己还小的，肯定能进行 append 操作，而那些末尾元素比自身大的，则有可能取而代之，很典型的就是上面 `i=3` 时的情况。

事实上，在 `lastElementWithLength` 数组中，有且仅有第一个比自己大的那个元素 `first` 能进行取代，毕竟前面的那些再大也不会超过自身，`first` 也是在前者的基础上加入的数组，尽管取代了，也比之前的所有元素大。而后面的那些更大的元素，也必然是在 `first` 的基础上建立，其对应的递增子序列必然包含 `first`（或者更大的元素），一旦取代就会破坏 LIS 的规则。

所以问题又转变成了：在 `lastElementWithLength` 数组中找到第一个比自己大的元素。这不就**二分法**么？如果找不到，直接在末尾添加便是！

这样一来，遍历的过程中每个元素执行一次二分法，在最极端（也就是原始数组严格递增）的情况下也仅仅需要 $O(n\log n)$ 的时间复杂度，比起动态规划，开销大大降低。

## 应用

传送门：

1. [>>> LeetCode 354 俄罗斯套娃信封问题(Hard) <<<](https://leetcode.cn/problems/russian-doll-envelopes/)