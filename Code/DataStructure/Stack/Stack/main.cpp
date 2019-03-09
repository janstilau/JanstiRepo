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


int main(int argc, const char * argv[]) {
    return 0;
}
