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
        //        value = mData[mLength]; 这个思路有问题, mLength 记录的应该是下一个可插入的位置, 所以这里应该是 mLength - 1
        value = mData[mLength - 1];
        --mLength;
        return true;
    }
    
    int top() {
        if (mLength <= 0) { return -1; }
        return mData[mLength-1];
    }
};

void sortStock(const MyStack& stack) {
    if (!stack.mLength) { return; }
    MyStack cacheStack;
    while (stack.mLength) {
        int currentValue;
        stack.pop(currentValue);
        if (!cacheStack.mLength) {
            cacheStack.push(currentValue);
            continue;
        }
        if (cacheStack.top >= currentValue) {
            cacheStack.push(currentValue);
            continue;
        }
        while (cacheStack.mLength && cacheStack.top < currentValue) {
            stack.push(cacheStack.pop());
        }
        cacheStack.push(currentValue);
    }
}

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
};

/*
 循环队列, 就是 用 %操作, 算出下一个插入的位置, 这样, 出队之后空余出来的前半部分的空间还能继续使用. 但是需要注意的是, 这个时候的队列的空满判断, 就有了改变, 如果不是循环队列, 空是指头指针和尾指针相同, 满则是尾指针到达最大位置. 而循环队列, 空还是两个指针相同, 满则是尾指针是头指针上一个位置. 判断则公式则是 (front+1)%n=end. 也就是说, 循环队列浪费了一个空间, 当做满的标志.
 */

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

// 不带头结点的链表模拟栈.
/*
 用链表模拟栈, 那么链表必然是头插法. 因为只有用头插法, 才能保持入栈出栈操作的时间复杂度为o1.
 */

struct LNode {
    int data;
    LNode *next;
};

void initStackL(LNode *&LNode) {
    LNode = nullptr;
}

bool isEmpty(LNode &l) {
    return l == nullptr;
}

void push(LNode *&l, int data) {
    LNode *newNode = (LNode *)malloc(sizeof(LNode));
    newNode->data = data;
    newNode->next = l;
    l = newNode;
}

void pop(Lnode *&l, int &result) {
    if (l == nullptr) { return; }
    result = l->data;
    l = l->next;
}

/*
 对于队列和栈, 能够用链表模拟, 也能够用数组模拟. 因为, 这两个都是线性表, 而队列和栈, 则是访问受限的线性表. 用数组模拟的场景比较简单, 可以直接用数字代表指针, 也就是利用了数组随机访问的特性. 用链表模拟栈, 一定要用头插法, 这样才能达到插入删除 O1的目的, 而链队, 则需要维护两个指针, 并且在第一个入队, 和最后一个出队的时候, 需要同时操作这两个指针. 这个时候, 队列为空就不是 head == tail, 而是 head == null 或者 tail == null. 在第一个入队的时候, head 和 tail 指向同一个位置, 当队列为空的时候, head tail 都置为 null.
 */

/*
 抽象数据类型, ADT, abstract data type. 是对功能的一种描述, 只关心对象的外在表现, 而不关心对象的内在实现. 栈和队列, 更多的是一种抽象数据类型, 只要满足了先入先出, 陷入后出的这种模型的对象, 都能够称之为栈, 队列, 而具体实现的方式, 或者是数组, 或者是链表, 也可以用其他的实现模型.
 */

int main(int argc, const char * argv[]) {
    return 0;
}



   
