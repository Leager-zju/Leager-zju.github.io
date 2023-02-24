---
title: weekCompetition317
author: Leager
mathjax: true
date: 2022-10-30 22:17:17
summary:
categories:
    - LeetCode
tags:
    - 周赛
img:
---

[第317场周赛](https://leetcode.cn/contest/weekly-contest-317/)复盘。

**排名** 690 / 5660

<!--more-->

### 1. [6220. 可被三整除的偶数的平均值](https://leetcode.cn/problems/average-value-of-even-numbers-that-are-divisible-by-three/)

> 给你一个由正整数组成的整数数组 nums ，返回其中可被 3 整除的所有偶数的平均值。
>
> 注意：n 个元素的平均值等于 n 个元素 **求和** 再除以 n ，结果 **向下取整** 到最接近的整数。
>

#### 思路

能被 3 整除的偶数 ==> 能被 6 整除。

#### code

```go
// go
func averageValue(nums []int) int {
    sum, cnt := 0, 0
    for _, n := range nums {
        if n % 6 == 0 {
            sum += n
            cnt ++
        }
    }
    if cnt == 0 {
        return 0
    }
    return sum/cnt
}
```

### 2. [6221. 最流行的视频创作者](https://leetcode.cn/problems/most-popular-video-creator/)

> 给你两个字符串数组 creators 和 ids ，和一个整数数组 views ，所有数组的长度都是 n 。平台上第 i 个视频者是 `creator[i]`，视频分配的 id 是 `ids[i]`，且播放量为 `views[i]`。
>
> 视频创作者的 **流行度** 是该创作者的 **所有** 视频的播放量的 **总和** 。请找出流行度 **最高** 创作者以及该创作者播放量 **最大** 的视频的 id。
>
> - 如果存在多个创作者流行度都最高，则需要找出所有符合条件的创作者。
> - 如果某个创作者存在多个播放量最高的视频，则只需要找出字典序最小的 id。
>
> 返回一个二维字符串数组 answer，其中 `answer[i] = [creator_i, id_i]` 表示 creatori 的流行度 **最高** 且其最流行的视频 id 是 id_i，可以按任何顺序返回该结果。

#### 思路

大模拟题，开两个 map 分别存 creators 到流行度的映射以及 creators 到其作品集的映射即可。

#### code

```go
// go
func mostPopularCreator(creators []string, ids []string, views []int) [][]string {
    type info struct {
        id string
        view int
    }
    popular := make(map[string]int)     // creators -> 流行度
    works := make(map[string][]info)    // creators -> 作品集
    maxm := 0                           // 最大流行度

    for i := range creators {
        popular[creators[i]] += views[i]
        work, ok := works[creators[i]]
        if !ok {
            works[creators[i]] = []info{{ids[i], views[i]}}
        } else {
            works[creators[i]] = append(work, info{ids[i], views[i]})
        }
        
        
        if popular[creators[i]] > maxm {
            maxm = popular[creators[i]]
        }
    }
    
    names := make([]string, 0)	// 所有流行度最高的创作者的名字
    for k, v := range popular {
        if v == maxm {
            names = append(names, k)
        }
    }
    
    res := make([][]string, 0)
    for _, name := range names {
        wks, _ := works[name]
        var id string
        maxview := -1
        for _, work := range wks {
            if work.view > maxview {
                id = work.id
                maxview = work.view
            } else if work.view == maxview && work.id < id {
                id = work.id
            }
        }
        res = append(res, []string{name, id})
    }
    return res
}
```

### 3. [6222. 美丽整数的最小增量](https://leetcode.cn/problems/minimum-addition-to-make-integer-beautiful/)

> 给你两个正整数 n 和 target 。
>
> 如果某个整数每一位上的数字相加小于或等于 target ，则认为这个整数是一个 **美丽整数** 。
>
> 找出并返回满足 n + x 是 **美丽整数** 的最小非负整数 x 。生成的输入保证总可以使 n 变成一个美丽整数。
>

#### 思路

定义 `getsum(n)` 表示 n 的每一位上的数字之和。若 `getsum(n) <= target` 则直接返回 0 即可。

反之，则需要考虑一个合适的增量 x。考虑到通过增加一个数来减少 `getsum(n)` 的最朴素的办法是加了一个增量 x 后将 n 的最后 i 位变成 0，第 i+1 位由于进位加上了 1，此时 `getsum(n + x) = getsum(n) - getsum(n % 10^i) + 1`，其中 `getsum(n % 10^i)` 即 n 最后 i 位数字之和。

1. 若最后 i 位全为 0，则在最后 i 位上加任何数都会导致各位和增加，因此需考虑更大的 i；
2. 除此之外的所有情况都会使得 `getsum(n % 10^i) >= 1`，故 `getsum(n + x) <= getsum(n)`，即增加一个数 x 后 n 的各位和能够减少，此时 `x = 10^i - n % 10^i`。

在这样的一个考虑下，又要 x 最小，我们只需要从 `i = 0` 开始，不断增加其值，直至找到满足要求的答案即可。

#### code

```go
// go
func getsum(n int64) int {
    res := 0
    for n > 0 {
        res += int(n % 10)
        n /= 10
    }
    return res
}
func makeIntegerBeautiful(n int64, target int) int64 {
    sum := getsum(n)
    if sum <= target {
        return 0
    }
    
    mask := int64(1)    // 10^i
    for {
        if sum - getsum(n % mask) + 1 <= target {
            return mask - n % mask
        }
        mask *= 10
    }
    return mask - n
}
```

### 4. [2458. 移除子树后的二叉树高度](https://leetcode.cn/problems/height-of-binary-tree-after-subtree-removal-queries/)

> 给你一棵 **二叉树** 的根节点 root ，树中有 n 个节点。每个节点都可以被分配一个从 1 到 n 且互不相同的值。另给你一个长度为 m 的数组 queries 。
>
> 你必须在树上执行 m 个 **独立** 的查询，其中第 i 个查询你需要执行以下操作：
>
> - 从树中 **移除** 以 `queries[i]` 的值作为根节点的子树。题目所用测试用例保证 `queries[i]` 不 等于根节点的值。
>
> 返回一个长度为 m 的数组 answer ，其中 `answer[i]` 是执行第 i 个查询后树的高度。
>
> **注意**：
>
> - 查询之间是独立的，所以在每个查询执行后，树会回到其 **初始** 状态。
> - 树的高度是从根到树中某个节点的 **最长简单路径中的边数** 。

#### 思路

最开始想的是开一些数据结构存放每个节点的 父节点，左子树高度，右子树高度 以及 值对应的节点指针。对于每个 queries[i]，找到对应节点，并通知上层节点 $f_1$ 高度已改变。$f_1$ 收到消息后，会比较被删除的儿子与另一个儿子，更新当前高度后继续通知上层节点 $f_2$。以此类推直至到达根节点。理想状态下它的时间复杂度为 $O(q\log n)$，但极端情况下当二叉树为单链时，时间复杂度就降为 $O(qn)$。其中 $q$ 为查询数，$n$ 为节点数。

于是可以想到，先遍历树，遍历的过程中存储**当删除该节点为根的子树时剩余树的高度**。为了保证这一信息不丢失，我们需要在调用函数时维护这一变量。那么对于任意节点 $root$：

- 如果删除其左子树，则剩余高度为 $\max(depth(root)+height(right),\ restHeight)$
- 如果删除其右子树，则剩余高度为 $\max(depth(root)+height(left),\ restHeight)$

#### code

```go
// go
func treeQueries(root *TreeNode, queries []int) []int {
	height := map[*TreeNode]int{} // 每棵子树的高度
	var getHeight func(*TreeNode) int
	getHeight = func(node *TreeNode) int {
		if node == nil {
			return 0
		}
		height[node] = 1 + max(getHeight(node.Left), getHeight(node.Right))
		return height[node]
	}
	getHeight(root)

	res := make([]int, len(height)+1) // 每个节点的答案
	var dfs func(*TreeNode, int, int)
	dfs = func(node *TreeNode, depth, restH int) {
		if node == nil {
			return
		}
		depth++
		res[node.Val] = restH
		dfs(node.Left, depth, max(restH, depth+height[node.Right]))
		dfs(node.Right, depth, max(restH, depth+height[node.Left]))
	}
	dfs(root, -1, 0)

	for i, q := range queries {
		queries[i] = res[q]
	}
	return queries
}

func max(a, b int) int { if b > a { return b }; return a }
```

