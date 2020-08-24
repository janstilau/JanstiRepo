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
 从存储效率上来说, 数组里面完全存放的是值信息, 所以空间利用率大, 但是, 过多的分配数组空间, 会导致整个数组的有效值个数降低, 而过小的分配数组空间, 会引起数组的频繁扩容, 复制.
 所以, 在各个数组容器类的时候, 都有着 dataCapacity 这样的一个值, 如果能够预先预估整个数组的大小, 在分配数组的时候指定空间, 能够大大的减少扩容的次数.
 
 根本没有无线延伸的数组的概念, 各个容器类只不过事先把扩容的操作封装到了自己的内部.
 数组最大的优势就是随机访问, 这是因为, 数组的角标和数组的开始地址能够直接计算出数据的位置.
 
 优化数组的策略有:
 插入操作, 如果不用保持数组的数据, 可以直接将插入位置的元素放置到数组的末尾, 然后将插入值插入到传入位置.
 删除操作, 如果是多次的删除操作, 可以将被删除的位置设置为删除标志位, 然后在所有的删除结束之后, 统一做一次数组的位置偏移, 这样能大大减少数组的位置偏移的操作.
 一年后, 发现上面的优化有点问题, 使用数组, 就是为了他的有序的特定, 根据角标快速的进行访问. 上面的优化, 都建立在顺序无效的基础上, 那这个时候, 就不应该使用数组这个数据结构.
 */

using namespace std;

const int kMaxSize = 100;

struct SList {
    int data[kMaxSize];
    int length;
}

int findElem(const SList &l, int x) {
//    int index = 0;
//    提前进行 index 的定义这样写不好, for 的结构开始就是为了初始化数据.
//    不如把 index 放到 for 中, 而且放到 for 中, index 的可访问区域会减少很多.
    for (int index = 0; index < l.length ; ++index) {
        if (l.data[index] == x) {
            return index;
        }
    }
    return -1;
}

/*
 一个数据结构, 里面的各个成员属性都应该发挥作用. length 可以快速的指明当前数组的长度. 代价就是, 在各个算法的内部, 都要维护该值.
 在设计类的时候, 维护类的各个数据的有效性, 是类的设计者的责任.
 */
void insertElem(SList &l, int x) {
    if (l.length+1 >= kMaxSize) { return; } // 此时应该进行扩容, 不过这个简单例子没有处理
    if (x < 0 || x > l.length) { return; } // 此时应该报错.
    // 数据后移, 留出插入的位置.
    for (int i = l.length - 1; i >= index; --i) {
        l.data[i+1] = l.data[i];
    }
    // 插入操作
    l.data[index] = x;
    // 每个必要的位置, 进行 length 的维护.
    ++l.length;
}

/*
 删除特定位置的值, 通过传出参数返回该值.
 */
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
