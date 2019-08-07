//
//  main.cpp
//  链表
//
//  Created by JustinLau on 2019/3/8.
//  Copyright © 2019年 JustinLau. All rights reserved.
//

#include <iostream>
using namespace std;

/*
 链表就是结点的串联, 而结点中有着两部分含义的数据, 数据域和指针域.
 链表的优势在于, 不用实现分配内存空间, 可以利用内存中零散的内存进行串联, 但是这也有个不好的地方, 每次需要新的结点, 释放原有结点都要进行内存的分配.
 链表没有满的概念. 但是有着长度的概念. 一般来说, 我们自己的封装链表, 都要有着 length 这个数据. 这样, 每次进行操作的时候, 不用进行遍历操作, 直接根据 length 的值判断链表的长度. 类似的, 数组那里也有着length , 但数组如果没有这个值, 根本不知道数组的长度. 而链表因为可以判断尾节点为NULL, 知道链表的范围.
 根据尾节点为 NULL 当然可以知道链表的长度, 但是封装的意义就在于, 可以在链表操作的时候, 及时更新 length 的值. 这个更新操作是在链表类的内部的, 所以类的设计者可以进行控制. 这里也是类和结构体的区别, 结构器的 public 作用域导致, 每次操作, 相当于更新一个 public 的成员变量, 既然是 public, 那么任何人任何地方都可以修改. 而类, 则可以限制 length 只在某些地方进行修改.
 双向链表在操作的方便性以及代码的简介性上都有很大的帮助, 所以实际的工作中, 大量的使用了双向链表.
 链表操作, 注意不要丢失指针, 也就是在进行结点内指针的指向前, 要注意保存原有的指向.
 要注意边界条件, 因为边界条件的代码一般和常规逻辑不符.
 哨兵, 可以理解为减少特殊情况的判断, 就和 guard 函数一样, 既可以保持程序的逻辑一致和整洁, 也可以加快程序的效率. 提前将小概率情况进行处理, 在后续的处理中, 可以在循环中减少每次都对于特殊情况的判断, 如果是大量的操作的话, 是很有好处的.
 在需要手动管理内存的环境里面, 注意内存的分配和释放.
 */

struct LNode {
    int data;
    LNode *next;
};

//
void sortMerge(LNode *l, LNode *r, LNode *&result) {
    if (!l->next && !r->next) { return; }
    if (!l->next) { result = r; return;}
    if (!r->next) { result = l; return;}
    // 这里假设 l, r 都有头结点, 所以 result 也就设计了拥有头结点. 这里能够看出 手动管理内存的风险, 如果多个链表中拥有相同的结点, 那么到底在删除结点的时候, 该不该释放内存呢.
    result = (LNode *)malloc(sizeof(LNode));
    result->data = -1;
    result->next = 0;
    
    LNode *lCurrent = l->next;
    LNode *rCurrent = r->next;
    LNode *resultCurrent = result;
    while (lCurrent && rCurrent) {
        if (lCurrent->data <= rCurrent->data) {
            resultCurrent->next = lCurrent;
            resultCurrent = resultCurrent->next;
            lCurrent = lCurrent->next;
        } else {
            resultCurrent->next = rCurrent;
            resultCurrent = resultCurrent->next;
            rCurrent = rCurrent->next;
        }
        resultCurrent->next = nullptr;// 这一步其实可以去掉, 因为下面一定会执行.
    }
    if (lCurrent) {
        resultCurrent->next = lCurrent;
    } else {
        resultCurrent->next = rCurrent;
    }
}

// 尾插法, 这里, 默认是建立一个带有头结点的链表.
void createListInTail(LNode *&result, int *source, int n) {
    result = nullptr;
    if (!source) { return; }
    if (n <= 0) { return; }
    result = (LNode *)malloc(sizeof(LNode));
    result->data = -1;
    result->next = nullptr; // 建立头结点.
    
    LNode *current = result;
    for (int i = 0; i < n; ++i) {
        current->next = (LNode *)malloc(sizeof(LNode));
        current = current->next;
        current->data = source[i];
    }
    current->next = nullptr;
}

// 头插法
// 头插法的倒序操作, 其实可以用在上面 merge 的时候, 进行递减 merge. 不过, 在最后的时候, 要把剩余那个没有遍历完的链表, 继续头插到 result 中.
void createListInHead(LNode *&result, int *source, int n) {
    result = nullptr;
    if (!source) { return; }
    if (n <= 0) { return; }
    result = (LNode *)malloc(sizeof(LNode));
    result->data = -1;
    result->next = nullptr;
    
    for (int i = n - 1; i >= 0; --i) { // 头插法会让数组逆序, 所以, 这里其实要逆序遍历数组.
        LNode *newNode = (LNode *)malloc(sizeof(LNode));
        newNode->next = result->next;
        result->next = newNode;
    }
}


bool findAndDelete(LNode *list, int target) {
    if (!list) { return false; }
    LNode *previous = list;
    LNode *current = list->next;
    while (current) {
        if (current->data == target) {
            previous->next = current->next;
            free(current);
            return true;
        }
        previous = current;
        current = current->next;
    }
    
    return false;
}

void reversList(LNode *list) {
    if (!list) { return; }
    if (!list->next || !list->next->next) { return; }
    LNode *previous = list->next;
    LNode *current = previous->next;
    previous->next = nullptr;
    while (current) {
        LNode *cacheNext = current->next;// 注意保存, 不要丢失后续结点的指针
        current->next = previous;
        previous = current;
        current = cacheNext;
    }
    list->next = previous;
}


int main(int argc, const char * argv[]) {
    // insert code here...
    std::cout << "Hello, World!\n";
    return 0;
}
