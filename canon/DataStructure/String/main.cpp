//
//  main.cpp
//  String
//
//  Created by JustinLau on 2019/3/10.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#include <iostream>

/*
 串就是内容受限的线性表.
 */

struct MyStr {
    char *ch;
    int length;
};

bool strAssign(MyStr &str, char *ch) {
    if (!ch) { return false; }
    /*
     有着外部存储的类, 要在赋值操作的时候, 将自身的资源进行释放.
     这里需要判断, 如果外部资源, 就是内部资源, 那么直接 return.
     */
    if (str.ch == ch) { return true; }
    if (str.ch) {
        free(str.ch);
        str.ch = nullptr;
        str.length = 0;
    }
    
    int length = 0;
    char *chIterator = ch;
    while (*chIterator) {
        ++length;
        chIterator = ch + length;
    }
    if (!length) {return true;} // 这里原来忘了判断
    
    char *copyCh = (char *)malloc(sizeof(char) * (length+1));
    if (!copyCh) { return false; }
    memcpy(copyCh, char, length);
    copyCh[length] = '\0';
    str.ch = copyCh;
    str.length = length;
    return true;
}

int strLength(MyStr &str) {
    return str.length;
}

// 这里写的有点问题, 为什么要有两个 it 作为迭代器, 一个就够了
bool strCompare(const MyStr &left, const MyStr& right) {
    if (!left.ch) { return true; }
    if (!right.ch) { return false; }
    int lIt = 0;
    int rIt = 0;
    while (lIt < left.length && rIt < right.length) {
        char leftc = left.ch[lIt];
        char rightc = right.ch[rIt];
        if (leftc == rightc) { ++lIt; ++rIt; continue;}
        return leftc - rightc;
    }
    return right.length > left.length;
}

int main(int argc, const char * argv[]) {
    // insert code here...
    std::cout << "Hello, World!\n";
    return 0;
}
