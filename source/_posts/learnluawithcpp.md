---
title: 用 C++ 的方式学习 Lua
author: Leager
mathjax: true
date: 2024-08-07 21:47:26
summary:
categories: lua
tags:
  - lua
img:
---

花了一晚上浅学了一下 Lua 脚本语言。作为 C++ Coder，对我而言，学一门新语言的最容易接受的方式就是将它和 C++ 进行对比，看看能不能实现 C++ 相关特性，或者额外的 C++ 做不到的事，观摩了网上的资料以及骚扰 GPT 后，彻底顿悟，写下心得。

<!--more-->

## 基础概念

### Hello World

作为一门「脚本语言」，它本身是**解释性**的，对应的解释器就是 `lua`。可以新建一个 `.lua` 文件，然后以 `lua <filename>.lua` 的方式运行。比如

```lua HelloWorld.lua
print("Hello") -- 控制台输出函数
print("World") -- 这个也是
--[[
  执行 lua HelloWorld.lua，能看到输出如下:
    Hello
    World

]]
```

那么就从上面这个例子开始，进入到对 Lua 的探索中。

### 注释

`--` 后跟单行注释，`--[[` 和 `]]` 之间允许跨行注释。

> 对应 C++ 的 `//` 和 `/**/`。

### 变量作用域

所有变量默认为「**全局**变量」，如果要声明一个仅在当前作用域下生效的局部变量，需要用 `local` 关键词进行修饰。并且在内部作用域声明的局部变量，访问优先级高于全局变量。

> 不难发现 Lua 中「作用域」的概念和 C++ 是基本一致的。

```lua 作用域
a = 5           -- 全局变量
local b = 5     -- 局部变量

function foo()
    local a = 6 -- 该变量优先级高于 line 1 的 a
    b = nil     -- 上层作用域的局部变量亦能在本作用域中访问，将其设置为 nil 相当于删除该变量
    c = 5       -- 全局变量
    local d = 6 -- 仅在 foo() 的作用域内生效
    print(a, b) --> 6       nil
end

foo()
print(a, b)     --> 5       nil
print(c, d)     --> 5       nil
```

根据最后一行执行结果，我们得出一个额外的结论：**一个不在本作用域生效的变量的值为 nil**。

同时还应该知道的是：应该尽可能使用局部变量，因为**既能避免命名冲突，访问速度也比全局变量更快**。

### 基本数据类型

Lua 有 8 大基本类型：

|数据类型|描述|
|:-|:-|
|nil|本作用域内无效的变量均为该类型，打印结果也是 nil|
|boolean|只有 false 和 nil 算 `false`，其余都是 `true`|
|number|双精度浮点数，允许隐式转为 string|
|string|字符串，用**成对**的单引号/双引号包裹，也可以用 `[[` 和 `]]` 包裹跨行字符串，允许隐式转为 number|
|function|Lua 或 C 的函数|
|userdata|C 中的数据结构|
|thread|线程|
|table|支持任意类型的 key-value 映射|

可以通过 `type()` 函数获取某个变量的类型，函数返回值为 `string` 类型。

```lua type
x = {}               -- 可以通过 {} 建表
print(type(nil))     --> nil
print(type(x))       --> table
print(type(type(x))) --> string
x = 1
print(type(x))       --> number
```

我们又可以得出一个额外的结论：**Lua 中的变量可以绑定到任意类型的值，并非像 C++ 那样一经声明就确定了变量名与类型的强绑定关系**。

> Lua 最初是用 C 语言编写的，这使得 Lua 可以很容易地与 C 语言进行交互，所以一些数据类型也与 C 存在关系。

### 运算符

```lua 算术运算符
--[[
  用 = 赋值，并支持多变量同时多赋值
  如果 #(变量) < #(值)，则多出来的值被舍弃，比如下面第二行的 4
  如果 #(变量) > #(值)，则多出来的变量被丢弃（不会被定义），比如下面第三行的 e
  支持第四行这样的 swap 行为
]] 
a = 1
b, c = 2, 3, 4
d, e = 5
b, c = c, b
print(a, b, c, d, e) --> 1 3 2 5 nil

--[[
  支持 + - * / 四则运算
  其中如果 + 的操作变量类型为 string，则会尝试将 string 转为 number
]]
print("123" + 456)   --> 579
print("123" + '456') --> 579

--[[
  % 是取模，^ 是求幂（这个是和 C/C++ 不一样的）
]]
print(3 % 4, 2 ^ 2)  --> 3       4
```

```lua 比较运算符
--[[
  除了不等于(~=)和 C/C++ 不同之外，其余比较符都是一样的，就不多讲了
]]
```

