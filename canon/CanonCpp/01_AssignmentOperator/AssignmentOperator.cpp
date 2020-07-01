/*******************************************************************
Copyright(c) 2016, Harry He
All rights reserved.

Distributed under the BSD license.
(See accompanying file LICENSE.txt at
https://github.com/zhedahht/CodingInterviewChinese2/blob/master/LICENSE.txt)
*******************************************************************/

//==================================================================
// 《剑指Offer——名企面试官精讲典型编程题》代码
// 作者：何海涛
//==================================================================

// 面试题1：赋值运算符函数
// 题目：如下为类型CMyString的声明，请为该类型添加赋值运算符函数。

#include<cstring>
#include<cstdio>

class CMyString
{
public:
    CMyString(char* pData = nullptr);
    /*
     拷贝构造函数, 传入 const 类型&
     */
    CMyString(const CMyString& str);
    ~CMyString(void);

    /*
     赋值函数, 传入 const 类型&
     */
    CMyString& operator = (const CMyString& str);

    void Print();
      
private:
    char* m_pData;
};

CMyString::CMyString(char *pData)
{
    if(pData == nullptr) {
        // 如果是空字符串, 也要分配内存空间, 用 /0 来代表结束
        m_pData = new char[1];
        m_pData[0] = '\0';
    } else {
        int length = strlen(pData);
        m_pData = new char[length + 1];
        strcpy(m_pData, pData);
    }
}

CMyString::CMyString(const CMyString &str)
{
    int length = strlen(str.m_pData);
    m_pData = new char[length + 1];
    strcpy(m_pData, str.m_pData);
}

CMyString::~CMyString()
{
    /*
     在析构函数里面, 要进行资源的释放工作.
     */
    delete[] m_pData;
}

/*
 在赋值函数里面, 要进行原有资源的释放工作, 而在拷贝构造函数里面, 这一步可以省略.
 */
CMyString& CMyString::operator = (const CMyString& str)
{
    if(this == &str)
        return *this;

    delete []m_pData;
    m_pData = nullptr;

    m_pData = new char[strlen(str.m_pData) + 1];
    strcpy(m_pData, str.m_pData);

    return *this;
}

// ====================测试代码====================

/*
 各种测试用例, 要将自己代码中考虑的点都暴露出来.
 应该说, 是现有测试用例的考虑, 才进行的代码的编写.
 
 写测试用例, 原始值, 期望值, 实际值.
 或者可以进行逻辑判断, 比如期望值和实际值相同, 输出 pass, 否则输出 fail, 并且写出原因来.
 测试用例的代码, 可以不那么漂亮.
 */
void CMyString::Print()
{
    printf("%s", m_pData);
}
