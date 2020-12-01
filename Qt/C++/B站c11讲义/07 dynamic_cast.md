# dynamic_cast

用于具有**虚函数的基类**与**派生类**之间的**指针或引用**的转换。

- ##### 基类必须具备虚函数

  原因：dynamic_cast是**运行时类型检查**，需要运行时类型信息(RTTI)，而这个信息是存储与类的**虚函数表**关系紧密，只有一个类定义了虚函数，才会有虚函数表。

- ##### 运行时检查，转型不成功则返回一个空指针

- ##### 非必要不要使用dynamic_cast，有额外的函数开销

  

常见的转换方式：

- 基类指针或引用转派生类指针（**必须使用**dynamic_cast）

- 派生类指针或引用转基类指针（可以使用dynamic_cast,但是**更推荐使用static_cast**）



```C++
#include "stdafx.h"
#include <iostream>
#include <string>

//基类与派生类之间的转换

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
public:
    virtual void foo() {
        std::cout << "CSon::void foo()" << std::endl;
    }
};

int main() {
    CFather f;
    CSon s;
    CFather* pFather = &f;
    CSon* pSon = &s;

    //父类转子类（不安全）
    //pSon = pFather;
    pSon = dynamic_cast<CSon*>(pFather); //运行时的检测,返回空
    //pSon->foo(); //运行时，pSon为NULL

    //pFather = static_cast<CFather* >(&s); //子类转父类，安全
    pFather = dynamic_cast<CFather* >(&s); //子类转父类也可以通过dynamic_cast，但不是必须的
    pSon = dynamic_cast<CSon*>(pFather); //运行时的检测,可以通过类型检测
    pSon->foo();
}
```