```lua 逻辑运算符 & 其他
--[[
  Lua 中用 or（或）、and（与）、not（非）实现逻辑运算，对应 C/C++ 中的 ||、&&、!，就不多讲了
]]

--[[
  支持 .. 进行 string 拼接操作，如果操作变量类型为 number，则会尝试将 number 转为 string
  支持 # 取 string 的长度
]]
print(#("Hello" .. "World")) --> 10
print(114 .. 514)            --> 114514
print(19.19 .. 8.10)         --> 19.198.1
```

### 循环控制语句

一共有 4 种循环控制语句

1. `while`；
2. `for`；
3. `repeat until`；
4. 基于以上三种的嵌套循环；

```lua 循环
-- while 循环。如果 condition 为 true，则一直运行 statement。
while (condition) do
    -- statement
end

-- for 循环分 数值循环 和 泛型循环 两种。
--[[
  数值循环语法如下：

  for var = val1, val2 [, val3=1] do
      statement
  end

  其中 var 会在区间 [val1, val2] 内以步长 val3（默认为 1）迭代
  等价于 for (auto var = val1; var <= val2; var += val3) {}
]] 
for i = 0, 10, 2 do
    print(i) --> 0 2 4 6 8 10（这里的空格应该是换行）
end

--[[
  泛型循环语法如下：

  for var in iterator do
      statement
  end

  Lua 内置的迭代器方法有 pair() 和 ipair() 两种，都需要配合 table 进行使用
  前者是返回 table 中所有的 key-value 对，后者则限制 key 为从 1 开始递增的整型 number，直到不存在该 key
]]
a = {}
a[1] = 1
a[3] = 3
for key, value in pairs(a) do
    print(key, value) --> 1       1
                      --> 3       3
end
for key, value in ipairs(a) do
    print(key, value) --> 1       1
end

-- repeat until 循环。一直运行 statement 直到 condition 为 true。
repeat
    -- statement
until(condition)
```

上面的 for 迭代循环还会在后文提到，如何自定义迭代器。

### 流程控制语句

其实就是 `if`、`elseif`、`else` 那一套，只不过语法上稍微有些区别，需要用 `then` 和 `end` 代替大括号。

```lua 流程控制语句
a = 100
if (a < 10) then
    print("a < 10")
elseif (a < 50) then
    print("10 <= a < 50")
else
    print("a >= 50")
end
```

### 字符串(string)操作

之前说过可以用单双引号，或者中括号来包裹 string，也说到可以用 `..`、`#` 运算符操作 string，但这里的「string」指的都是类型。事实上 Lua 内置了一个名为 `string` 的对象（本质上是 table），并为其实现了许多成员函数，如下所示：

> ⚠️**注意字符串的位置默认从 1 开始**

|函数|描述|
|:-|:-|
|string.upper(str)|将 str 转为大写。|
|string.upper(str)|将 str 转为小写。|
|string.gsub(str, substr, replace, num)|将 str 中前 num 个 substr 子串替换为 replace。|
|string.find(str, pattern, init=1, plain=true)|找到 str 从 init 开始第一次出现的 pattern，并返回其起始位置与结束位置。如果 plain 为 true 则禁用正则匹配。没找到就返回 nil。|
|string.reserve(str)|将 str 反转。|
|string.char(...)|可变参函数，输入若干 number，并将 number 转成对应的字符然后拼成字符串（如 97 98 -> "ab"）。|
|string.byte(str, i=1, j=i)|返回 str[i:j] 的所有字符对应整数（如 'a' -> 97）。|
|string.length(str)|求长度，等价于 #str。|
|string.rep(str, n)|将 str 重复 n 次。|
|string.match(str, pattern, init=1)|找到 str 从 init 开始第一次出现的 pattern，并返回匹配到的结果串。支持正则匹配。匹配失败就返回 nil。|
|string.gmatch(str, pattern)|**迭代器函数**。不断对 str 进行 pattern 的匹配，并返回匹配到的结果串。支持正则匹配。直到返回 nil。|

### 数组

Lua 的数组依托 table 实现，对下标 i 的访问实际上就是访问 table 中 `key=i` 的那一项。不再赘述。

### 函数(function)

Lua 的函数定义本质上是定义一个类型为 function 的变量，与变量相关的大部分性质也都适用。我们可以通过以下方式定义一个 function：

```lua 函数定义
local function foo()
    print("local")
end

function bar()
    print("global")
end

foo()            --> local
bar()            --> global
print(type(foo)) --> function
```

和 C/C++ 不同，Lua 的函数支持**多返回值**，当然也可以利用赋值的性质，用个数不等的变量去接收值。

```lua 多返回值函数
function foo()
    return 1, 2
end
a, b, c = foo()
print(a, b, c) --> 1       2       nil
```

甚至支持参数包。

```lua 参数包
function add(base, ...)         -- 可以有固定参数，但是必须在参数包之前
    local s = base
    print("get " .. select("#", ...) .. " elements")
    for i, v in ipairs {...} do -- {...}表示一个用参数包构成的数组
        s = s + v
    end
    return s
end

print(add(0, select(3, 1, 2, 3, 4, 5))) -- 相当于调用 add(0, 3, 4, 5)
                                        --> 12
```

