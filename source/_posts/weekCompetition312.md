---
title: weekCompetition312
author: Leager
mathjax: true
date: 2022-09-26 21:48:58
summary:
categories:
    - LeetCode
tags:
    - 周赛
img:
---

[第 312 场周赛](https://leetcode.cn/contest/weekly-contest-312/)复盘。

**排名** 1273 / 6638

<!--more-->

### 1. [按身高排序](https://leetcode.cn/problems/sort-the-people/)

> 给你一个字符串数组 `names` ，和一个由 **互不相同** 的正整数组成的数组 `heights` 。两个数组的长度均为 n 。
>
> 对于每个下标 i，`names[i]` 和 `heights[i]` 表示第 i 个人的名字和身高。
>
> 请按身高 **降序** 顺序返回对应的名字数组 `names` 。
>

#### 思路

由于人名可能有重复，故不能建 map，而是将 name 与其对应的 height 作为一个整体，然后排序。

#### code

```c++
// c++
class Solution {
public:
    vector<string> sortPeople(vector<string>& names, vector<int>& heights) {
        vector<string> res;
        vector<pair<string, int>> temp;
        for (int i = 0; i < names.size(); i++) {
            temp.emplace_back(make_pair(names[i], heights[i]));
        }
        
        sort(temp.begin(), temp.end(), [&](const pair<string, int> &a, const pair<string, int> &b) {
            return a.second > b.second;
        });
        
        for (auto &it : temp) {
            res.emplace_back(it.first);
        }
            
        return res;
    }
};
```

### 2. [按位与最大的最长子数组](https://leetcode.cn/problems/longest-subarray-with-maximum-bitwise-and/)

> 给你一个长度为 n 的整数数组 `nums` 。
>
> 考虑 `nums` 中进行 **按位与**运算得到的值 **最大** 的 **非空** 子数组。
>
> - 换句话说，令 k 是 `nums` **任意** 子数组执行按位与运算所能得到的最大值。那么，只需要考虑那些执行一次按位与运算后等于 k 的子数组。
>
> 返回满足要求的 **最长** 子数组的长度。
>
> 数组的按位与就是对数组中的所有数字进行按位与运算。
>
> **子数组** 是数组中的一个连续元素序列。

#### 思路

首先有一个性质：`a AND b ≤ min(a, b)`，那么 AND 运算能够得到的最大值必然是整个数组的最大值。从而问题转换为，找到一个最长的连续子数组，其中所有元素都是 `nums[]` 中的最大值。

#### code

```c++
// c++
class Solution {
public:
    int longestSubarray(vector<int>& nums) {
        int maxm = *max_element(nums.begin(), nums.end());
        int res = 1;
        for (int i = 0; i < nums.size(); i++) {
            if (nums[i] == maxm) {
                int j = i + 1;
                for (j = i + 1; j < nums.size(); j++) {
                    if (nums[j] != nums[i]) {
                        break;
                    }
                }
                res = max(res, j - i);
                i = j-1;
            }
        }
        return res;
    }
};
```

### 3. [找到所有好下标](https://leetcode.cn/problems/find-all-good-indices/)

> 给你一个大小为 n 下标从 **0** 开始的整数数组 `nums` 和一个正整数 k 。
>
> 对于 `k <= i < n - k` 之间的一个下标 i ，如果它满足以下条件，我们就称它为一个 **好** 下标：
>
> - 下标 i **之前** 的 k 个元素是 **非递增的** 。
> - 下标 i **之后** 的 k 个元素是 **非递减的** 。
>
> 按 **升序** 返回所有好下标。

#### 思路

定义 `assend[]` 与 `dessend[]`：如果一个数比它前面那个数大，则 `assend[i] = 1`；如果一个数比它后面那个数小，则 `dessend[i] = 1`

问题就变为：找到一个下标，它前面 k-1 个下标的 assend 值均为 0，后面 k-1 个下标的 dessend 值也均为 0

用滑动窗口来维护前后 k-1 个下标的 assend/dessend 值中 1 的个数，每个迭代的过程只需判断个数是否均为 0 即可。

#### code

```go
// go
func goodIndices(nums []int, k int) []int {
    n := len(nums)
    
    res := make([]int, 0)
    
    if n - k <= k {
        return res
    }
    
    assend := make([]int, n)
    dessend := make([]int, n)
    
    for i := range nums {
        if i > 0 && nums[i] > nums[i-1] {
            assend[i] = 1
        } else {
            assend[i] = 0
        }
        if i < n-1 && nums[i] > nums[i+1] {
            dessend[i] = 1
        } else {
            dessend[i] = 0
        }
    }

    left1, right1, left2, right2 := 1, k-1, k+1, 2*k-1
    cnt1, cnt2 := 0, 0
    
    for i := left1; i <= right1; i++ {
        cnt1 += assend[i]
    }
    for i := left2; i <= right2; i++ {
        cnt2 += dessend[i]
    }
    
    if cnt1 == 0 && cnt2 == 0 {
        res = append(res, k)
    }
    
    for i := k+1; i < n-k; i++ {
        right1++
        cnt1 = cnt1 + assend[right1] - assend[left1]
        left1++
        
        right2++
        cnt2 = cnt2 + dessend[right2] - dessend[left2]
        left2++
        
        if cnt1 == 0 && cnt2 == 0 {
            res = append(res, i)
        }
    }
    
    return res
}
```

### 4. [好路径的数目](https://leetcode.cn/problems/number-of-good-paths/)

> 给你一棵 n 个节点的树（连通无向无环的图），节点编号从 0 到 n - 1 且恰好有 n - 1 条边。
>
> 给你一个长度为 n 下标从 **0** 开始的整数数组 `vals` ，分别表示每个节点的值。同时给你一个二维整数数组 `edges` ，其中 `edges[i] = [ai, bi]` 表示节点 ai 和 bi 之间有一条 **无向** 边。
>
> 一条 **好路径** 需要满足以下条件：
>
> - 开始节点和结束节点的值 **相同** 。
> - 开始节点和结束节点中间的所有节点值都 **小于等于** 开始节点的值（也就是说开始节点的值应该是路径上所有节点的最大值）。
>
> 请你返回不同好路径的数目。
>
> 注意，一条路径和它反向的路径算作 同一 路径。比方说， `0 -> 1` 与 `1 -> 0` 视为同一条路径。单个节点也视为一条合法路径。
>

#### 思路

参考了 [这位大佬的解法](https://leetcode.cn/problems/number-of-good-paths/solution/bing-cha-ji-by-endlesscheng-tbz8/)。

朴素的考虑是，找到连通分量中所有的最大值节点，若有 $x$ 个，则共可以生成 $\displaystyle C(x, 2) = \frac{x(x-1)}{2}$ 条好路径；之后，将这些节点删除，对剩下的所有连通分量应用上述步骤。但这种方法实现起来较为复杂。

不妨逆向思维，从小到大走，同时将删除操作改为合并操作。于是可以考虑用**并查集**来完成这一操作。

刚开始所有节点都是 standalone 的，我们遍历 `edges[]` 时，不断合并节点，并让较大元素作为较小元素的**代表元**，一旦在合并过程中发现有两个节点的代表元相等（也就意味着这两个代表元满足**好路径**的要求），如果用 `size[]` 表示当前节点作为代表元时，所在并查集中最大值的数量，则可以用乘法解得合并后的连通分量里的好路径数量。

由于我们按照节点值升序访问节点，故每次只需和比自己小的邻居合并，则可以保证对于节点 $v$ 的任意邻居，其所在并查集的最大值不会超过 $vals[v]$，好路径的数量也就不会遗漏。合并后 $v$ 即为代表元。

#### code

```go
// go
func findfather(father []int, x int) int {
    a, temp := x, x
    for father[x] != x {
        x = father[x]
    }
    for a != x {
        a = father[a]
        father[temp] = x
        temp = a
    }
    return x
}

func numberOfGoodPaths(vals []int, edges [][]int) int {
    n := len(vals)
    res := n  // 所有单节点好路径数量
    father := make([]int, n)  // 代表元
    size := make([]int, n)    // 当前节点为代表元时, 所在并查集中最大值的数量
    ids := make([]int, n)     // 序号, 根据 vals[id] 来排序
    graph := make([][]int, n) // 图
    // 初始化
    for i := range father {
        father[i] = i
        size[i] = 1
        ids[i] = i
        graph[i] = make([]int, 0)
    }
    for _, edge := range edges {
        x, y := edge[0], edge[1]
        graph[x] = append(graph[x], y)
        graph[y] = append(graph[y], x)
    }
    sort.Slice(ids, func(i, j int) bool {
        return vals[ids[i]] < vals[ids[j]]
    })

    for _, id := range ids {
        fx := findfather(father, id)
        for _, neighbor := range graph[id] {
            fy := findfather(father, neighbor)
            if fx == fy || vals[fy] > vals[id] { // fx == fy 则无需合并, 只考虑比自己小的邻居
                continue
            }
            
            if vals[fx] == vals[fy] {
                res += size[fx] * size[fy]
                size[fx] += size[fy]
            }
            father[fy] = fx
        }
    }
    return res
}
```

