---
title: C++11 の 正则表达式(Regex)
author: Leager
mathjax: true
date: 2023-02-05 12:20:37
summary:
categories: C++
tags: C++11
img:
---

**正则表达式**，又称规则表达式（Regular Expression，常简写为 regex、regexp 或 RE），是一种**文本模式/规则**，包括普通字符和特殊字符（**元字符**）。通常使用单个字符串来表示正则表达式 `pattern`，并**匹配**一系列符合模式 `pattern` 的字符串。

<!--more-->

## 正则表达式基本知识

### 模糊匹配

| 符号     | 描述                                 | 例子                        |
| :------- | :----------------------------------- | --------------------------- |
| `.`      | 匹配换行符以外的任意一个字符         | `f.o`：foo / f0o / ...      |
| `*`      | 匹配前一个字符**零次或多次**         | `fo*`：f / foooo / ...      |
| `+`      | 匹配前一个字符**一次或多次**         | `fo+`：fo / foooo / ...     |
| `?`      | 匹配前一个字符**零次或一次**         | `fo?`：f / fo               |
| `{n}`    | 匹配前一个字符固定 n 次，n ≥ 0，下同 | `fo{2}`：foo                |
| `{n,}`   | 匹配前一个字符至少 n 次              | `fo{1,}`：fo / foo / ...    |
| `{,m}`   | 匹配前一个字符至多 m 次              | `fo{,2}`：f / fo / foo      |
| `{n, m}` | 匹配前一个字符至少 n 次，至多 m 次   | `fo{1, 2}`：fo / foo        |
| `[]`     | 匹配指定集合中的一个字符             | `[fF]oo`：foo / Foo         |
| `[^]`    | 匹配不在集合中的一个字符             | `[^0-9]ar`：Bar / car / ... |
| `x|y`    | 匹配字符串 x **或** y，可连续用      | `foo|bar`：foo / bar        |
| `(...)`  | 匹配括号内任意正则表达式             | `(b|c)def`：bdef / cdef     |

> 字符集可以只输入确定的几个字符，也可以用 `-` 表示范围

### 特殊序列

| 符号 | 描述                                              |
| :--- | :------------------------------------------------ |
| `\`  | 对下一个字符转义                                  |
| `\f` | 匹配换页符                                        |
| `\n` | 匹配换行符                                        |
| `\r` | 匹配回车符                                        |
| `\t` | 匹配制表符                                        |
| `\v` | 匹配垂直制表符                                    |
| `\w` | 匹配任意字母、数字及下划线，等价于 `[0-9a-zA-z_]` |
| `\W` | `\w` 取非，等价于 `[^0-9a-zA-z_]`                 |
| `\d` | 匹配任意一个数字，等价于 `[0-9]`                  |
| `\D` | `\d` 取非，等价于 `[0-9]`                         |
| `\s` | 匹配任意一个空白字符，等价于 `[\f\n\r\t\v]`       |
| `\S` | `\s` 取非，等价于 `[^\f\n\r\t\v]`                 |

### 位置标记

| 符号 | 描述       | 例子                      |
| ---- | ---------- | ------------------------- |
| `^`  | 行首定位符 | `^foo`：以 "foo" 开头的行 |
| `$`  | 行尾定位符 | `^bar`：以 "bar" 结尾的行 |

## C++ 正则表达式支持

C++11 为支持正则表达式新增了若干类，并将这些类封装在头文件 `<regex` 中。

### 主要模板类

- `basic_regex`：正则表达式对象，为基类，可以直接通过字符串或初始化列表进行构造，支持拷贝与移动；
- `sub_match`：标识子表达式所匹配的字符序列；
- `match_results`：维护表示正则表达式匹配结果的字符序列集合，可以通过 `str(int n = 0)` 返回第 n 个子匹配结果的字符序列 ；

### 匹配算法

- `regex_match`：检查字符串是否完全匹配；
- `regex_search`：检查字符串是否部分匹配，若存在匹配的子字符串，则只返回第一个；
- `regex_replace`：以新字符串替换所有匹配的子字符串；

### 代码示例

```c++
// 完全匹配
std::regex r("\\w+day");
std::smatch res;
std::string s1("Monday");
std::string s2("Tuesday");
std::string s3("Weekend");
std::string s4("day");
std::cout << boolalpha
          << regex_match(s1, res, r) << " " << res.str() << "\n"
          << regex_match(s2, res, r) << " " << res.str() << "\n"
          << regex_match(s3, res, r) << " " << res.str() << "\n"
          << regex_match(s4, res, r) << " " << res.str() << "\n";

// output:
// true Monday
// true Tuesday
// false
// false
```

```c++
// 部分匹配
std::regex r("\\w+day");
std::smatch res;
std::string s1("MondayTuesdaySunday");
std::string s2("Monday and Tuesday and Sunday");
std::cout << boolalpha
          << regex_search(s1, res, r) << " " << res.str() << "\n"
          << regex_search(s2, res, r) << " " << res.str() << "\n";

// output:
// true MondayTuesdaySunday
// true Monday
```

```c++
// 子串替换
std::regex r("\\w+day");
std::smatch res;
std::string s("Monday and Tuesday and Sunday");
std::cout << regex_replace(s, r, "Weekend");

// output:
// Weekend and Weekend and Weekend
```

