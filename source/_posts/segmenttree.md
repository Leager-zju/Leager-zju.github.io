---
title: 线段树
author: Leager
mathjax:
  - true
date: 2024-08-11 12:13:26
summary:
categories:
  - data structure
tags:
img:
---

**线段树**是一种能够在 $O(\log n)$ 的时间复杂度下，动态维护区间信息的数据结构。

<!--more-->

## 树状数组

[**树状数组**](../shu-zhuang-shu-zu)虽然也能支持 $O(\log n)$ 的区间查询，但仅仅是区间求和，对于区间最值问题显得有些无力。

## 线段树

**线段树**将每个长度不为 1 的区间划分成左右两个区间递归求解，从而在逻辑上把整个区间划分为一个树形结构，通过合并左右两区间信息来求得该区间的信息。通常应用于**区间求和**、**区间求最值**等问题。

线段树建树的思想并不难理解：如果当前节点负责区间 `[left, right]`，那么左儿子节点负责 `[left, mid]`，右儿子节点负责 `[mid + 1, right]`，这样的以中点的划分能够尽可能让同一层所有节点负责的区间大小相近。

我们可以简单地用二叉树来构建，但这样就会存在开销（维护左右儿子的指针，在堆上分配内存）。然而根据建树的过程，我们也不难发现最后的树形结构与「满二叉树」非常接近，且当区间大小为 2 的幂时变满。此时我们就可以考虑用数组的方式来维护这棵树，如果我们使整棵树从下标 `index = 1` 开始，那么访问左儿子就是令 `index = index * 2`，访问右儿子就是令 `index = index * 2 + 1`。这样一来每个节点就比二叉树少维护了两个指针的信息，大大减少了内存开销。

> 考虑到位运算的效率大于四则运算，上面访问儿子的方式也可以升级为 `index = index << 1` 和 `index = (index << 1) | 1`，证明略。

### 构建

从而根据序列 `nums` 构建线段树 `st` 的代码用 C++ 可以如下实现：

```cpp 构建线段树
int build(std::vector<int>& st, int idx,
          const std::vector<int>& nums, int left, int right) {
  if (left == right) {
    st[idx] = nums[left];
    return;
  }

  int mid = left + (right - left) >> 1;
  int lchild = build(st, idx << 1, nums, left, mid);
  int rchild = build(st, (idx << 1) | 1, nums, mid + 1, right);
  // 根据左右区间的信息维护当前信息，比如下面是区间求和的代码
  st[idx] = lchild + rchild;
  // 求区间最大值则是用 st[idx] = std::max(lchild, rchild);
  // 其他同理。
}
```

### 查询

现在我们已经有了线段树数组了，如何进行查询呢？考虑到每个节点负责的区间是固定的，所以在递归查询的时候需要额外提供当前节点的区间边界信息。为了降低开销，我们只要找到一个极大的子区间，即可读取该区间的信息，而无需进一步访问子节点。

那么查询区间 `[left, right]` 信息的代码如下所示：

```cpp 区间查询
int query(std::vector<int>& st, int idx, int lbound, int rbound // 当前节点负责区间 [lbound, rbound]
          int left, int right) {
  // 这里依然以区间求和为例
  if (lbound == left && rbound == right) {
    // 找到极大子区间
    return st[idx];
  }

  int mid = lbound + (rboud - lbound) >> 1;
  int res = 0;
  if (left <= mid) {
    // 待查询的区间与左子树负责的区间 [lbound, mid] 产生交集
    res += query(st, idx << 1, lbound, mid, left, right);
  }
  if (right >= mid + 1) {
    // 待查询的区间与右子树负责的区间 [mid + 1, rbound] 产生交集
    res += query(st, (idx << 1) | 1, mid + 1, rbound, left, right);
  }

  return res;
}
```

### 修改 & 懒惰标记

单点修改其实是区间修改中对应区间长度为 1 的情况，所以我们这里仅讨论区间修改。一种朴素的做法是遍历该区间，对其中每个元素，都去线段树中找到对应的长度为 1 的区间，然后自底向上修改。

