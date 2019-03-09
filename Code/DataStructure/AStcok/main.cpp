//
//  main.cpp
//  Stack
//
//  Created by JustinLau on 2019/3/8.
//  Copyright © 2019 JustinLau. All rights reserved.
//

/*
 栈是操作受限的线性表, 只允许一段插入和删除数据.
 特定的数据结构, 是对特定的场景的抽象, 而数组和链表暴露的操作接口太多, 在操作上灵活自由, 但是使用的时候不可控, 更加容易出错.
 */
#include <iostream>

using namespace std;

static const int kStackDefaultSize = 10000;

struct MyStack {
    int mData[10000];
    int mLength = 0;
    int mMaxSize = kStackDefaultSize;
    
    bool push(int value) {
        if (mLength >= mMaxSize - 1) { return false; }
        mData[mLength] = value;
        ++mLength;
        return true;
    };
    
    bool pop(int &value) {
        if (mLength <= 0) { return false; }
        //        value = mData[mLength]; 这几思路有问题, mLength 记录的应该是下一个可插入的位置, 所以这里应该是 mLength - 1
        value = mData[mLength - 1];
        --mLength;
        return true;
    }
};

struct MyQueue {
    int mData[10000];
    int size;
    int head;
    int tail;
    
    MyQueue(){
        size = head = tail = 0;
    }
    //    原始版本
    //    bool enqueue(int i) {
    //        if (tail == 100000) { return false; }
    //        mData[tail++] = i;
    //        size++;
    //        return true;
    //    }
    //    自动重排版本
    bool enqueue(int i) {
        if (tail == 10000) {
            if (head == 0) { return false;}
            for(int index = head; index < tail; index++) {
                mData[index-head] = mData[index];
            }
            head = 0;
            tail = size;
            return enqueue(i);
        }
        mData[tail++] = i;
        size++;
        return true;
    }
    bool dequeue(int &result) {
        if (head == tail) { return false; }
        result = mData[head++];
        size--;
        return true;
    }
    int count() const {
        return size;
    }
    
    bool isEmpty() const {
        return size == 0;
    }
};

struct AutoMallocQueue {
    int *mData;
    int mMaxSize;
    int mSize;
    int mHead;
    int mTail;
    
    static const int kDeafultQeueueSize;
    AutoMallocQueue():mMaxSize(0), mSize(0), mHead(0), mTail(0) {
        mData = (int *)malloc(sizeof(int));
        mMaxSize = AutoMallocQueue::kDeafultQeueueSize;
    }
    bool expandSize() {
        int *newData = (int *)malloc(sizeof(int) * mMaxSize * 2);
        if (!newData) { return false; }
        memcpy(newData, mData, mSize);
        free(mData);
        mMaxSize = mMaxSize * 2;
        mData = newData;
        return true;
    }
    
    void compressQueue() {
        for(int index = mHead; index < mTail; index++) {
            mData[index-mHead] = mData[index];
        }
        mHead = 0;
        mTail = mSize;
    }
    
    bool enqueue(int value) {
        if (mTail == mMaxSize) {
            if (mHead == 0) {
                if(expandSize()) { return false; }
                return enqueue(value);
            }
            compressQueue();
            return enqueue(value);
        }
        mData[mTail++] = value;
        mSize++;
        return true;
    }
};

const int AutoMallocQueue::kDeafultQeueueSize = 1000;

struct Node {
    int mData;
    Node *next;
};

struct LinkQueue {
    int mSize;
    Node *mHead;
    Node *mTail;
    
    LinkQueue():mSize(0), mHead(nullptr), mTail(nullptr){}
    
    bool enqueue(int value) {
        Node* newNode = (Node*)malloc(sizeof(Node));
        if (!newNode) { return false; }
        newNode->mData = value;
        newNode->next = nullptr;
        if (!mHead) {
            mHead = newNode;
            mTail = newNode;
            return true;
        }
        mTail->next = newNode;
        mTail = newNode;
        mSize++;
        return true;
    }
    
    bool dequeue(int &value) {
        if (!mSize) { return false; }
        value = mHead->mData;
        Node *headNext = mHead->next;
        free(mHead);
        mHead = headNext;
        --mSize;
        return true;
    }
};

// 例题, 判断小括号匹配
/*
 在解决问题的时候, 出现了一个子问题, 现有的条件不能解决他, 需要记下, 等到子问题解决之后在回来解决原有的问题, 这个时候就要用到栈, 因为栈有着记忆的功能.
 这其实就是递归的思路, 或者说, 递归的思路就是栈的思路. 所以, 递归本质上就是一个栈的使用.
 */
bool match(char exp[], int n) {
    MyStack bracketContainer;
    for (int i = 0; i < n; ++i) {
        char oneChar = exp[i];
        if (oneChar == '(') {
            bracketContainer.push(oneChar);
        } else if (oneChar == ')') {
            if (bracketContainer.mLength == 0) {
                return false;
            } else {
                int value;
                bracketContainer.pop(value);
            }
        }
    }
    if (bracketContainer.mLength) { return false; }
    return true;
}

// 例题, 后缀表达式求值.
/*
 (a+b+c*d)/e, 后缀表达为 abcd*++e/, 后缀表达式是没有运算符优先级问题的.
 后缀表达式, 当扫描到字符的时候, 应该怎么计算字符的值, 这个时候没有出现运算符的时候是没有办法计算的. 所以, 要先存储之前的字符值, 等到运算符的时候在取出计算, 这符合我们刚才提到的栈的使用场景.
 */

int op(int left, int right, char operatorChar) {
    return 0;// 按照 +, -, *, / 返回运算的结果.
}
// 按理说, 这里应该有着对于表达式的错误检查, 所以, 应该有着一个 error 值作为判断格式正确与否的表示.
int compute(char exp[]) {
    MyStack numStack;
    int result = -1;
    for (int i = 0; exp[i] != '\0'; i++) {
        if ('0' <= value && value <= '9') {
            numStack.push(value - '0');// 这里, 应该对字符数字进行一次转化. 因为我们知道 Stack 里面, 存放的就应该是数值.
        } else {
            int right;
            numStack.pop(right);
            int left;
            numStack.pop(left);
            int opResult = op(left, right, value);
            numStack.push(opResult);
        }
    }
    numStack.pop(result);
    return result;
}

int main(int argc, const char * argv[]) {
    return 0;
}
