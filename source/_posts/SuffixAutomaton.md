---
title: 后缀自动机(Suffix Automaton)
author: Leager
mathjax:
  - true
date: 2024-08-05 20:10:24
summary:
categories: data structure
tags:
  - C++
img:
---

翻阅网络资料两天后顿悟，遂写下心得。

> 参考资料
>
> - [OI Wiki](https://oi-wiki.org/string/sam/#%E6%A3%80%E6%9F%A5%E5%AD%97%E7%AC%A6%E4%B8%B2%E6%98%AF%E5%90%A6%E5%87%BA%E7%8E%B0)
>
> - [知乎。并贴心地给出了构建过程的中间形态](https://zhuanlan.zhihu.com/p/410131141)

<!--more-->

## 性质

关于**后缀自动机(SAM)**的所有概念，其实网上说的都已经差不多了。个人总结出以下几个关键的性质：

1. 在 SAM 中，能够通过一个**状态(State)**来表示一组 endpos 相同的字符串，并且有一个**起始 State**（$Start$）来表示空字符串；
   
   > 所谓 endpos 其实就是字符串在「**源串**」（下面简称 `src`）中所有结束位置的集合。比如字符串 `"aabab"` 中 `"ab"` 的 endpos 就是 {2, 4}

2. SAM 可以表示为一个树形结构，并且树上的所有节点都是一个 State，且根节点对应 $Start$；
3. 如果将一个 State 表示的所有字符串以降序排序，假设得到的结果是 $\{s_1, s_2, \dots, s_n\}$，那么对于任意 $i<j$，有 $s_j$ 是 $s_i$ 的**真后缀**，并且 $len(s_{i-1}) = len(s_i) - 1$；
   
   > 在上面的例子中，`"ab"` 和 `"b"` 属于同一 State（它们的 endpos 都是 {2, 4}），这两个字符串满足上述性质。为此，需要在 State 中维护一个 `length` 变量，意为 State 表示的所有字符串中的最大长度。

4. 对于某一 State $A$ 在树中的所有祖先 State $B$，可以得出 $B$ 表示的所有字符串 $b_i$ 都是 $A$ 中所有字符串 $a_i$ 的**真后缀**，同时 $endpos_A \subseteq endpos_B$；

   > 为此，需要在 State 中维护一个 `parent` 变量，以转移到父 State。通常这一步也叫「**后缀压缩**」。

5. State 还需要能够通过某一字符 `ch` 转移到另一 State（如果存在这样一种转移的话），并且认为 State $A$ 表示的所有字符串 $a_i$ 在添加字符 `ch` 后的所有新字符串 $a_i'$ 是 $b_i$ 的**后缀**；

   > 为此，需要在 State 中维护一个 `next` 变量，通常是一个 unordered map<char, int>。当然如果字符集只有小写字母，也可以直接用一个长度为 26 的数组。

## 构建

基于以上性质，其实不难理解 SAM 的构建代码了。因为这是一个 online 结构，我们可以随时添加新字符/字符串以更新自动机。每次新增一个字符 `ch`，相当于建立了一个新的 State $New$（此刻仅表示添加了 `ch` 后的新串 `newStr`，对应 endpos 为 $len(newStr)-1$）。

接下去这句个人理解我认为很关键：**添加 $New$ 后重构 SAM 的过程，本质上就是找一个合适的 State 作为 $New$ 的 parent 的过程**。

根据性质 4，这个所谓的合适的 State，其表示的所有字符串必须能作为 `newStr` 的后缀，且最长串应尽可能长。

如果我们能够把上一次添加字符所构建的 State $Last$ 考虑进来，问题就会变得很简单——$Last$ 所表示的字符串（暂且称为 `oldStr` 好了）在添加了 `ch` 后恰好就是 `newStr` 的后缀。

那么只需要遍历 $Last$ 的所有祖先即可。因为如果一个 State 不是 $Last$ 的祖先，其表示的字符串也不会是 $Last$ 所表示字符串的后缀，也就无法在添加 `ch` 后成为 `newStr` 的后缀了。这也是板子的前半段代码的基本思想。对于上述 States，需要在 `next` 中添加到 $New$ 的转移。

```cpp
// 新建状态
automaton.emplace_back(++strLength_, 0);
State& newState = automaton.back();
stateIndex newStateIdx = automaton.size() - 1;

stateIndex p;
for (p = last_; p != NIL && !automaton[p].next.count(ch); p = automaton[p].parent) {
  // 遍历 last 的祖先，添加转移
  automaton[p].next[ch] = newStateIdx;
}
```

如果直接遍历完在 $Start$ 的 parent 处停止，意味着 `ch` 没有在 `oldStr` 中出现过，可用反证法证明之。

那么如果遇到某个 State $P$（包括 $Start$），其已经能通过 `ch` 转移到其他 State $Q$ 了，说明 `ch` 肯定在 `oldStr` 中出现过。

由于此时此刻集合 endpos($New$) 的大小为 1，那么对于 `oldStr` 的所有后缀 $old_i$，如果子串 $old_i + ch$ 未在 `oldStr` 中出现过，那其必定与 `newStr` 对应同一 endpos 集合。否则，就像之前说的那样，$old_i$ 所属的 State $P$ 存在一个到另一 State $Q$ 的转移。

这需要分情况讨论，其实也就是所有资料都提到的两种情况：

1. $len(P) + 1 = len(Q)$ 
2. $len(P) + 1 < len(Q)$ 

对于第一种情况，表明 $Q$ 就是我们要找的 parent。因为此时不存在一个 State 能够表示更长且与 `newStr` 的 endpos 不同的字符串了。

```cpp
if (automaton[p].length + 1 == automaton[q].length) {
  newState.parent = q;
}
```

对于第二种情况，表明虽然 $Q$ 表示的最长串不一定是 `newStr` 的后缀，但 $old_i + ch$ 一定是，并且根据性质 5，$old_i + ch$ 必定能作为 $Q$ 表示的所有字符串的后缀。此时 $New$ 和 $Q$ 有了一个公共后缀 $old_i + ch$，并且此时 endpos($old_i + ch$) 就会与 endpos($Q$) 产生差异——多了一项 $len(newStr)-1$。

于是就又产生了一个新的 State，并且这个新的 State 是基于 $Q$ 的——对于 $P$ 及其所有祖先，一旦能够通过 `ch` 转移到 $Q$，那就必然能够转移到这个新的 State；同时又能继承 $Q$ 的所有转移（这很显然，毕竟是 $Q$ 的后缀）。所以一般把这个 State 称为 $Clone$。

```cpp
else {
  automaton.emplace_back(automaton[q]);
  State& cloneState = automaton.back();
  stateIndex cloneStateIdx = automaton.size() - 1;
  cloneState.length = automaton[p].length + 1; // 别忘了修改 length

  // 修改 p 的祖先中所有转移到 q 的 State
  for (; p != NIL; p = automaton[p].parent) {
    auto iter = automaton[p].next.find(ch);
    if (iter == automaton[p].next.end() || iter->second != q) {
      break;
    }
    iter->second = cloneStateIdx;
  }

  // 最后 New 和 Q 都指向 Clone
  automaton[q].parent = cloneStateIdx;
  newState.parent = cloneStateIdx;
}
```

最后的最后，还要修改 $Last$ 使其指向 $New$。到这就大功告成了。完整实现如下：

```cpp
void SuffixAutomaton::insert(char ch) {
  automaton.emplace_back(++strLength_, 0);
  State& newState = automaton.back();
  stateIndex newStateIdx = automaton.size() - 1;

  stateIndex p;
  for (p = last_; p != NIL && !automaton[p].next.count(ch); p = automaton[p].parent) {
    automaton[p].next[ch] = newStateIdx;
  }

  if (p != NIL) {  //  {p} + c is a suffix of {q}
    stateIndex q = automaton[p].next[ch];
    if (automaton[p].length + 1 == automaton[q].length) {
      // endpoint({p} + c) change in sync with endpoint({q})
      newState.parent = q;
    } else {
      // size(endpoint({p} + c)) > size(endpoint({q})), so we should
      // create a new intermidiate state "cloneState" to present {p} + c
      automaton.emplace_back(automaton[q]);
      State& cloneState = automaton.back();
      stateIndex cloneStateIdx = automaton.size() - 1;
      cloneState.length = automaton[p].length + 1;
      cloneState.firstTime =
          automaton[q].firstTime + automaton[q].length - cloneState.length;

      for (; p != NIL; p = automaton[p].parent) {
        auto iter = automaton[p].next.find(ch);
        if (iter == automaton[p].next.end() || iter->second != q) {
          break;
        }
        iter->second = cloneStateIdx;
      }

      automaton[q].parent = cloneStateIdx;
      newState.parent = cloneStateIdx;
    }
  }

  for (p = automaton[newStateIdx].parent; p != NIL; p = automaton[p].parent) {
    automaton[p].cnt++;
  }

  last_ = newStateIdx;
}
```

## 应用

SAM 是处理字符串问题的利器，根据前文提到的几条性质，其实可以实现包括但不限于以下功能：

1. 判断模式串是否匹配；
2. 不同子串数；
3. 模式串的出现次数；
4. 查找模式串的首个出现位置；
5. 最长公共子串；
6. ...

所有的实现代码放在了[仓库](https://github.com/Leager-zju/DataStructures/tree/main/SuffixAutomaton)中。只能说，理解 parent 和 next 很关键。