这种做法的问题在于，需要进行若干次单点修改，即深入到叶节点去操作。可我们的线段树维护的是区间信息啊，完全可以只修改极大子区间，却暂不进一步修改更深的子节点。

那么子节点维护的区间信息肯定还是要去修改的，不然就会出现一致性的问题。那么什么时候修改呢？根据 LAZY 哲学，我们完全可以等到未来访问子区间的时候再去更新。显然如果未来并没有访问子区间，那我们就省下了若干修改操作，不得不说是很大的优化；即便访问了子区间，那么本次下推相当于将之前所有的累计更新放到这一次完成，也能大大优化时间开销。

此时就要用到一个称为「**懒惰标记**」的东西了。它会将我们修改的区间做上记号，表明这段区间已经在之前进行了整体的修改操作。

这样一来，如果后续的查询需要进入更深层次的节点，只需修改子节点的懒惰标记即可。

```cpp 区间修改 with 懒惰标记 - 记录修改量
void update(std::vector<int>& st, int idx, int lbound, int rbound,
            std::vector<int>& lazy, // lazy: 懒惰标记数组，记录修改量
            int change, int left, int right) {
  // 这里依然以区间求和为例
  if (lbound == left && rbound == right) {
    lazy[idx] += change; // 记录对这个区间所有值的修改量，后续再下推到子节点
    st[idx] += (right - left + 1) * change;
    return;
  }

  int mid = lbound + (rboud - lbound) >> 1;
  if (lbound != rbound && lazy[idx] != 0) {
    // 将之前的更新下推到左儿子
    lazy[idx << 1] += lazy[idx];
    st[idx << 1] += (mid - left + 1) * lazy[idx];
    // 将之前的更新下推到右儿子
    lazy[(idx << 1) | 1] += lazy[idx];
    st[(idx << 1) | 1] += (right - mid) * lazy[idx];
    // 自身清空
    lazy[idx] = 0;
  }

  if (left <= mid) {
    // 待修改的区间与左子树负责的区间 [lbound, mid] 产生交集
    update(st, idx << 1, lbound, mid, nums, left, right);
  }
  if (right >= mid + 1) {
    // 待修改的区间与右子树负责的区间 [mid + 1, rbound] 产生交集
    update(st, (idx << 1) | 1, mid + 1, rbound, nums, left, right);
  }
  st[idx] = st[idx << 1] + st[(idx << 1) | 1];
}
```

上面的代码是将某个区间整体加上某个值 `change`，如果要将区间修改为目标值 `target`，则代码应当改为如下形式：

```cpp 区间修改 with 懒惰标记 - 记录目标值
void update(std::vector<int>& st, int idx, int lbound, int rbound,
            std::vector<int>& lazy, std::vector<bool>& isUpdate, // lazy: 懒惰标记数组，记录目标值。isUpdate: 记录是否修改
            int target, int left, int right) {
  // 这里依然以区间求和为例
  if (lbound == left && rbound == right) {
    lazy[idx] = target; // 记录修改后的值，后续再下推到子节点
    st[idx] = (right - left + 1) * target;
    isUpdate[idx] = true;
    return;
  }

  int mid = lbound + (rboud - lbound) >> 1;
  if (lbound != rbound && isUpdate[idx]) {
    // 将之前的更新下推到左儿子
    lazy[idx << 1] = lazy[idx];
    st[idx << 1] = (mid - left + 1) * lazy[idx];
    isUpdate[idx << 1] = true;
    // 将之前的更新下推到右儿子
    lazy[(idx << 1) | 1] = lazy[idx];
    st[(idx << 1) | 1] = (right - mid) * lazy[idx];
    isUpdate[(idx << 1) | 1] = true;
    // 自身清空
    isUpdate[idx] = false;
  }

  if (left <= mid) {
    // 待修改的区间与左子树负责的区间 [lbound, mid] 产生交集
    update(st, idx << 1, lbound, mid, nums, left, right);
  }
  if (right >= mid + 1) {
    // 待修改的区间与右子树负责的区间 [mid + 1, rbound] 产生交集
    update(st, (idx << 1) | 1, mid + 1, rbound, nums, left, right);
  }
  st[idx] = st[idx << 1] + st[(idx << 1) | 1];
}
```

