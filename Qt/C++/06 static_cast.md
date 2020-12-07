# static_cast

基本等价于隐式转换的一种类型转换运算符，可使用于需要明确隐式转换的地方。

##### **可以**用于低风险的转换。

- 整型和浮点型

- 字符与整形
- 转换运算符
- ***\*空指针转换为任何目标类型的指针\****

##### **不可以**用与风险较高的转换

- 不同类型的指针之间互相转换
- 整型和指针之间的互相转换
- 不同类型的引用之间的转换

```c++
#include <iostream>
#include <string>

class CInt{
public:
    operator int() {
        return m_nInt;
    }

    int m_nInt;
};

int main() {
    int n = 5;
    double dbl = n;
    char ch = 'a';

    //整型与浮点型
    dbl = static_cast<double>(n);

    //整型与字符型
    ch = static_cast<char>(n);

    //转换运算符
    CInt nObj;
    int k = static_cast<int>(nObj);
}
```



##### static_cast用于基类与派生类的转换过程中，但是没有运行时类型检查。

```c++
#include "stdafx.h"
#include <iostream>
#include <string>

class CFather
{
public:
    CFather() {
        m_nTest = 3;
    }

    virtual void foo() {
        std::cout << "CFather()::void foo()" << std::endl;
    }

    int m_nTest;
};

class CSon : public CFather
{
    virtual void foo() {
        std::cout << "CSon::void foo()" << std::endl;
    }
};

int main() {
    CFather* pFather = nullptr;
    CSon* pSon = nullptr;

    //pFather = pSon;
    //pFather = static_cast<CFather*>(pSon);

    //pSon = pFather;
    pSon = static_cast<CSon*>(pFather);
   
}
```