上面我们用了一个叫 `select` 的函数，这个函数实际上也支持可变参数，它有以下两种用法：

1. `select("#", ...)`: 获取参数包的参数个数；
2. `select(i, ...)`: 返回参数包从第 i 个元素开始到最后一个元素的切片；

Lua 也可以利用一些基本性质实现 C++ 中的具有**默认值**的函数参数，当然这些参数必须在参数列表的最右侧。

```lua 支持默认值的函数参数
function foo(a, b, c)
    b = b or 2 -- 如果不传入第二个参数，则 b 就会被视为 nil，通过这个语句可以令其具有默认值 2
    c = c or 3 -- 同理
    return a + b + c
end

print(foo())         -- 会报错，因为入参 a 相当于 nil，而 nil 不支持参与四则运算
print(foo(1))        --> 6
print(foo(114, 514)) --> 631
```

### 表(table)

Lua 中的 table 可以说是应用扩展性最高的类型了，因为其支持任意类型的 key 和 value，就可以玩出很多花样来。

先说说最基础的用法。

```lua table 构造 & 访问 & 新增
key0 = 0
tab = {key1 = "value1", key2 = "value2", key3 = "value3", "value4"}
tab[key0] = "value0"

print(tab.key0, tab.key1, tab[key2], tab["key3"]) --> nil value1 nil value2
for key, value in pairs(tab) do
    print(key, type(key), value, type(value)) --> 1       number  value4  string
                                              --> key1    string  value1  string
                                              --> key3    string  value3  string
                                              --> 0       number  value0  string
                                              --> key2    string  value2  string
end
```

简要分析一下: 首先我们通过 `{k = v, ...}` 的方式构造了一个 table，并且通过 `table[]` 往里加入新元素，后续的访问既可以通过 `.` 的方式，也可以通过 `[]` 的方式。但是根据输出结果来看，我们能得出以下结论：

1. 若以 `[k] = v` 方式添加元素，则会保留 k 的源类型；
2. 若以 `{k = v, ...}` 方式构造 table，则 k 会视为 string 类型，比如上面 key1 = "value1" 实际上是生成了一个 "key1" -> "value1" 的映射关系；
3. 若上面这种方式不指定 k，则会默认 k 为从 1 开始自增的 number；
   
    > 通过这种方式可以进行**数组**的构造，即 `nums = {1, 2, 3, 4, 5}`。注意下标默认从 1 开始。但 Lua 中事实上是没有「数组」的，是通过 table 模拟的。

4. 若以 `[k]` 方式访问，则基于 k 的源类型，比如上面 `tab[key2]` 中，`key2` 变量不生效，为 nil，所以返回一个 nil
5. 若以 `.` 方式访问，则 k 会视为 string 类型，比如上面 `tab.key0` 实际上等价于 `tab["key0"]`，同理 `tab.key1` 等价于 `tab["key1"]`，这也就是为什么前者输出 nil 而后者输出 value1 的原因了；

### 元表(metatable)

所谓 metatable 本质上其实就是一个普通的 table，并不是什么特殊的数据类型，只不过表现为 table 中某个**特殊**的 key 对应的 value，为 table 提供若干功能。目前只能通过以下两种方式设置元表。

```lua 设置元表
metatable = {}

tab1 = {}
setmetatable(tab1, metatable)      -- 第一种方式

tab2 = setmetatable({}, metatable) -- 第二种方式

getmetatable(tab1)                 -- 获取 metatable 的方式

-- 其实就是为传入的第一个参数设置 metatable 为第二个参数，然后将其返回。
-- 设置的元表并不会通过 key value 公开给用户，比如下面的脚本就啥也不输出。
for key, value in pairs(tab1) do
    print(key, value)
end
```

上面说了 metatable 可以为 table 提供若干功能，具体有以下功能：

#### __index

> `__index` 提供了访问表中不存在 key 的处理逻辑。

当通过 `table[key]` 访问且 key 在 table 中不存在时，如果设置了 metatable，则会用 metatable 的 `__index` 进行查找。反之返回 nil。

`__index` 可以是 function，也可以是 table。

- 当 `__index` 是 function 时，相当于调用 `metatable.__index(table, key)`；
- 当 `__index` 是 table 时，相当于调用 `metatable.__index[key]`；

```lua __index
tab1 =
    setmetatable(
    {},
    {
        __index = function(table, key)
            print(table, key)
            return 1
        end
    }
)
tab2 =
    setmetatable(
    {},
    {
        __index = tab1
    }
)
print(tab1, tab2)         --> table: 0x189d6d0        table: 0x189d080
print(tab1[0], tab2[1])   --> table: 0x189d6d0        0
                          --> table: 0x189d6d0        1
                          --> 1       1
```

