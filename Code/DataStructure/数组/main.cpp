//
//  main.cpp
//  Sequence
//
//  Created by JustinLau on 2019/3/7.
//  Copyright © 2019年 JustinLau. All rights reserved.
//

#include <iostream>
/*
 数组的是一块连续的内存空间, 所以, 必须预先分配内存.
 从存储效率上来说, 数组里面完全存放的是值信息, 所以空间利用率大, 但是, 过多的分配数组空间, 会导致整个数组的有效值个数降低, 而过小的分配数组空间, 会引起数组的频繁扩容, 复制. 所以, 在各个数组容器类的时候, 都有着 dataCapacity 这样的一个值, 如果能够预先预估整个数组的大小, 在分配数组的时候指定空间, 能够大大的减少扩容的次数.
 根本没有无线延伸的数组的概念, 各个容器类只不过事先把扩容的操作封装到了自己的内部.
 数组最大的优势就是随机访问, 这是因为, 数组的角标和数组的开始地址能够直接计算出数据的位置.
 优化数组的策略有:
 插入操作, 如果不用保持数组的数据, 可以直接将插入位置的元素放置到数组的末尾, 然后将插入值插入到传入位置.
 删除操作, 如果是多次的删除操作, 可以将被删除的位置设置为删除标志位, 然后在所有的删除结束之后, 统一做一次数组的位置偏移, 这样能大大减少数组的位置偏移的操作.
 */

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

bool deleteElem(Slist &l, int index, int &value) {
    if (index < 0 && index >= l.length) { return false; }
    value = l.data[index];
    for (int i = index; i < l.length - 1; ++i) {
        l.data[i] = l.data[i+1];
    }
    --l.length;
}


int main(int argc, const char * argv[]) {
    return 0;
}
