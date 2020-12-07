# 强制转换运算符----const_cast

强制类型转换是有一定风险的，有的转换并不一定安全，如把**整型**数值转换成**指针**，把**基类指针**转换成**派生类指针**，把**一种函数指针**转换成**另一种函数指针**，把**常量指针**转换成**非常量指针**等。

C++ 引入新的强制类型转换机制

#### 强制转换运算符

C++ 引入了四种功能不同的强制类型转换运算符以进行强制类型转换：

- const_cast

- static_cast

- reinterpret_cast

- dynamic_cast

##### C语言强制类型转换缺点：

主要是为了克服C语言强制类型转换的以下三个缺点。

- 没有从形式上体现转换功能和风险的不同。

  例如，将 int 强制转换成 double 是没有风险的，而将常量指针转换成非常量指针，将基类指针转换成派生类指针都是高风险的，而且后两者带来的风险不同（即可能引发不同种类的错误），C语言的强制类型转换形式对这些不同并不加以区分。

- 将多态基类指针转换成派生类指针时不检查安全性，即无法判断转换后的指针是否确实指向一个派生类对象。

- 难以在程序中寻找到底什么地方进行了强制类型转换。

  强制类型转换是引发程序运行时错误的一个原因，因此在程序出错时，可能就会想到是不是有哪些强制类型转换出了问题。



----



#### const_cast

仅用于进行去除 const 属性的转换，它也是四个强制类型转换运算符中唯一能够去除 const 属性的运算符。

##### ***\*常量对象或者是基本数据类型不允许转化为非常量对象，只能通过指针和引用来修改：\****

```
#include "stdafx.h"
#include <iostream>
#include <string>

int main() {
    const int n = 5;
    const std::string s = "Inception";

    std::string t = const_cast<std::string>(s); //错误
    int k = const_cast<int>(n); //错误
}
```

**\**可以利用* const_cast 转换为同类型的非 const 引用或者指针：\***

```c++

#include "stdafx.h"
#include <iostream>
#include <string>

int main() {
    const int n = 5;
    const std::string s = "Inception";

    std::string& t = const_cast<std::string&>(s); //转换成引用
    int* k = const_cast<int*>(&n); //转换成指针
    *k = 6; //转换后指针指向原来的变量
    t = "Hello World!";
}
```

**\*常成员函数中去除this指针的const属性：\***

```c++
#include "stdafx.h"
#include <iostream>
#include <string>

class CTest
{
public:
    CTest() : m_nTest(2) {}

    void foo(int nTest) const {
        //m_nTest = nTest; 错误
        const_cast<CTest*>(this)->m_nTest = nTest;
    }

public:
    int m_nTest;
};

int main() {
    CTest t;
    t.foo(1);
}
```

