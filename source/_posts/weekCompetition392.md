---
title: weekCompetition392
author: Leager
mathjax: true
date: 2024-04-07 11:28:36
summary:
categories: LeetCode
tags: weekly
img:
---

[第 392 场周赛](https://leetcode.cn/contest/weekly-contest-392/)复盘。

**排名** 367 / 3193

<!--more-->

## 1. [最长的严格递增或递减子数组](https://leetcode.cn/problems/longest-strictly-increasing-or-strictly-decreasing-subarray/description/)

> 给你一个整数数组 `nums` 。
> 
> 返回数组 `nums` 中 **严格递增** 或 **严格递减** 的最长非空子数组的长度。

### 思路

维护两个数组，分别是以当前元素为末尾的最长严格递增/递减子数组的长度。**动态规划**后取两个数组中的最大值即可。

### code

```C++
// C++
class Solution {
public:
    int longestMonotonicSubarray(vector<int>& nums) {
        int n = nums.size();
        vector<int> inc(n, 1); // 最长严格递增子数组的长度
        vector<int> dec(n, 1); // 最长严格递减子数组的长度
        for (int i = 1; i < n; i++) {
            if (nums[i] > nums[i - 1]) {
                inc[i] = inc[i - 1] + 1;
            } else if (nums[i] < nums[i - 1]) {
                dec[i] = dec[i - 1] + 1;
            }
        }
        return max(*max_element(inc.begin(), inc.end()),
                   *max_element(dec.begin(), dec.end()));
    }
};
```

## 2. [满足距离约束且字典序最小的字符串](https://leetcode.cn/problems/lexicographically-smallest-string-after-operations-with-constraint/description/)

> 给你一个字符串 `s` 和一个整数 `k` 。
> 
> 定义函数 `distance(s1, s2)` ，用于衡量两个长度为 `n` 的字符串 `s1` 和 `s2` 之间的距离，即：
> 
> - 字符 `'a'` 到 `'z'` 按 **循环** 顺序排列，对于区间 `[0, n - 1]` 中的 `i` ，计算所有「 `s1[i]` 和 `s2[i]` 之间 **最小距离**」的 和 。
> 
> 例如，`distance("ab", "cd") == 4` ，且 `distance("a", "z") == 1` 。
> 
> 你可以对字符串 `s` 执行 **任意次** 操作。在每次操作中，可以将 `s` 中的一个字母 **改变** 为 **任意** 其他小写英文字母。
> 
> 返回一个字符串，表示在执行一些操作后你可以得到的 **字典序最小** 的字符串 `t` ，且满足 `distance(s, t) <= k` 。

### 思路

使用**贪心**的策略，从字符串第一个字母开始，对于靠前的每个字母，我们希望执行操作后其变得尽可能“小”，这样操作后得到的字符串的字典序必然是最小的。

我们可以求出每个字母变成 `'a'` 的距离，如果当前操作次数允许，那么就将其变为 `'a'`；反之尽可能变成更小的字母。

### code

```C++
// C++
class Solution {
public:
    int disToA(char ch) { return min(ch - 'a', 'a' + 26 - ch); }

    string getSmallestString(string s, int k) {
        for (int i = 0; i < s.length() && k > 0; i++) {
            if (s[i] != 'a') { // 如果已经是 'a' 了就不操作
                int d = disToA(s[i]);
                if (k >= d) {
                    s[i] = 'a';
                    k -= d;
                } else {
                    s[i] -= k;
                    k = 0;
                }
            }
        }
        return s;
    }
};
```

## 3. [使数组中位数等于 K 的最少操作数](https://leetcode.cn/problems/minimum-operations-to-make-median-of-array-equal-to-k/description/)

> 给你一个整数数组 `nums` 和一个 **非负** 整数 `k` 。
> 
> 一次操作中，你可以选择任一下标 `i` ，然后将 `nums[i]` 加 `1` 或者减 `1` 。
> 
> 请你返回将 `nums` **中位数** 变为 `k` 所需要的 **最少** 操作次数。
> 
> 一个数组的 **中位数** 指的是数组按 **非递减** 顺序排序后最中间的元素。如果数组长度为偶数，我们选择中间两个数的较大值为中位数。

### 思路

因为是修改任意元素，故修改前后结果与初始顺序无关，那么可以先将数组排序，将问题转换为：使得 `nums[nums.size()/2] == k`。

此时我们可以找 `k` 的左右边界。

- **左边界**：第一个**小于等于** k 的数；
- **右边界**：第一个**大于** k 的数；

如果右边界小于等于 `nums.size()/2`，说明中间这部分数太大了，应当将其减至 `k`，使得最终右边界为 `nums.size()/2 + 1`。

如果左边界大于 `nums.size()/2`，说明中间这部分数太小了，应当将其增至 `k`，使得最终左边界为 `nums.size()/2`。

其他情况都是使得整个数组的中位数为 `k` 的，此时无需任何操作。

> WA 了一次，发现返回值是 `long long`，而我返回了一个 `int`🤣。

### code

```C++
// C++
class Solution {
public:
    long long minOperationsToMakeMedianK(vector<int>& nums, int k) {
        sort(nums.begin(), nums.end());
        int lb = nums.size(), rb = nums.size();

        for (int i = 0; i < nums.size(); i++) {
            if (nums[i] >= k) {
                lb = i;
                break;
            }
        }
        for (int i = lb; i < nums.size(); i++) {
            if (nums[i] > k) {
                rb = i;
                break;
            }
        }

        long long res = 0;
        while (rb < nums.size() / 2 + 1) {
            res += nums[rb++] - k;
        }
        while (lb > nums.size() / 2) {
            res += k - nums[--lb];
        }
        return res;
    }
};
```

## 4. [带权图里旅途的最小代价](https://leetcode.cn/problems/minimum-cost-walk-in-weighted-graph/)

> 给你一个 `n` 个节点的带权无向图，节点编号为 `0` 到 `n - 1` 。
> 
> 给你一个整数 `n` 和一个数组 `edges` ，其中 `edges[i] = [u_i, v_i, w_i]` 表示节点 `u_i` 和 `v_i` 之间有一条权值为 `w_i` 的无向边。
> 
> 在图中，一趟旅途包含一系列节点和边。旅途开始和结束点都是图中的节点，且图中存在连接旅途中相邻节点的边。注意，一趟旅途可能访问同一条边或者同一个节点多次。
> 
> 如果旅途开始于节点 `u` ，结束于节点 `v` ，我们定义这一趟旅途的 **代价** 是经过的边权按位与 `AND` 的结果。换句话说，如果经过的边对应的边权为 `w0, w1, w2, ..., wk` ，那么代价为 `w0 & w1 & w2 & ... & wk` ，其中 `&` 表示按位与 `AND` 操作。
> 
> 给你一个二维数组 `query` ，其中 `query[i] = [s_i, t_i]` 。对于每一个查询，你需要找出从节点开始 `s_i` ，在节点 `t_i` 处结束的旅途的最小代价。如果不存在这样的旅途，答案为 `-1` 。
> 
> 返回数组 `answer` ，其中 `answer[i]` 表示对于查询 `i` 的 **最小** 旅途代价。

### 思路

对于按位与而言，`a AND b` 的结果必然小于等于 `a, b` 两者，并且图中点和边可以访问任意次数，那么我们需要尽可能多地访问边，这样就能使得结果最小。

对于一个连通分量来说，将所有边都访问一遍就已经能达到最小值了，因为相同的数做 `AND` 计算结果不变，所以访问再多次也没有意义。那思路就很简单了，用**并查集**，将所有互达的点纳入同一个集合。如果查询中的两个点在同一个连通分量里，我们可以遍历这个连通分量所有的边，不断做 `AND` 计算即可；反之说明两点不可达，直接返回 `-1`。

经过上面的讨论我们发现，同一个连通分量里任意两对不同的点，其路径代价都是一样的，都是这个连通分量里所有的边的 `AND` 操作和，这可以看作是**整个连通分量的代价**。那么我们可以在查询前预先将所有连通分量的代价计算好，等到查询时直接进入哈希表中查询即可，无需作重复计算。

有一点需要注意的是，因为是无向图，并且两点之间可能会有多条边，那么也需要将这些边做一个代价统计，最后留下的结果就直接是 `AND` 的结果。

> 😭 corner case：当 `query[0] == query[1]` 时，代价为 `0`。好多人都 WA 了，估计是因为这个 case 没考虑到。

### code

```C++
// C++
class Solution {
public:
    vector<int> minimumCost(int n, vector<vector<int>>& edges,
                            vector<vector<int>>& query) {
        // 初始化并查集
        vector<int> father(n);
        auto findfather = [&](int x) {
            int a = x, b = x;
            while (x != father[x]) {
                x = father[x];
            }
            while (a != x) {
                a = father[a];
                father[b] = x;
                b = a;
            }
            return x;
        };
        auto merge = [&](int x, int y) {
            int fx = findfather(x);
            int fy = findfather(y);
            if (fx != fy) {
                father[fx] = fy;
            }
        };
        for (int i = 0; i < n; i++) {
            father[i] = i;
        }

        // 初始化图
        vector<unordered_map<int, int>> g(n);
        for (auto&& e : edges) {
            int u = e[0];
            int v = e[1];
            int w = e[2];
            if (g[u].count(v) == 0) {
                g[u][v] = w;
            } else {
                g[u][v] &= w;
            }
            if (g[v].count(u) == 0) {
                g[v][u] = w;
            } else {
                g[v][u] &= w;
            }
            merge(u, v);
        }

        // 预先计算连通分量的代价
        unordered_map<int, int> cache;
        for (int i = 0; i < n; i++) {
            int f = findfather(i);

            int tmp = -1;
            for (auto&& next : g[i]) {
                // 这里就算重复计算 (u, v) 和 (v, u) 也没关系，AND 结果是不变的
                if (tmp == -1) {
                    tmp = next.second;
                } else {
                    tmp &= next.second;
                }
            }

            if (cache.count(f)) {
                cache[f] &= tmp;
            } else {
                cache[f] = tmp;
            }
        }

        // 结果查询
        vector<int> res;
        for (auto&& q : query) {
            if (q[0] == q[1]) {
                res.push_back(0); // !!! corner case
            } else if (findfather(q[0]) != findfather(q[1])) {
                res.push_back(-1);
            } else {
                res.push_back(cache[findfather(q[0])]);
            }
        }
        return res;
    }
};
```