上面的示例中，因为 `tab1` 不存在 key `0`，所以访问 `tab1[0]` 相当于调用了 `metatable.__index(tab1, 0)`，将其打印后并返回 1。

同时，因为 `tab2` 不存在 key `1`，所以访问 `tab2[1]` 相当于调用了 `metatable.__index[1]` 即 `tab1[1]`，所以传入的第一个参数是 `tab1` 而非 `tab2`。

> 因为 Lua 函数调用的特性，如果我们用不到 table 和 key 这两个参数，也可以不设置形参，这样传入的实参就会被舍弃。同理，也可以设置参数列表为 (table, key1, key2, ..., keyn)，只不过从 key2 开始后面的都会是 nil 了。

#### __newindex

> `__newindex` 提供了添加表中不存在 key 的处理逻辑。

当通过 `table[key] = value` 或 `table.key = value` 赋值且 key 在 table 中不存在时，如果设置了 metatable，则会用 metatable 的 `__newindex` 进行操作。反之进行正常的添加。

同样，`__newindex` 可以是 function，也可以是 table。

- 当 `__newindex` 是 function 时，相当于调用 `metatable.__newindex(table, key, value)`；
- 当 `__newindex` 是 table 时，相当于调用 `metatable.__newindex[key] = value`；

```lua __newindex
tab1 =
    setmetatable(
    {},
    {
        __newindex = function(table, key, value)
            print(table, key, value)
            return 1
        end
    }
)
tab2 =
    setmetatable(
    {},
    {
        __newindex = tab1
    }
)
print(tab1, tab2)       --> table: 0x20ec130        table: 0x20ec200
tab1[0] = 1
tab2[0] = 2
print(tab1[0], tab2[0]) --> table: 0x20ec130        0       1
                        --> table: 0x20ec130        0       2
                        --> nil     nil
```

道理和 `__index` 一样的，就不赘述了。

#### __call

> `__call` 提供了 table 作为 function 进行函数调用的处理逻辑。

当通过 `table(...)` 的形式执行类似于函数调用的操作时，如果设置了 metatable，则会用 metatable 的 `__call` 进行操作。反之报错。

> 用 C++ 的话描述，其实就是重载了 `operator()`。

```lua __call
tab =
    setmetatable(
    {},
    {
        __call = function(self, ...)
            for key, value in pairs({...}) do
                self[key] = value
            end
        end
    }
)

tab(1, 2, 3)
for key, value in pairs(tab) do
    print(key, value) --> 1       1
                      --> 2       2
                      --> 3       3
end
```

#### __tostring

> `__tostring` 提供了被 print 调用时的处理逻辑。

当通过 `print(table)` 的形式执行类似于函数调用的操作时，如果设置了 metatable，则会用 metatable 的 `__tostring` 尝试获取一个能被 `print()` 函数接受的类型的值。反之报错。

```lua __tostring
tab =
    setmetatable(
    {1, 2, 3},
    {
        __tostring = function(self)
            local sum = 0
            for k, v in pairs(self) do
                sum = sum + v
            end
            return "表所有元素的和为 " .. sum
        end
    }
)

print(tab) --> 表所有元素的和为 6
```

#### 运算符

我们可以通过 `__add`，`__sub` 这些字段重载 table 的运算符（就像 C++ 中那样！），比如下面这样：

```lua __add
tab =
    setmetatable(
    {},
    {
        __add = function(self, other) -- 用 C++ 的话来说就是重载了 tab 的 operator+()
            for key, value in pairs(other) do
                self[key] = value
            end
            return self
        end
    }
)

res = tab + {1, 2, 3}
for key, value in pairs(res) do
    print(key, value) --> 1       1
                      --> 2       2
                      --> 3       3
end

for key, value in pairs(tab) do
    print(key, value) --> 1       1
                      --> 2       2
                      --> 3       3
end
```

> 上面 tab 的值也被更改了，说明 table 类型的传值是以**指针/引用**的形式。

其余运算符也可以重载，如下：

|   元方法   |对应运算符|
|:---------:|:--------:|
| __add	    |    +     |
| __sub	    |    -     |
| __mul	    |    *     |
| __div	    |    /     |
| __mod	    |    %     |
| __unm	    |    -     |
| __concat  |    ..    |
| __eq      |    ==    |
| __lt      |    <     |
| __le      |    <=    |

## 进阶玩法

### 迭代器

之前我们提到可以用 `pairs` 和 `ipairs` 去遍历一个 table，但实际上迭代器(iter)并不限于此。以 `ipairs()` 为例，我们先尝试获取这个函数的返回值是什么。

```lua pairs
tab = {key1 = 1, 2, 3}
print(ipairs(tab)) --> function: 0x1a8d080     table: 0x1a94020        0
print(tab)         --> table: 0x1a94020
```

第一个返回值是一个 function，应该是一个闭包；第二个返回值是 tab 对象本身；第三个返回值是 0，可能会用于索引。

