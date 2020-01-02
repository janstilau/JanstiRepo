//
//  main.cpp
//  test
//
//  Created by JustinLau on 2019/12/13.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#include <iostream>

using namespace std;

/*
    C语言不支持函数重载
    C++支持函数重载
*/

//int sum(int v1, int v2) {
//    return v1 + v2;
//}
//
//int sum(int v1, int v2, int v3) {
//    return v1 + v2 + v3;
//}

//void func(int v1, double v2) {
//    cout << "func(int v1, double v2)" << endl;
//}
//
//void func(double v1, int v2) {
//    cout << "func(double v1, int v2)" << endl;
//}


// 歧义，二义性
//int func(int a) {
//    return 0;
//}
//
//double func() {
//    return 0;
//}

// display_v
void display() {
    cout << "display()" << endl;
}

// display_i
void display(int a) {
    cout << "display(int) - " << a << endl;
}

// display_l
void display(long a) {
    cout << "display(long) - " << a << endl;
}

// display_d
void display(double a) {
    cout << "display(double) - " << a << endl;
}

// Debug模式：很多调试信息，生成的可执行文件比较臃肿
// Release模式：去除调试信息，生成的可执行文件比较精简、高效

// 反汇编
// 逆向工程
int main() {

    display();
    display(10);
    display(10L);
    display(10.0);
    
    // 1010 1010 1111 0001 1010 1011
    // AA F1 AB

    // func(10, 10.5);
    // func(10.5, 10);

    // cout << sum(10, 20) << endl;
    // cout << sum(10, 20, 30) << endl;

    getchar();
    return 0;
}
