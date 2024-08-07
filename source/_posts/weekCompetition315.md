---
title: LeetCode 周赛 315
author: Leager
mathjax: true
date: 2022-10-16 12:50:37
summary:
categories: leetcode
tags: weekly
img:
---

[第 315 场周赛](https://leetcode.cn/contest/weekly-contest-315/)复盘。

**排名** 2768 / 6490

<!--more-->

## 1. [与对应负数同时存在的最大正整数](https://leetcode.cn/problems/largest-positive-integer-that-exists-with-its-negative/)

> 给你一个 **不包含** 任何零的整数数组 `nums`，找出自身与对应的负数都在数组中存在的最大正整数 k 。
>
> 返回正整数 k ，如果不存在这样的整数，返回 -1 。
>

### 思路

遍历数组，对于负数，加入 set；对于正数，判断其对应的负数是否存在于 set 中，若存在则更新最大值。

遍历一遍是不够的，比如遇到 `nums = [1, -1]` 的情况就挂了，所以需要遍历两遍，第一遍建 set，第二遍查询，时间复杂度 $O(nlogn)$

也可以先对数组进行升序排序，这样负数就集中在左侧，正数集中在右侧，只需一次遍历即可。

### code

```go 与对应负数同时存在的最大正整数
func findMaxK(nums []int) int {
  mp := make(map[int]struct{})
  res := -1
  var null struct{}
  sort.Ints(nums)

  for _, num := range nums {
    if num < 0 {
      mp[num] = null
    } else if _, ok := mp[-num]; ok && num > res {
      res = num
    }
  }

  return res
}
```

## 2. [反转之后不同整数的数目](https://leetcode.cn/problems/count-number-of-distinct-integers-after-reverse-operations/)

> 给你一个由 **正** 整数组成的数组 `nums`。
>
> 你必须取出数组中的每个整数，**反转其中每个数位**，并将反转后得到的数字添加到数组的末尾。这一操作只针对 `nums` 中原有的整数执行。
>
> 返回结果数组中 **不同** 整数的数目。
>

### 思路

对原始数组中每一个值，将其和其反转后的数字加入 set，最后返回 set 大小即可。

### code

```go 反转之后不同整数的数目
func reverse(num int) int {
  res := 0
  for num > 0 {
    res = res * 10 + (num % 10)
    num /= 10
  }
  return res
}

func countDistinctIntegers(nums []int) int {
  mp := make(map[int]struct{})
  var null struct{}
  for _, num := range nums {
    mp[num] = null
    mp[reverse(num)] = null
  }
  return len(mp)
}
```

## 3. [反转之后的数字和](https://leetcode.cn/problems/sum-of-number-and-its-reverse/)

> 给你一个 **非负** 整数 `num`。如果存在某个 **非负** 整数 `k` 满足 `k + reverse(k) = num`  ，则返回 true ；否则，返回 false 。
>
> `reverse(k)` 表示 `k` 反转每个数位后得到的数字。

### 思路

直接无脑枚举即可。

### code

```go 反转之后的数字和
func reverse(num int) int {
  res := 0
  for num > 0 {
    res = res * 10 + (num % 10)
    num /= 10
  }
  return res
}

func sumOfNumberAndReverse(num int) bool {
  for i := 0; i <= num; i++ {
    if i + reverse(i) == num {
      return true
    }
  }
  return false
}
```

## 4. [统计定界子数组的数目](https://leetcode.cn/problems/count-subarrays-with-fixed-bounds/)

> 给你一个整数数组 `nums` 和两个整数 `minK` 以及 `maxK` 。
>
> `nums` 的定界子数组是满足下述条件的一个子数组：
>
> - 子数组中的 **最小值** 等于 `minK` 。
> - 数组中的 **最大值** 等于 `maxK` 。
>
> 返回定界子数组的数目。
>
> 子数组是数组中的一个连续部分。
>

参考了 [这位大佬的解法](https://leetcode.cn/problems/count-subarrays-with-fixed-bounds/solution/jian-ji-xie-fa-pythonjavacgo-by-endlessc-gag2/)，我认为这个解法是最完美的了，这里就对该思路进行一个解释。

他的思路基于以下性质：

1. 既然是求连续的子数组的个数，不妨对任意 `i`，考虑其作为数组右端点时能够产生的最大子数组个数；
2. 如果数组某一区间及其右端点固定，则包含该区间的连续子数组个数为该区间左端点左侧的元素个数 + 1；
3. 为了考虑到所有可能的情况，左端点必须尽可能靠近右端点；
4. 区间内所有值必须在 `[minK, maxK]` 范围内。

在 3 和 4 的约束下，左端点的坐标即 minK 和 maxK 上一次出现的坐标中的最小值。

再来看 2，区间不可能无限向左扩展，应该在遇到第一个不满足 `[minK, maxK]` 范围内的值时停下。

如果用 `minIndex, maxIndex, errIndex` 分别代表 minK、maxK 和 **范围外的值** 上一次出现的坐标。如果 errIndex 出现在左端点的右侧，则该区间无效，不进行考虑；反之，以 `i` 为右端点的子数组个数为
$$
\min(minIndex, maxIndex) - errIndex
$$

### code

```go 统计定界子数组的数目
func min(a, b int) int {
  if a < b {
    return a
  }
  return b
}
func countSubarrays(nums []int, minK int, maxK int) int64 {
  minIndex, maxIndex, errIndex := -1, -1, -1	     // -1 代表未出现
  res := 0
  for i, num := range nums {
    if num == minK {
      minIndex = i
    }
    if num == maxK {
      maxIndex = i
    }
    if num > maxK || num < minK {
      errIndex = i
    }
    leftIndex := min(minIndex, maxIndex)
    if leftIndex > errIndex {
      res += leftIndex - errIndex
    }
  }

  return int64(res)
}
```