```lua 接上面的代码
a, b, c = ipairs(tab)
-- print(a())       --> bad argument #1 to 'a' (table expected, got no value)
-- print(a(b))      --> bad argument #2 to 'a' (number expected, got no value)
print(a(b, 0))      --> 1       2
print(a(b, 1))      --> 2       3
print(a(b, 2, 123)) -->
print(a(b, 3))      -->
-- 是的，最后两个就是打印了空行，但实际上应该返回 nil
```

从上面可以得到，`ipairs()` 的第一个返回值 function 对象接受两个参数，且第一个参数要求是 table，第二个参数要求是 number（但是传入 0 却实现了返回 `1 tab[1]`，比较莫名其妙）。那么下面是一个可能的 `ipairs` 的实现：

```lua myIpairs
function iter(tbl, i)
    i = i + 1
    local v = tbl[i]
    if v then
        return i, v
    end
end

function myIpairs(table)
    return iter, table, 0
end

for key, value in ipairs(tab) do
    print(key, value) --> 1       1
                      --> 2       2
end

for key, value in myIpairs(tab) do
    print(key, value) --> 1       1
                      --> 2       2
                      -- 根据这一输出结果，猜想得到证实
end
```

进一步分析「泛型循环」的行为：

1. 首先执行 `in` 左侧的表达式，期望得到**三**个返回值，记为 `func`，`param1`，`param2`；
2. 调用 `func(param1, param2)`，可以得到若干返回值 `value1`，`value2`，...；
3. 这些返回值会被 `in` 左侧的变量接收，多余的丢弃，不足的用 nil 补充；
4. 如果 `value1` 为 nil，终止循环，否则执行循环体；
5. `param1` 不变，`param2 = value1`，重复步骤 2；

其中只有 `func` 是必要的。另外，由于 `param1` 不变，所以又被称为「**状态常量**」，`param2` 仅用于第一次的 `func()` 调用，在循环过程中会发生变化，故又被称为「**初始变量**」。

也可以实现一个只返回 `func` 的迭代器函数：

```lua 无状态迭代器
function square(iteratorMaxCount, currentNumber)
    if currentNumber < iteratorMaxCount then
        currentNumber = currentNumber + 1
        return currentNumber, currentNumber ^ 2
    end
end

for i, n in square, 3, 0 do
    print(i, n) --> 1       1
                --> 2       4
                --> 3       9
end
```

这种只利用**状态常量**和**初始变量**两个值就可以获取下一个元素的迭代器函数称为「**无状态的迭代器**」。那么当然也有「**有状态的迭代器**」了。

```lua 有状态迭代器
array = {"Jack", "Mike"}
function elementIterator(collection)
    local index = 0
    local count = #collection
    return function()
        index = index + 1
        if index <= count then
            return collection[index]
        end
    end
end

for element in elementIterator(array) do
    print(element) --> Jack
                   --> Mike
end
```

这里通过定义局部变量，并将其赋给闭包函数，使得在整个循环中这些局部变量都能生效，这样也就为 `func` 提供了额外的信息，因而为**有状态的**。

### 实现面向对象

回顾一下面向对象三大特性：封装、继承、多态。下面分别讲一下 Lua 如何实现这几个特性。

#### 封装

我们知道 table 可以通过 `.` 的方式访问 key，不难发现这和 C++ 中访问成员变量的方式如出一辙。事实上我们完全可以通过 table 的这一特性实现成员变量。又因为 value 支持任意类型，当然也包括 function 类型，同理也可以实现成员函数。

```lua 封装
obj = {member = 123} -- 定义成员变量
print(obj)           --> table: 0x1449880

function obj:foo()   -- 定义成员函数
    print(self)
    print("obj.foo")
end

obj:foo()            --> table: 0x1449880
                     --> obj.foo

obj.foo = function() -- 也可以通过这种方式定义成员函数
    print(self)
    print("obj.foo - new!")
end

obj.foo()            --> nil
                     --> obj.foo - new!
```

我们发现了两种成员函数的定义方式，同时也发现了两种调用方式！虽然两种定义方式是等价的，但是调用方式却不等价。区别就在于，使用 `:` 调用成员函数会隐式传入 `self` 对象，也就是自身，而 `.` 的方式却不行。同时，我们不能通过 `:` 访问非 function 类型的 value，会报错，因为解释器默认在 `:` 后面的是 function 对象，是要跟圆括号的。所以既然 Lua 为我们专门提供了一种访问方式，那就不要跟他作对，用就是了。

#### 继承

指定 metatable 其实就可以看作「继承自基类」。在 C++ 中，「继承」（假设以 `public` 方式）能够使派生类访问基类的所有非私有成员变量和成员函数，那么在 Lua 中，这种性质由「指定 metatable.__index = metatable」的方式实现。这很合理，当我们尝试访问一个 table（派生类）中不存在的 key-value 时，就会通过 metatable.__index 去查找，也就相当于查找 metatable（基类）中的 key-value。

