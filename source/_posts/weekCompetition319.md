---
title: LeetCode 周赛 319
author: Leager
mathjax: true
date: 2022-11-15 11:35:42
summary:
categories: leetcode
tags: weekly
img:
---

[第319场周赛](https://leetcode.cn/contest/weekly-contest-319/)复盘。

**排名** 534 / 6175

<!--more-->

## 1. [2469. 温度转换](https://leetcode.cn/problems/convert-the-temperature/)

> 给你一个四舍五入到两位小数的非负浮点数 celsius 来表示温度，以 **摄氏度（Celsius）**为单位。
>
> 你需要将摄氏度转换为 **开氏度（Kelvin）**和 **华氏度（Fahrenheit）**，并以数组 `ans = [kelvin, fahrenheit]` 的形式返回结果。
>
> 返回数组 ans 。与实际答案误差不超过 $10^{-5}$ 的会视为正确答案。
>
> 注意：
>
> - 开氏度 = 摄氏度 + 273.15
> - 华氏度 = 摄氏度 * 1.80 + 32.00

### 思路

签到题

### code

```go
// go
func convertTemperature(celsius float64) []float64 {
    return []float64{celsius + 273.15, celsius * 1.8 + 32}
}
```

## 2. [2470. 最小公倍数为 K 的子数组数目](https://leetcode.cn/problems/number-of-subarrays-with-lcm-equal-to-k/)

> 给你一个整数数组 nums 和一个整数 k ，请你统计并返回 nums 的 **子数组** 中满足 元素最小公倍数为 k 的子数组数目。
>
> **子数组** 是数组中一个连续非空的元素序列。
>
> **数组的最小公倍数** 是可被所有数组元素整除的最小正整数。

### 思路

数据范围挺小的，直接暴力枚举即可，但也要注意剪枝。

### code

```go
// go
func gcd(a, b int64) int64{
    if a < b {
        return gcd(b, a);
    }
    if a % b == 0 {
        return b;
    }
    return gcd(b, a % b);
}
func lcm(a, b int64) int64{
    return a * b / gcd(a, b);
}
func subarrayLCM(nums []int, k int) int {
    res, i, j := 0, 0, 0
    for i < len(nums) {
        var l int64 = 1;	// 以 nums[i] 为起点的子数组的最小公倍数
        for j = i; j < len(nums); j++ {
            l = lcm(int64(nums[j]), l);
            if (int64(k) % l != 0) {	// 剪枝
                break;
            }
            if (int64(k) == l) {
                res++;
            }
        }
        i++;
    }

    return res;
}
```

## 3. [2471. 逐层排序二叉树所需的最少操作数目](https://leetcode.cn/problems/minimum-number-of-operations-to-sort-a-binary-tree-by-level/)

> 给你一个 **值互不相同** 的二叉树的根节点 root 。
>
> 在一步操作中，你可以选择 **同一层** 上任意两个节点，交换这两个节点的值。
>
> 返回每一层按 **严格递增顺序** 排序所需的最少操作数目。
>
> 节点的 **层数** 是该节点和根节点之间的路径的边数。
>

### 思路

用二维切片记录每一层的数据 `level[]`，对当前层而言，开一个额外数组记录每个元素 `level[i]` 在排序后的最终位置 `pos[level[i]]`，不断交换 `level[i]` 与 `level[pos[level[i]]]` 即可。

### code

```go
// go
/**
 * Definition for a binary tree node.
 * type TreeNode struct {
 *     Val int
 *     Left *TreeNode
 *     Right *TreeNode
 * }
 */
func minimumOperations(root *TreeNode) int {
    order := make([][]*TreeNode, 0)

    order = append(order, []*TreeNode{root})
    for i := 0; i < len(order); i++ {
        level := make([]*TreeNode, 0)
        for _, r := range order[i] {
            if r.Left != nil {
                level = append(level, r.Left)
            }
            if r.Right != nil {
                level = append(level, r.Right)
            }
        }
        if len(level) > 0 {
            order = append(order, level)
        }
    }

    res := 0
    for _, level := range order {
        if len(level) == 1 {
            continue
        }
        temp := make([]*TreeNode, len(level))
        for i := range temp {
            temp[i] = level[i]
        }
        sort.Slice(temp, func(i, j int) bool {
            return temp[i].Val < temp[j].Val
        })

        pos := make(map[int]int)
        for i := range temp {
            pos[temp[i].Val] = i
        }
        for i := range level {
            for level[pos[level[i].Val]] != level[i] {
                level[i], level[pos[level[i].Val]] = level[pos[level[i].Val]], level[i]
                res++
            }
        }
    }

    return res
}
```

## 4. [2472. 不重叠回文子字符串的最大数目](https://leetcode.cn/problems/maximum-number-of-non-overlapping-palindrome-substrings/)

> 给你一个字符串 s 和一个 **正** 整数 k 。
>
> 从字符串 s 中选出一组满足下述条件且 **不重叠** 的子字符串：
>
> - 每个子字符串的长度 **至少** 为 k 。
> - 每个子字符串是一个 **回文串** 。
>
> 返回最优方案中能选择的子字符串的 **最大** 数目。
>
> **子字符串** 是字符串中一个连续的字符序列。

### 思路

首先用一个二维数组 `isPalid[i][j]` 记录子字符串 `s[i] ~ s[j]` 是否为回文串。定义 `dp[i]` 表示字符串 `s[:i]` 中不重叠回文子字符串的最大数目。那么状态转移方程可以表示为：

1. 若 `s[j:i] (0 <= j <= i-k)` 为回文串，则 `dp[i] = max(do[i], dp[j] + 1) `；
2. 反之，`dp[i] = dp[i-1]`。

### code

```go
// go
func maxPalindromes(s string, k int) int {
    isPalid := make([][]bool, len(s))
    for i := range isPalid {
        isPalid[i] = make([]bool, len(s))
        isPalid[i][i] = true
        if i < len(s)-1 && s[i] == s[i+1] {
            isPalid[i][i+1] = true
        }
    }

    for l := 3; l <= len(s); l++ {
        for i := 0; i <= len(s) - l; i++ {
            isPalid[i][i+l-1] = (s[i] == s[i+l-1] && isPalid[i+1][i+l-2])
        }
    }

    dp := make([]int, len(s)+1)     // dp[i]: 前 i 个字符最大的回文子字符串数
    if isPalid[0][k-1] {
        dp[k] = 1
    }
    for i := k + 1; i <= len(s); i++ {
        for j := i-k; j >= 0; j-- {
            if isPalid[j][i-1] {
                dp[i] = max(dp[i], dp[j] + 1)
            }
        }
        dp[i] = max(dp[i], dp[i-1])
    }
    fmt.Println(dp)
    return dp[len(s)]
}

func max(i, j int) int {
    if i > j {
        return i
    }
    return j
}
```

