---
title: LeetCode 801. 使序列递增的最小操作次数
author: Leager
mathjax:
  - true
date: 2022-10-10 11:30:00
summary:
categories: leetcode
tags:
  - daily
img:
---

传送门 [>>> LeetCode 801(hard) <<<](https://leetcode.cn/problems/minimum-swaps-to-make-sequences-increasing/)

<!--more-->

> 我们有两个长度相等且不为空的整型数组 `nums1` 和 `nums2`。在一次操作中，我们可以交换 `nums1[i]` 和 `nums2[i]` 的元素。
>
> 例如，如果 `nums1 = [1,2,3,8], nums2 =[5,6,7,4]` ，你可以交换 `i = 3` 处的元素，得到 `nums1 =[1,2,3,4]` 和 `nums2 =[5,6,7,8]` 。
> 返回 使 `nums1` 和 `nums2` **严格递增** 所需操作的最小次数 。
>
> 数组 `arr` **严格递增** 是指  `arr[0] < arr[1] < arr[2] < ... < arr[arr.length - 1]`
>
> **注意**：用例保证可以实现操作。

## 最初的想法

首先，对于任意 `i`，我们有两种选择，交换 or 不交换。那么最开始，我们可以考虑定义一个数组 `dp[n]`，其中 `dp[i]` 表示前 `i+1` 个元素的子数组中**使序列递增的最小操作次数**。那么可以得到以下状态转移方程：

```go
if num1[i] <= nums1[i-1] || nums2[i] <= nums2[i-1] {
  dp[i] = dp[i-1] + 1
} else {
  dp[i] = dp[i-1]
}
```

但这种考虑存在一个漏洞：我们的考虑范围局限在了相邻两个元素之间的关系，却没有考虑到之前的元素。

比如当 `nums1 = [0,2,2], nums2 = [1,1,3]` 时，我们只需交换 `i = 1` 处的元素。而在上面的状态转移过程中，我们却得到了 `dp = [0, 1, 2]`——这显然不是我们想要的。而这一结果的成因在于，忽略了之前是否有交换。

## 改进

于是需要将 `dp[n]` 扩展到二维数组 `dp[n][2]`，`dp[i][0]` 表示对 `i` 处**不进行交换**时，前 `i+1` 个元素的子数组中使序列递增的最小操作次数；`dp[i][1]` 表示**进行交换**时的最小操作次数。这样一来，我们就能够对之前的交换情况进行考虑了。

既然题目保证最终能够实现操作，那么对任意 `i > 1`，必然存在以下情况：

1. `nums1[i] <= num1[i-1] || nums2[i] <= nums2[i-1]`

    这种情况下，`i` 处的交换情况必须与 `i-1` 处的交换情况相反，如果 `i-1` 换了，则 `i` 处无需交换；反之同理。有：
    $$
    \begin{align}
    dp[i][0] &= dp[i-1][1] \\[2ex] dp[i][1] &= dp[i-1][0] + 1
    \end{align}
    $$

2. `(nums1[i] > num1[i-1] && nums2[i] > nums2[i-1]) && (nums1[i] <= nums2[i-1] || nums2[i] <= nums1[i-1])`

    这种情况下，`i` 处的交换情况必须与 `i-1` 处的交换情况保持一致，也就是要么都交换，要么都不交换，则有：
    $$
    \begin{align}
    dp[i][0] &= dp[i-1][0] \\[2ex] dp[i][1] &= dp[i-1][1] + 1
    \end{align}
    $$

3. `(nums1[i] > num1[i-1] && nums2[i] > nums2[i-1]) && (nums1[i] > nums2[i-1] && nums2[i] > nums1[i-1])`

    这种情况下，`i` 处交不交换都无所谓，既然我们要最小操作，则有：
    $$
    \begin{align}
    dp[i][0] &= \min(dp[i-1][0], dp[i-1][1])\\[2ex] dp[i][1] &= dp[i][0] + 1
    \end{align}
    $$

于是代码就很清晰了

```go 使序列递增的最小操作次数
func min(a, b int) int {
  if a < b {
    return a
  }
  return b
}

func minSwap(nums1 []int, nums2 []int) int {
  n := len(nums1)
  dp := make([][]int, n)
  for i := 0; i < n; i++ {
    dp[i] = make([]int, 2)
  }

  dp[0][0] = 0
  dp[0][1] = 1
  for i := 1; i < n; i++ {
    if nums1[i] <= nums1[i-1] || nums2[i] <= nums2[i-1] {
      dp[i][0] = dp[i-1][1]
      dp[i][1] = dp[i-1][0] + 1
    } else if nums1[i] <= nums2[i-1] || nums2[i] <= nums1[i-1] {
      dp[i][0] = dp[i-1][0]
      dp[i][1] = dp[i-1][1] + 1
    } else {
      dp[i][0] = min(dp[i-1][0], dp[i-1][1])
      dp[i][1] = dp[i][0] + 1
    }
  }
  return min(dp[n-1][0], dp[n-1][1])
}
```

一看提交结果，看来还得优化。

> 执行用时：144 ms, 在所有 Go 提交中击败了 18.18% 的用户
>
> 内存消耗：19.7 MB, 在所有 Go 提交中击败了 9.09% 的用户

## 优化

注意到，每个 `dp[i]` 的状态只与 `dp[i-1]` 有关，之前的信息就被淘汰了，于是可以采用**滚动数组**的技巧优化空间。

```go 优化版本
func min(a, b int) int {
  if a < b {
    return a
  }
  return b
}

func minSwap(nums1 []int, nums2 []int) int {
  n := len(nums1)
  a, b := 0, 1
  for i := 1; i < n; i++ {
    if nums1[i] <= nums1[i-1] || nums2[i] <= nums2[i-1] {
      a, b = b, a + 1
    } else if nums1[i] <= nums2[i-1] || nums2[i] <= nums1[i-1] {
      b++
    } else {
      a = min(a, b)
      b = a + 1
    }
  }
  return min(a, b)
}
```

优化后，比较满意了。

> 执行用时：120 ms, 在所有 Go 提交中击败了68.18%的用户
>
> 内存消耗：9.6 MB, 在所有 Go 提交中击败了90.91%的用户