同时也允许派生类覆盖基类的成员变量/函数，只需要添加同名 key 即可（就不会走 metatable.__index 了）。

下面给出一个工厂函数示例，用于生成派生 table 对象。

```lua 工厂函数
RectangleFactory = {}                          -- 基类
RectangleFactory.__index = RectangleFactory    -- !这一步很关键，允许派生类访问基类的成员函数和成员变量

function RectangleFactory:new(length, breadth) -- 创建派生类的函数
    return setmetatable(
        {
            length = length or 0,
            breadth = breadth or 0,
            area = length * breadth
        },
        self
    )
end

function RectangleFactory:printArea()
    print(self, "面积为", self.area)
end

rec = RectangleFactory:new(1, 2) -- 此时 new() 中的 self 是 RectangleFactory
print(rec)                       --> table: 0x243c740
rec:printArea()                  --> table: 0x243c740        面积为  2
```

在调用 `rec:printArea()` 时，由于其本身没有对应的 key，所以去 metatable（也就是 `RectangleFactory`）的 `__index` 中查找，最终调用了 `RectangleFactory:printArea()`。

这里我们发现，在调用 metatable 的成员函数时，传入的 `self` 是 `rec` 本身。从而得出一个额外的结论：**对于一个 function 而言，如果它作为 table 的成员函数被调用，则内部的 `self` 取决于调用者，即 `:` 左侧的对象**。

#### 多态

只需要在 table 中定义 metatable 的同名函数即可实现多态。

### 模块(module)与包(package)

我们可以在一个 `module.lua` 文件中通过 `return` 返回若干变量，其它 `.lua` 文件可以在开头通过 `require("module")` 语句获得这些变量的使用权。

```lua module.lua
mod = {foo = 1}

function mod:func()
    print("call mod:func " .. self.foo)
end

function moduleFunc()
    print("call moduleFunc")
end

return mod, moduleFunc
```

```lua main.lua
require("module") -- 会根据一定规则找到 module.lua 文件

mod:func()        --> call mod:func 1
moduleFunc()      --> call moduleFunc
```

**加载规则**是：先找当前文件夹，再去环境变量 `LUA_PATH` 中查找。

> ⚠️需要注意的是，使用的变量必须在 `module.lua` 文件中为全局变量。这很好理解，我们把一个文件看成一个单独的作用域，那么声明为 `local` 的变量也就只能在该文件中生效，即便被其它文件 `require`，相当于作用域发生变化，也就无法使用了。这很容易联想到 C 中的 `#include`、`static`、`extern` 相关用法。

进阶玩法是，可以在某个 `package.lua` 中 `require` 许多 module，这样如果我们需要使用这些模块的时候，只需要 `require("package")` 即可（相当于形成了一种 table 的树状结构）。

```lua package.lua
package = {}

package.module1 = require("mypackage.module1") -- 引入 ./mypackage/module1.lua
package.module2 = require("mypackage.module2") -- 引入 ./mypackage/module2.lua

return package
```

通过模块和包，我们可以更好地组织代码，提高代码的可重用性，并降低代码之间的耦合度。

### Lua & C 交互

之前说到 Lua 是 C 写的，可以容易地与 C 语言进行交互，下面讲讲是如何做到的。

#### Lua 中调用 C 函数

具体方式是将 `.c` 文件生成动态链接库，令 Lua 执行相应的函数注册与调用行为。

```c mylib.c
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>

// 所有要注册的函数都必须为 int (*)(lua_State *L) 类型
static int cAdd(lua_State *L) {
  double lhs = luaL_checknumber(L, 1);
  double rhs = luaL_checknumber(L, 2);
  double result = lhs + rhs;
  lua_pushnumber(L, result);
  return 1;  // 返回值的数量
}

// 如果链接成 *.so，那么就需要设置函数名为 luaopen_*
int luaopen_mylib(lua_State *L) {
  luaL_Reg mylib[] = {   // 注册函数名与函数指针，用 {NULL, NULL} 作为结束标识符
    {"add", cAdd},
    {NULL, NULL}
  };
  luaL_newlib(L, mylib); // 注册函数
  return 1;
}
```

```bash 根据 mylib.c 生成动态链接库
$ gcc mylib.c -fPIC -shared -o mylib.so -Wall
$ ls
mylib.c mylib.so test.lua
```

```lua test.lua
local mylib = require("mylib")   -- 查找 mylib.so，并调用其中的 luaopen_mylib()
                                 -- 注册 add() 函数对应到 cAdd()

local result = mylib.add(10, 20) -- 相当于调用 cAdd(10, 20)
print(result)                    --> 30
```

#### C 中执行 Lua 脚本

这个比较简单，关键在于 `luaL_dofile()` 函数。

