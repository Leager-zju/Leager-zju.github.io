---
title: LeetCode 1653. 使字符串平衡的最少删除次数
author: Leager
mathjax: true
date: 2023-03-06 11:59:32
summary:
categories:
    - LeetCode
tags:
    - 每日一题
img:
---

传送门 [>>> 2023.3.6 每日一题 LeetCode1653(Medium) <<<](https://leetcode.cn/problems/minimum-deletions-to-make-string-balanced/)

<!--more-->

> 给你一个字符串 s ，它仅包含字符 `'a'` 和 `'b'​​​`​。
>
> 你可以删除 s 中任意数目的字符，使得 s **平衡** 。当不存在下标对 $(i, j)$ 满足 $i < j$，且 `s[i] = 'b'` 的同时 `s[j]= 'a'` ，此时认为 s 是 **平衡** 的。
>
> 请你返回使 s **平衡** 的 **最少** 删除次数。

## 思考

题目意思就是通过删除操作，使得字符串中所有字符 `'a'` 均在 `'b'` 的左侧。定义一个变量 `result` 表示**遍历到下标 `i` 时，`s[0:i]` 通过删除达到平衡的最少次数**，那么根据当前字符不同，我们进行如下思考：

1. 若 `s[i] == 'a'`，则有两种选择：
   - **删除**：只需简单地令 `result = result + 1` 即可；
   - **保留**：意味着原始字符串下 `s[0, i-1]` 中所有 `'b'` 均需被删除——这也是一种使得子串平衡的方法——而不能简单地使用前一个下标计算得到的结果，此时 `result = #('b')`；
 
    在这两种选择中取最小值即可。

    > 举个例子，对于字符串 `"baabbaaa"` 而言，通过删除最右侧的 `'a'` 的代价并不会比直接删除所有 `'b'` 的代价低。这在右侧 `'a'` 的数量激增时更明显。本质原因在于保留 `'b'` 的代价相当于删除其右侧所有 `'a'`。

2. 若 `s[i] == 'b'`，则无需删除，因为这个字符必然在**已达成平衡的字符串**的最右侧，直接保留即可。

## 代码

```c++
// C++
class Solution {
public:
    int minimumDeletions(string s) {
        int numOfb = 0;
        int result = 0;

        for (auto&& c : s) {
            if (c == 'a') {
                result = min(numOfb, result + 1);
            } else {
                numOfb++;
            }
        }

        return result;
    }
};
```