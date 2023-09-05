---
title: LeetCode 315. 计算右侧小于当前元素的个数
author: Leager
mathjax: true
date: 2023-09-05 12:43:25
summary:
categories:
    - LeetCode
tags:
    - 算法题
img:
---

传送门 [>>> LeetCode315(Hard) <<<](https://leetcode.cn/problems/count-of-smaller-numbers-after-self/)

<!--more-->

> 给你一个整数数组 `nums`，按要求返回一个新数组 `counts`。数组 `counts` 有该性质：`counts[i]` 的值是 `nums[i]` 右侧小于 `nums[i]` 的元素的数量。

## 暴力解法

从头遍历数组，对于当前下标 `i`，找到 `nums[0:i-1]` 中所有满足 `nums[j] > nums[i]` 的 `j`，然后令 `counts[j]++`。

但是一看到数组长度 $n$ 为 $10^5$ 的量级，$O(n^2)$ 显然是不行的，必须对时间开销进行压缩。

## 换个思路

不如试试从后往前遍历，对于每个遇到的 `nums[i]`，令其出现次数 `times[nums[i]]` 加一，那么对应的 `counts[i]` 就是

$$
\text{counts}[i] = \sum\limits_{j=\text{min\_element}(\text{nums})}^{\text{nums}[i]-1}\text{times}[j]
$$

在数据大小 $m$ 为 $10^4$ 量级的情况下，这个思路依然会 timeout，但是比暴力解法降低了不少开销。

“如果有什么方法能够节省计算 `counts[i]` 的时间就好了。”

脑子里这么想着。毕竟上面那个公式本质上是对一个区间进行求和，而区间左侧是固定的，只有右侧在变化，如果能找到一种数据结构或者算法，能够在低于 $O(m)$ 的复杂度下求出区间和，那么时间复杂度将会大大降低。

**前缀和**确实能实现这一点，但由于我们的查询是动态的，每遍历一个元素都要对整个数组进行修改，复杂度依然为 $O(m)$，这就有些力不从心了。

幸运的是，前人为我们发明了[**树状数组**](../../Data-Structure/树状数组)，其支持 $O(\log m)$ 级别的单点修改和区间查询，这样一来时间开销就能压下去了。但需要注意的是，由于存在负数，所以需要将所有元素做一个映射 $x\rightarrow x-\text{min\_element}$，这样就方便处理了。

> 本质上是一道模板题，但有助于理解这一数据结构。

## 代码

```c++
// C++
class Solution {
public:
    class bitTree {
        public:
            bitTree(int n_, int digit_): arr(n_+1), digit(digit_) {}

            int lowbit(int x) {
                return x & (-x);
            }

            void update(int idx, int diff) {
                while (idx < arr.size()) {
                    arr[idx] += diff;
                    idx += lowbit(idx);
                }
            }

            int rangeQuery(int idx) {
                int res = 0;
                while (idx) {
                    res += arr[idx];
                    idx -= lowbit(idx);
                }
                return res;
            }
        
        private:
            vector<int> arr;
            int digit;
    };

    vector<int> countSmaller(vector<int>& nums) {
        vector<int> res(nums.size());
        int maxm = INT_MIN, minm = INT_MAX;
        for (int n : nums) {
            if (n > maxm) {
                maxm = n;
            }
            if (n < minm) {
                minm = n;
            }
        }
        int size = maxm - minm;
        int n = 1;
        int digit = 0;
        while (n <= size) {
            n <<= 1;
            digit++;
        }

        bitTree bt(n, digit);
        for (int i = nums.size()-1; i >= 0; i--) {
            int idx = nums[i] - minm + 1; // map to [1, maxm-minm+1]
            res[i] = idx ? bt.rangeQuery(idx-1) : 0;
            bt.update(idx, 1);
        }

        return res;
    }
};
```