```C main.c
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#include <stdio.h>

int main() {
  lua_State *L = luaL_newstate();                         // 创建 Lua 虚拟机
  luaL_openlibs(L);                                       // 打开标准 Lua 库

  int error = luaL_dofile(L, "myLua.lua");                // 执行 Lua 脚本
  if (error) {
    fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));  // 打印异常信息
    lua_pop(L, 1);                                        // 弹出异常信息
  }

  lua_close(L);                                           // 关闭 Lua 虚拟机
  return 0;
}
```

#### C 中执行调用了 C 函数的 Lua 脚本

这就是把上面两个合起来了。

当然此时也可以不生成动态链接库，直接执行一段字符串即可。

```C main.c
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#include <stdio.h>

static int cAdd(lua_State *L) {
  double lhs = luaL_checknumber(L, 1);
  double rhs = luaL_checknumber(L, 2);
  double result = lhs + rhs;
  lua_pushnumber(L, result);
  return 1;  // 返回值的数量
}

int main() {
  lua_State *L = luaL_newstate(); // 创建 Lua 虚拟机
  luaL_openlibs(L);               // 打开标准 Lua 库

  /**
   * 下面这个其实是一个宏
   * #define lua_register(L,n,f) (lua_pushcfunction(L, f), lua_setglobal(L, n))
   *
   * 其中：
   * lua_pushcfunction(L, cAdd); 将函数 cAdd() 转换为 Lua 的 function 并压入虚拟栈
   * lua_setglobal(L, "add");    弹出栈顶元素，并在 Lua 中用名为 add 的全局变量存储
   */
  lua_register(L, "add", cAdd);

  int error = luaL_dostring(L, "add(10, 20)");            // 执行 Lua 脚本
  if (error) {
    fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));  // 打印异常信息
    lua_pop(L, 1);                                        // 弹出异常信息
  }

  lua_close(L);                                           // 关闭 Lua 虚拟机
  return 0;
}
```

#### Lua 虚拟机

TODO

### Lua 协程

Lua 协程和 C++20 的协程用法基本一致，由 `coroutine` 模块提供支持。这里我们直接通过一个生产者-消费者问题来了解什么是协程。

```lua coroutine.lua
local newProductor

function productor()
    print("productor", coroutine.running()) -- 获取正在运行的 coroutine
    local i = 0
    repeat
        send(i)
        i = i + 1
    until i > 3
end

function consumer()
    print("consumer", coroutine.running())  -- 获取正在运行的 coroutine
    local i = receive()
    while i do
        i = receive()
    end
end

function receive()
    local status, value = coroutine.resume(newProductor) -- 启动 coroutine 并获取返回值
    print("receive", value, status)
    return value
end

function send(x)
    print("send", x)
    coroutine.yield(x)                     -- 返回一个值并挂起
end

-- 这里都是由 main thread 负责的
newProductor = coroutine.create(productor) -- 创建但不启动 coroutine
consumer()

-->  consumer        nil
-->  productor       thread: 0xc81020
-->  send    0
-->  receive 0
-->  send    1
-->  receive 1
-->  send    2
-->  receive 2
-->  send    3
-->  receive 3
-->  receive nil

print(coroutine.resume(newProductor)) --> false    cannot resume dead coroutine
```

|序号|描述|控制权属于 main|控制权属于 newProductor|
|:-|:--------------------------|:---:|:-:|
|1|首先，我们通过 `coroutine.create()` 创建了一个 thread 类型的对象 `newProductor`，绑定到函数 `productor()`。根据输出结果可以看到，此时其并未启动。|√||
|2|main 继续调用 `consumer()` 函数，并通过 `coroutine.resume()` 的方式启动 `newProductor`，并等着获取抛出的值。||√|
|3|`newProductor` 启动，在 `productor()` 内部通过 `coroutine.yield(i)` 抛出一个值的同时将自身挂起；如果函数结束，则抛出 nil。|√||
|4.1|如果 main 在 `receive()` 中获取到了非 nil 值，则重复第二步。||√|
|4.2|如果 main 在 `receive()` 中获取到了 nil 值，这意味着 `newProductor` 已经正常结束，那 main 也需结束|√||
|5|截至目前 `status` 都是 true，但如果后续再次通过 `resume()` 尝试启动 `newProductor`，则会报错|√||

不难看出，其实协程就是通过用户编码的方式来将协程的切换行为委托给用户而非操作系统。虽然说是说 thread 类型的变量，但其实还是以用户态的形式运作的，和需要操作系统调度的「线程」有本质区别。

> 跟 C++ 的协程非常像，但开发效率高了不少。

### 文件 I/O

基本的文件操作有「打开」、「关闭」、「读」、「写」这四种。Lua 内置了一个全局 table 变量 `io`，实现了文件相关的成员函数，比如要打开一个文件可以用 `io.open(file [, mode = "r"])`，其中第一个参数为「**文件路径**」，第二个参数为「**打开方式**」。这种打开文件的操作和 C/C++ 几乎一致，就不赘述了。

