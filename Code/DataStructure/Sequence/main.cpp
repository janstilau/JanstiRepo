//
//  main.cpp
//  Sequence
//
//  Created by JustinLau on 2019/3/7.
//  Copyright © 2019年 JustinLau. All rights reserved.
//

#include <iostream>

using namespace std;

const int kMaxSize = 100;

struct SList {
    int data[kMaxSize];
    int length;
}

int findElem(const SList &l, int x) {
    int index = 0;
    for (; index < l.length ; ++index) {
        if (l.data[index] > x) {
            return index;
        }
    }
    return index;
}

void insertElem(SList &l, int x) {
    int index = findElem(l, x);
    if (index == kMaxSize) { return; }// 越界报错
//    for (int i = l.length - 1; i > index; --i) {
//        l.data[i] = l.data[i-1];
//    } 算法有问题, 最后一个元素的值没有转移
    for (int i = l.length - 1; i >= index; --i) {
        l.data[i+1] = l.data[i];
    }
    l.data[index] = x;
    ++l.length;
}

struct LNode {
    int data;
    LNode *next;
}

struct LNode {
    int data;
    struct LNode* next;
};

void merge(LNode *l, LNode *r, LNode *&result) {
    if (!l->next && !r->next) { return; }
    if (!l->next) { result = r; return;}
    if (!r->next) { result = l; return;}
    
    result = (LNode *)malloc(sizeof(LNode));
    result->data = -1;
    result->next = 0;
    
    LNode *lCurrent = l->next;
    LNode *rCurrent = r->next;
    LNode *resultCurrent - result;
    while (lCurrent && rCurrent) {
        if (lCurrent->data <= rCurrent) {
            resultCurrent->next = lCurrent;
            resultCurrent = resultCurrent->next;
            lCurrent = lCurrent->next;
        } else {
            resultCurrent->next = rCurrent;
            rCurrent = rCurrent->next;
        }
    }
    if (lCurrent) {
        resultCurrent->next = lCurrent;
    } else {
        resultCurrent->next = rCurrent;
    }
}




int main(int argc, const char * argv[]) {
    
    
    
    return 0;
}
