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

// 面试题16：数值的整数次方
// 题目：实现函数double Power(double base, int exponent)，求base的exponent
// 次方。不得使用库函数，同时不需要考虑大数问题。

#include <iostream>
#include <cmath>

bool g_InvalidInput = false;
bool equal(double num1, double num2);
double PowerWithUnsignedExponent(double base, unsigned int exponent);

double Power(double base, int exponent)
{
    g_InvalidInput = false;

    if (equal(base, 0.0) && exponent < 0) {
        /*
         在这种情况下, 就会求出现 1/0 的情况, 是不合法的.
         */
        g_InvalidInput = true;
        return 0.0;
    }

    /*
     一个简单的, 求绝对值的过程.
     */
    unsigned int absExponent = (unsigned int) (exponent);
    if (exponent < 0){
        absExponent = (unsigned int) (-exponent);
    }

    double result = PowerWithUnsignedExponent(base, absExponent);
    if (exponent < 0)
        result = 1.0 / result;

    return result;
}

/*
 最基本的写法, 这个写法就是利用循环, 计算 exponent 次乘方的操作.
double PowerWithUnsignedExponent(double base, unsigned int exponent)
{
    double result = 1.0;
    
    for (int i = 1; i <= exponent; ++i)
        result *= base;

    return result;
}
*/

double PowerWithUnsignedExponent(double base, unsigned int exponent)
{
    if (exponent == 0)
        return 1;
    if (exponent == 1)
        return base;

    
    // >> 1 替换 除以 2 的操作, & 0x01 替换取余判断偶数的操作. 位运算符的计算, 要比操作符的计算快很多很多.
    /*
     33 16 8 4 2 1 0
     32 16 8 4 2 1 0
     所以, >> 1 操作, 最后都会到达上面的两个条件.
     
     27 13 6
           6
        13 6
           6
     
     33 16  8   4   2   1
                        1
                    2   1
                        1
                4   2   1
                        1
                    2   1
                        1
            8   4   2
                    2
                4   2
                    2
        16  8   4
                4
            8   4
                4
     */
    /*
     不要去构思递归的发散图, 而是想出临界点来. 然后想出, 在拿到结果, 之前之后, 应该进行什么样的操作. 将递归的复杂度, 控制起来.
     人脑不适合做发散工作, 因为递归的发散网, 是指数级别增长的.
     */
    double result = PowerWithUnsignedExponent(base, exponent >> 1);
    result *= result; // 这一步的计算, 可以大大的减少循环的次数. logn 级别减少的.
    if ((exponent & 0x1) == 1)
        result *= base;

    return result;
}

/*
 浮点型的数值, 需要特殊的判断技巧. 也就是差值在一个特殊的范围之内才可以.
 */
bool equal(double num1, double num2)
{
    if ((num1 - num2 > -0.0000001) && (num1 - num2 < 0.0000001))
        return true;
    else
        return false;
}

// ====================测试代码====================
void Test(const char* testName, double base, int exponent, double expectedResult, bool expectedFlag)
{
    double result = Power(base, exponent);
    if (equal(result, expectedResult) && g_InvalidInput == expectedFlag)
        std::cout << testName << " passed" << std::endl;
    else
        std::cout << testName << " FAILED" << std::endl;
}

int main(int argc, char* argv[])
{
    // 底数、指数都为正数
    Test("Test1", 2, 3, 8, false);

    // 底数为负数、指数为正数
    Test("Test2", -2, 3, -8, false);

    // 指数为负数
    Test("Test3", 2, -3, 0.125, false);

    // 指数为0
    Test("Test4", 2, 0, 1, false);

    // 底数、指数都为0
    Test("Test5", 0, 0, 1, false);

    // 底数为0、指数为正数
    Test("Test6", 0, 4, 0, false);

    // 底数为0、指数为负数
    Test("Test7", 0, -4, 0, true);

    return 0;
}