`io.open()` 会返回一个文件句柄 `file`，其实现了以下成员函数：

|file 函数|描述|
|:-------------------------|:-------------------------------------------------------------------|
|file:close()               | 关闭文件。也可以通过 `file=nil` 使其被垃圾回收，但回收时间随机，不建议。 |
|file:read(...)             | 每个传入的参数为一种读取方式，对应一个返回值。有以下几种读取方式：<br>`"l"`:（**默认**）读一行，不包括换行符。**只能用于文本文件**。<br>`"L"`: 读一行，包括换行符。**只能用于文本文件**。<br>`"n"`: 读一个 number。<br>`"a"`: 从当前位置读整个文件。<br>`number`: 传入一个整数，读 number 个字节。<br>如果读取失败则返回 nil。|
|file:write(...)            | 将所有入参（**只能**是 string 或 number）写入文件。写入行为取决于 `open()` 中指定的打开方式。如果失败则返回 nil, errstring。 |
|file:lines(...)            | **迭代器函数**，能够指定和 `read()` 一样的读取方式循环读取文件直至 EOF。|
|file:flush()               | 将缓冲区内容落盘。 |
|file:seek(whence, offset=0)| 修改文件当前位置为 `base+offset`。第一个参数为 string，用于指定 base。<br>`"cur"`: （**默认**）base 为文件当前位置。<br>`"set"`: base 为文件起始位置。<br>`"end"`: base 为 EOF。<br>若成功则返回文件当前位置，否则返回 nil, errstring。|
|file:setvbuf(mode, size)   | 设置文件输出缓冲模式。<br>`"no"`: 无缓冲，任何写入都会落盘。<br>`"full"`: 全缓冲，仅当缓冲区满或显示调用 `flush()` 时落盘。<br>`"line"`: 行缓冲，遇到换行符时落盘。|

一些基本操作如下：

```lua file.lua
file = io.open("input.txt", "a+")  -- 以 append & 可读写 方式打开文件

file:write("hello world\n")        -- 此时 file 当前位置为 EOF

file:seek("set")                   -- 重新指向起始位置

for line in file:lines("l") do
    print(line)                    --> hello world
end
```

至于为什么要用 `:` 方式调用函数呢，可能内部有一个 `cur` 指向当前位置，需要传入 `self` 去查改。

> 虽然 `io` 对象也实现了若干成员函数，但只支持单文件操作，并不太想去了解。

### 异常处理

Lua 提供了两个**基本**异常处理函数：

- `assert(v, message="assertion failed!")`: 若表达式 `v` 不为 true，则程序中断，输出异常信息 `message`；
- `error(message, level=1)`: 中断程序，并输出异常信息 `message`。其中 `level` 用于控制位置信息，默认为 `1`，附带「文件名+函数内行号」，`0` 表示不添加位置信息，`2` 表示附带「文件名+调用函数行号」；

```lua error.lua
function func0()
    error("haha", 0)
end
function func1()
    error("haha", 1)
end
function func2()
    error("haha", 2)
end

func0() --> lua: haha
func1() --> lua: error.lua:5: haha
func2() --> lua: error.lua:13: haha
```

这两个函数都会在发生异常时中断程序，有些时候可能不是我们想要的行为。Lua 为我们提供了一种保护机制，使得即使某个函数抛出了异常，也能正确处理而非直接使程序终止，就是下面两个函数：

- `pcall(func, ...)`: 全称「protected call」。第一个返回值为 boolean，表示是否成功运行，后续返回值是要么是 `func(...)` 的返回值（如果调用成功），要么是异常信息（如果发生错误）；
- `xpcall(func, error_handler, ...)`: 比 `pcall()` 多了第二个参数，是一个只接受一个 string 参数的 function，当异常发生时会由 `error_handler(err)` 进行处理。第一个返回值为 boolean，表示是否成功运行，后续返回值是要么是 `func(...)` 的返回值（如果调用成功），要么是 `error_handler(err)` 的返回值（如果发生错误）；

Lua 内置了一个 debug 库，为我们提供了两个通用的 error_handler：

- `debug.debug()`：提供一个 Lua 提示符，让用户来检查错误的原因；
- `debug.traceback()`：根据调用栈来构建一个扩展的错误消息；

下面是基本用法

```lua error_handle.lua
function func()
    n = n / nil
end

success, res = pcall(func)
print(res)  --> test.lua:2: attempt to perform arithmetic on global 'n' (a nil value)

success, res = xpcall(func, debug.traceback)
print(res)  --> test.lua:2: attempt to perform arithmetic on global 'n' (a nil value)
            --> stack traceback:
            -->         test.lua:2: in function <test.lua:1>
            -->         [C]: in function 'xpcall'
            -->         test.lua:12: in main chunk
            -->         [C]: ?
```

> debug 库提供的 error_handler 也不止上面这两个，用到再学吧。