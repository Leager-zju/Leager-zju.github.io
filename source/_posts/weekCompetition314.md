---
title: LeetCode 周赛 314
author: Leager
mathjax: true
date: 2022-10-09 19:34:27
summary:
categories:
    - LeetCode
tags:
    - 周赛
img:
---

[第 314 场周赛](https://leetcode.cn/contest/weekly-contest-314/)复盘。

**排名** 1130 / 4838

<!--more-->

## 1. [处理用时最长的那个任务的员工](https://leetcode.cn/problems/the-employee-that-worked-on-the-longest-task/)

> 共有 n 位员工，每位员工都有一个从 0 到 n - 1 的唯一 id。
>
> 给你一个二维整数数组 `logs`，其中 `logs[i] = [id_i, leaveTime_i]`：
>
> `id_i` 是处理第 i 个任务的员工的 id，且 `leaveTime_i` 是员工完成第 i 个任务的时刻。所有 `leaveTime_i` 的值都是 **唯一** 的。
>
> 注意，第 i 个任务在第 i - 1 个任务结束后立即开始，且第 0 个任务从时刻 0 开始。
>
> 返回处理用时最长的那个任务的员工的 id。如果存在两个或多个员工同时满足，则返回几人中 **最小** 的 id。

### 思路

找使得 `log[i][1] - log[i-1][1]` 最大的 `log[i]`，并取其中最小的那个 `log[i][0]`

### code

```go
// go
func hardestWorker(n int, logs [][]int) int {
    res, max := logs[0][0], logs[0][1]
    
    for i := 1; i < len(logs); i++ {
        diff := logs[i][1] - logs[i-1][1]
        if diff > max {
            max = diff
            res = logs[i][0]
        } else if diff == max && res > logs[i][0] {
            res = logs[i][0]
        }
    }
     
    return res
}
```



## 2. [找出前缀异或的原始数组](https://leetcode.cn/problems/find-the-original-array-of-prefix-xor/)

>给你一个长度为 n 的 **整数** 数组 `pref` 。找出并返回满足下述条件且长度为 n 的数组 `arr`：
>
>`pref[i] = arr[0] ^ arr[1] ^ ... ^ arr[i]`
>
>注意 ^ 表示 按位异或运算。

### 思路

`pref[i+1] = pref[i] ^ arr[i]`，两边同时异或 `pref[i]`，得到 `arr[i] = pref[i] ^ pref[i+1]`

### code

```go
// go
func findArray(p []int) []int {
    res := make([]int, len(p))
    res[0] = p[0]
    
    for i := 1; i < len(p); i++ {
        res[i] = p[i] ^ p[i-1]
    }
    
    return res
}
```



## 3. [使用机器人打印字典序最小的字符串](https://leetcode.cn/problems/using-a-robot-to-print-the-lexicographically-smallest-string/)

>给你一个字符串 s 和一个机器人，机器人当前有一个空字符串 t。执行以下操作之一，直到 s 和 t 都变成空字符串：
>
>删除字符串 s 的 **第一个** 字符，并将该字符给机器人。机器人把这个字符添加到 t 的尾部。
>
>删除字符串 t 的 **最后一个** 字符，并将该字符给机器人。机器人将该字符写到纸上。
>
>请你返回纸上能写出的字典序最小的字符串。

### 思路

题目可以转为，给定一个字符串的入栈顺序，求所有出栈顺序中字典序最小的那个。所以需要把 t 等效为栈。

我们需要遍历 s，同时，在任意时刻，对于 t 栈顶（尾部）的字符而言：

1. 如果 s 中尚存的字符中没有比它更小的，则将其 append 到结果字符串的末尾（写到纸上）；

    > 不难证明，这样贪心的做法一定会使字典序最小。

2. 反之，先将其加入栈中（添加到 t 的尾部），最后一并写出。

可以用一个数组 `minm[]` 来表示 s 的当前 index 到末尾这一子串中 ASSIC 码最小的字符，那么 (1) 中的比较就变成了 `t.top()` 与 `minm[i]` 之间的比较。

### code

```c++
// c++
class Solution {
public:
    string robotWithString(string s) {
        int n = s.length();
        vector<char> minm(n);
        stack<char> t;
        string res;
        
        minm[n-1] = s[n-1];
        for (int i = n-2; i >= 0; i--) {
            minm[i] = s[i] < minm[i+1] ? s[i] : minm[i+1];
        }        
        
        for (int i = 0; i < n-1; i++) {
            t.push(s[i]);	// 删除 s 的第一个字符并添加到 t 的尾部
            while (!t.empty() && t.top() <= minm[i+1]) {	// 若后面没有比 t 尾部字符更小的，写到纸上
                res.push_back(st.top());
                t.pop();
            }
        }
        
        // 将 t 中所有字符写到纸上
        res.push_back(s[n-1]);
        while (!t.empty()) {
            res.push_back(t.top());
            t.pop();
        }
        
        return res;
    }
};
```



## 4. [矩阵中和能被 K 整除的路径](https://leetcode.cn/problems/paths-in-matrix-whose-sum-is-divisible-by-k/)

> 给你一个下标从 0 开始的 m x n 整数矩阵 grid 和一个整数 k 。你从起点 (0, 0) 出发，每一步只能往 **下** 或者往 **右** ，你想要到达终点 (m - 1, n - 1) 。
>
> 请你返回路径和能被 k 整除的路径数目，由于答案可能很大，返回答案对 $10^9 + 7$ 取余 的结果。
>

### 思路

*知道用动态规划，但没想出来，下面参考了别人的*

定义 `dp[i][j][v]` 表示从 `(0, 0)` 走到 `(i, j)`，且路径和模 k 的结果为 v 时的路径数。

要使得从 `(0, 0)` 处走到 `(i, j)` 且路径和模 k 的结果为 v，前一个点只能是 `(i-1, j)` 或 `(i, j-1)`，且有

- `(pathsum(i-1, j) + grid[i][j]) % k = pathsum(i, j) = v `
- `(pathsum(i, j-1) + grid[i][j]) % k = pathsum(i, j) = v `

那么有如下状态转移方程：`dp[i][j][v] = dp[i-1][j][(v - grid[i][j]) % k] + dp[i][j-1][(v - grid[i][j]) % k]`

### code

```go
// go
func numberOfPaths(grid [][]int, k int) int {
    mod := 1000000007
    m, n := len(grid), len(grid[0])
    dp := make([][][]int, m)
    for i := 0; i < m; i++ {
        dp[i] = make([][]int, n)
        for j := 0; j < n; j++ {
            dp[i][j] = make([]int, k)
        }
    }

    dp[0][0][grid[0][0] % k] = 1
    for i := 0; i < m; i++ {
        for j := 0; j < n; j++ {
            for v := 0; v < k; v++ {
                if i > 0 {
                    dp[i][j][v] += dp[i-1][j][(v - grid[i][j] + 100*k) % k]
                    dp[i][j][v] %= mod
                }
                if j > 0 {
                    dp[i][j][v] += dp[i][j-1][(v - grid[i][j] + 100*k) % k]
                    dp[i][j][v] %= mod
                }
            }
        }
    }

    return dp[m-1][n-1][0]
}
```
