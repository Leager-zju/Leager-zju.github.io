---
title: LeetCode 周赛 316
author: Leager
mathjax:
  - true
date: 2022-10-23 13:39:34
summary:
categories: leetcode
tags:
  - weekly
img:
---

[第316场周赛](https://leetcode.cn/contest/weekly-contest-316/)复盘。

**排名** 873 / 6387

<!--more-->

## 1. [判断两个事件是否存在冲突](https://leetcode.cn/problems/determine-if-two-events-have-conflict/)

> 给你两个字符串数组 event1 和 event2，表示发生在 **同一天** 的两个闭区间时间段事件，其中：
>
> - `event1 = [startTime1, endTime1`]
>
> - `event2 = [startTime2, endTime2]`
>
> 事件的时间为有效的 24 小时制且按 `HH:MM` 格式给出。
>
> 当两个事件存在某个非空的交集时（即，某些时刻是两个事件都包含的），则认为出现 **冲突** 。
>
> 如果两个事件之间存在冲突，返回 true；否则，返回 false。
>

### 思路

用 `strconv.Atoi()` 将字符串转换为数字。

若 `endTime1 < startTime2` 或 `endTime2 < startTime1` 则认为无冲突。

### code

```go 判断两个事件是否存在冲突
func compare(a, b string) bool {  // a is earlier than b
  h1, _ := strconv.Atoi(a[:2])
  m1, _ := strconv.Atoi(a[3:])
  h2, _ := strconv.Atoi(b[:2])
  m2, _ := strconv.Atoi(b[3:])
  if h1 == h2 {
    return m1 < m2
  }
  return h1 < h2
}

func haveConflict(e1 []string, e2 []string) bool {
  start1, end1, start2, end2 := e1[0], e1[1], e2[0], e2[1]
  return !(compare(end1, start2) || compare(end2, start1))
}
```

## 2. [最大公因数等于 K 的子数组数目](https://leetcode.cn/problems/number-of-subarrays-with-gcd-equal-to-k/)

> 给你一个整数数组 nums 和一个整数 k ，请你统计并返回 nums 的子数组中元素的最大公因数等于 k 的子数组数目。
>
> **子数组** 是数组中一个连续的非空序列。
>
> **数组的最大公因数** 是能整除数组中所有元素的最大整数。

### 思路

若 $k$ 是 $\{a_1, a_2, \dots, a_n\}$ 的最大公因数，则 $gcd(k, a_{n+1})$ 是 $\{a_1, a_2, \dots, a_n, a_{n+1}\}$ 的最大公因数。

定义 `g[i][j]` 表示 `nums[i:j+1]` 的最大公因数，则 `g[i][j] = gcd(g[i][j-1], nums[j])`

### code

```go 最大公因数等于 K 的子数组数目
func gcd(a, b int) int {
  if a < b {
    return gcd(b, a)
  }
  if a % b == 0 {
    return b
  }
  return gcd(b, a%b)
}
func subarrayGCD(nums []int, k int) int {
  g := make([][]int, len(nums))
  for i := range g {
    g[i] = make([]int, len(nums))
  }
  cnt := 0
  for i := range nums {
    g[i][i] = nums[i]
    if g[i][i] == k {
      cnt++
    }
    for j := i+1; j < len(nums); j++{
      g[i][j] = gcd(g[i][j-1], nums[j])
      if g[i][j] == k {
        cnt++
      }
    }
  }
  return cnt
}
```

## 3. [使数组相等的最小开销](https://leetcode.cn/problems/minimum-cost-to-make-array-equal/)

> 给你两个下标从 **0** 开始的数组 nums 和 cost ，分别包含 n 个 **正** 整数。
>
> 你可以执行下面操作 **任意** 次：
>
> - 将 nums 中 **任意** 元素增加或者减小 1
>
> 对第 i 个元素执行一次操作的开销是 `cost[i]`。
>
> 请你返回使 nums 中所有元素 **相等** 的 **最少** 总开销。

### 思路

没做出来，看完 [题解](https://leetcode.cn/problems/minimum-cost-to-make-array-equal/solution/by-endlesscheng-i10r/) 发现我真的蠢。。。

### code

```go 使数组相等的最小开销
func minCost(nums, cost []int) int64 {
	type pair struct{ x, c int }
	a := make([]pair, len(nums))
	for i, x := range nums {
		a[i] = pair{x, cost[i]}
	}
	sort.Slice(a, func(i, j int) bool {
    a, b := a[i], a[j];
    return a.x < b.x
  })

	var total, sumCost int64
	for _, p := range a {
		total += int64(p.c) * int64(p.x-a[0].x)
		sumCost += int64(p.c)
	}
	ans := total
	for i := 1; i < len(a); i++ {
		sumCost -= int64(a[i-1].c * 2)
		total -= sumCost * int64(a[i].x-a[i-1].x)
		ans = min(ans, total)
	}
	return ans
}

func min(a, b int64) int64 {
  if a > b {
    return b
  }
  return a
}
```

## 4. [使数组相似的最少操作次数](https://leetcode.cn/problems/minimum-number-of-operations-to-make-arrays-similar/)

> 给你两个正整数数组 nums 和 target ，两个数组长度相等。
>
> 在一次操作中，你可以选择两个 **不同** 的下标 i 和 j ，其中 `0 <= i, j < nums.length` ，并且令
>
> - `nums[i] = nums[i] + 2`
> - `nums[j] = nums[j] - 2`
>
> 如果两个数组中每个元素出现的频率相等，我们称两个数组是 **相似** 的。
>
> 请你返回将 nums 变得与 target 相似的最少操作次数。测试数据保证 nums 一定能变得与 target 相似。

### 思路

因为必然会相似，则更大的一定会通过不断 **减二** 得到小的数，而更小的数一定会通过不断 **加二** 得到大的数，而为了使总操作更小，nums 中最小的数将变成 target 中最小的数，以此类推（所以需要进行排序）。因为这两步算 **同一次操作**，故考虑所有的"加二"操作即可。

同时还要考虑奇偶，因为奇数总是变成奇数，偶数总是变成偶数。

### code

```go 使数组相似的最少操作次数
func makeSimilar(nums []int, target []int) int64 {
  // 考虑奇偶
  n1, n2, t1, t2 := make([]int, 0), make([]int, 0), make([]int, 0), make([]int, 0)
  for _, n := range nums {
    if n % 2 != 0 {
      n1 = append(n1, n)
    } else {
      n2 = append(n2, n)
    }
  }
  for _, t := range target {
    if t % 2 != 0 {
      t1 = append(t1, t)
    } else {
      t2 = append(t2, t)
    }
  }

  sort.Ints(n1)
  sort.Ints(n2)
  sort.Ints(t1)
  sort.Ints(t2)

  var d1, d2 int64 = 0, 0
  for i := range n1 {
    if t1[i] > n1[i] {
      d1 += int64(t1[i]-n1[i])
    }
  }
  for i := range n2 {
    if t2[i] > n2[i] {
      d2 += int64(t2[i] - n2[i])
    }
  }
  return (d1+d2)/2
}
```