### 查询 & 懒惰标记

有了懒惰标记后，查询部分代码也应当做相应修改。

```cpp 区间查询 with 懒惰标记 - 记录修改量
int query(std::vector<int>& st, int idx, int lbound, int rbound,
          std::vector<int>& lazy, // lazy: 懒惰标记数组，记录修改量
          int left, int right) {
  // 这里依然以区间求和为例
  if (lbound == left && rbound == right) {
    return st[idx];
  }

  int mid = lbound + (rboud - lbound) >> 1;
  if (lbound != rbound && lazy[idx] != 0) {
    // 将之前的更新下推到左儿子
    lazy[idx << 1] += lazy[idx];
    st[idx << 1] += (mid - left + 1) * lazy[idx];
    // 将之前的更新下推到右儿子
    lazy[(idx << 1) | 1] += lazy[idx];
    st[(idx << 1) | 1] += (right - mid) * lazy[idx];
    // 自身清空
    lazy[idx] = 0;
  }

  int res = 0;
  if (left <= mid) {
    // 待修改的区间与左子树负责的区间 [lbound, mid] 产生交集
    res += query(st, idx << 1, lbound, mid, nums, left, right);
  }
  if (right >= mid + 1) {
    // 待修改的区间与右子树负责的区间 [mid + 1, rbound] 产生交集
    res += query(st, (idx << 1) | 1, mid + 1, rbound, nums, left, right); 
  }

  return res;
}
```

```cpp 区间查询 with 懒惰标记 - 记录目标值
int query(std::vector<int>& st, int idx, int lbound, int rbound,
          std::vector<int>& lazy, std::vector<bool>& isUpdate, // lazy: 懒惰标记数组，记录目标值。isUpdate: 记录是否修改
          int target, int left, int right) {
  // 这里依然以区间求和为例
  if (lbound == left && rbound == right) {
    return st[idx];
  }

  int mid = lbound + (rboud - lbound) >> 1;
  if (lbound != rbound && isUpdate[idx]) {
    // 将之前的更新下推到左儿子
    lazy[idx << 1] = lazy[idx];
    st[idx << 1] = (mid - left + 1) * lazy[idx];
    isUpdate[idx << 1] = true;
    // 将之前的更新下推到右儿子
    lazy[(idx << 1) | 1] = lazy[idx];
    st[(idx << 1) | 1] = (right - mid) * lazy[idx];
    isUpdate[(idx << 1) | 1] = true;
    // 自身清空
    isUpdate[idx] = false;
  }

  int res = 0;
  if (left <= mid) {
    // 待修改的区间与左子树负责的区间 [lbound, mid] 产生交集
    res += query(st, idx << 1, lbound, mid, nums, left, right);
  }
  if (right >= mid + 1) {
    // 待修改的区间与右子树负责的区间 [mid + 1, rbound] 产生交集
    res += query(st, (idx << 1) | 1, mid + 1, rbound, nums, left, right);
  }

  return res;
}
```

### 空间复杂度

如果采用数组结构，则当序列长度为 $n$ 时，表明线段树存在 $n$ 个叶节点，易得线段树深度最大为 $\lceil\log{n}\rceil$。对应的数组存储最大容量为 $s = 2^{\lceil\log{n}\rceil + 1}$。这个最大值在 $n = 2^x+1$ 时取到，此时 $s = 2^{x+2} = 2^{\log(n-1)+2} = 4(n-1)$。所以我们可以简单地把数组的长度设置在 $4(n-1)$ 大小，保证不会出现越界。

## 应用

1. [>>> LeetCode 2940 找到 Alice 和 Bob 可以相遇的建筑(Hard) <<<](https://leetcode.cn/submissions/detail/554071441/)