//
//  main.cpp
//  Sort2
//
//  Created by JustinLau on 2019/3/9.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#include <iostream>

/*
 归并排序 和 快速排序, 时间复杂度都是 nlogn, 适合大规模的排序.
 
 归并排序:
 归并排序的核心思想还是蛮简单的。如果要排序一个数组，我们先把数组从中间分成前后两部分， 然后对前后两部分分别排序，再将排好序的两部分合并在一起，这样整个数组就都有序了。
 归并排序用到了分治的思想, 分而治之, 大问题分为小问题, 小的问题解决了, 大的问题也就解决了. 这其实也是递归的思想, 所以分治一般都用递归来实现.
 递推公式
 merge_sort(p...r) = merge(merge_sort(p...q), merge_sort(q+1...r))
 终止条件.
 p >= r 不用再继续分解
 
 归并排序, 时间复杂度 nlogn, 空间复杂度是 on, 但是这个排序不是原地排序算法, 所以他的应用没有快排那么广.
 11 20 12 15 1 2 5 4 3 19 17 18 13 14 16 6 8 7 9 10
 11 12 20 15 1 2 5 4 3 19 17 18 13 14 16 6 8 7 9 10
 11 12 20 1 15 2 5 4 3 19 17 18 13 14 16 6 8 7 9 10
 1 11 12 15 20 2 5 4 3 19 17 18 13 14 16 6 8 7 9 10
 1 11 12 15 20 2 5 4 3 19 17 18 13 14 16 6 8 7 9 10
 1 11 12 15 20 2 4 5 3 19 17 18 13 14 16 6 8 7 9 10
 1 11 12 15 20 2 4 5 3 19 17 18 13 14 16 6 8 7 9 10
 1 11 12 15 20 2 3 4 5 19 17 18 13 14 16 6 8 7 9 10
 1 2 3 4 5 11 12 15 19 20 17 18 13 14 16 6 8 7 9 10
 1 2 3 4 5 11 12 15 19 20 17 18 13 14 16 6 8 7 9 10
 1 2 3 4 5 11 12 15 19 20 13 17 18 14 16 6 8 7 9 10
 1 2 3 4 5 11 12 15 19 20 13 17 18 14 16 6 8 7 9 10
 1 2 3 4 5 11 12 15 19 20 13 14 16 17 18 6 8 7 9 10
 1 2 3 4 5 11 12 15 19 20 13 14 16 17 18 6 8 7 9 10
 1 2 3 4 5 11 12 15 19 20 13 14 16 17 18 6 7 8 9 10
 1 2 3 4 5 11 12 15 19 20 13 14 16 17 18 6 7 8 9 10
 1 2 3 4 5 11 12 15 19 20 13 14 16 17 18 6 7 8 9 10
 1 2 3 4 5 11 12 15 19 20 6 7 8 9 10 13 14 16 17 18
 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
 
 上面是下面的测试程序的每次打印的图.
 可以看出, 归并排序是这样的一个模型.
 它第一次从左到右走一次, 会产生两两相邻的数据排序
 下一次从左到右走一次, 会产生四个元素对的排序.
 下一次就是8个元素块的排序.
 n 是指, 每一次都要从 0 走到 n. log n 是指, 要这样走多少次.
 
 从逆序对的概念也能感受到为什么归并要快, 在后面排序好的两个队列进行合并的时候, 每一次的位置变化, 都会消灭排序好的那个队列那么多个逆序对. 这比冒泡, 插入, 每一次位置移动, 只消灭一个逆序对快的多. 所以, 排序好的队列进行排序要快的多. 归并, 就是一点点的建立排序号的子队列的过程.
 
 快排:
 快排的思路是, 先随便取队头或者队尾的一个值做标准, 然后将这个数组前半部分变为小于等于这个值得空间, 后半部分是大于这个值得空间, 这个值在它最终排序的位置, 然后递归, 快排前半部分, 快排后半部分. 快排的这个分区间的过程, 并不需要两个区间是有序的, 只要保证两个区间是分局这个标准进行了区分. 在这个算法里面, 如果我们用队首元素, 它会在 partion 的程序里面跑到中间位置, 所以, 这个算法不是稳定的排序算法.
 
 6 9 7 8 1 2 5 4 3 10 17 18 13 14 16 19 15 12 11 20
 2 3 4 5 1 6 8 7 9 10 17 18 13 14 16 19 15 12 11 20
 1 2 4 5 3 6 8 7 9 10 17 18 13 14 16 19 15 12 11 20
 1 2 3 4 5 6 8 7 9 10 17 18 13 14 16 19 15 12 11 20
 1 2 3 4 5 6 7 8 9 10 17 18 13 14 16 19 15 12 11 20
 1 2 3 4 5 6 7 8 9 10 15 11 13 14 16 12 17 19 18 20
 1 2 3 4 5 6 7 8 9 10 12 11 13 14 15 16 17 19 18 20
 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 19 18 20
 1 2 3 4 5 6 7 8 9 10 11 12 14 13 15 16 17 19 18 20
 1 2 3 4 5 6 7 8 9 10 11 12 14 13 15 16 17 18 19 20
 1 2 3 4 5 6 7 8 9 10 11 12 14 13 15 16 17 18 19 20
 
 
 归并排序的处理过程是由下到上的，先处理子问题，然后再合并。而快排正好相反，它的处理过程是由上到下的，先分区，然后再处理子问题。归并排序虽然是稳定的、时间复杂度为 O(nlogn) 的排序算法，但是它是非原地排序算法。我们前面讲过，归并之所以是非原地排序算法， 主要原因是合并函数无法在原地执行。快速排序通过设计巧妙的原地分区函数，可以实现原地排 序，解决了归并排序占用太多内存的问题。
 */


void merge(int data[], int begin, int middle, int end, int mergeData[]) {
    int lBegin = begin;
    int lend = middle;
    int rBegin = middle + 1;
    int rend = end;
    int index = begin;
    while (lBegin <= lend && rBegin <= rend ) {
        if (data[lBegin] <= data[rBegin]) {
            mergeData[index++] = data[lBegin++];
        } else {
            mergeData[index++] = data[rBegin++];
        }
    }
    
    if (lBegin <= lend) {
        while (lBegin <= lend) {
            mergeData[index++] = data[lBegin++];
        }
    } else {
        while (rBegin <= rend) {
            mergeData[index++] = data[rBegin++];
        }
    }
    memcpy(data+begin, mergeData+begin, (end-begin+1) * sizeof(int));
    // 这里是个大坑, Both objects are reinterpreted as arrays of unsigned char. 所以这里要写清楚 size 是多少
}

void mergeSortImp(int data[], int begin, int end, int mergeData[]) {
    if (begin >= end) { return; }
    int middle = (begin+end) / 2;
    mergeSortImp(data, begin, middle, mergeData);
    mergeSortImp(data, middle+1, end, mergeData);
    merge(data, begin, middle, end, mergeData);
    for (int i = 0; i < 20; ++i) {
        std::cout << data[i] << " " ;
    }
    std::cout << '\n';
}

void mergeSort(int data[], int n, int mergeData[]) {
    mergeSortImp(data, 0, n, mergeData);
}

int partion(int data[], int begin, int end) {
    if (begin >= end) { return end; }
    int left = begin + 1;
    int right = end;
    int middle = data[begin];
    while (left < right) {
        while (data[right] > middle && left < right) {
            --right;
        }
        while (data[left] <= middle && left < right) {
            ++left;
        }
        int temp = data[left];
        data[left] = data[right];
        data[right] = temp;
    }
    int temp = data[begin];
    data[begin] = data[right];
    data[right] = temp;
    return right;
}

void quickSortImp(int data[], int begin, int end) {
    if (begin>=end){return;}
    int flag = partion(data, begin, end);
    for (int i = 0; i < 20; ++i) {
        std::cout << data[i] << " " ;
    }
    std::cout << '\n';
    quickSortImp(data, begin, flag-1);
    quickSortImp(data, flag+1, end);
}

void quickSort(int data[], int n) {
    if (!data) { return; }
    if (n < 2) { return; }
    int flag = partion(data, 0, n-1);
    quickSortImp(data, 0, flag-1);
    quickSortImp(data, flag+1, n-1);
}




int main(int argc, const char * argv[]) {
    // insert code here...
    int datas[20] = {20, 11, 12, 15, 1, 2, 5, 4, 3, 19, 17, 18, 13, 14 ,16, 6, 8, 7, 9, 10};
    int mergeData[20];
//    mergeSort(datas, 19, mergeData);
       quickSort(datas, 20);
    for (int i = 0; i < 20; ++i) {
        std::cout << datas[i] << " ";
    }
    return 0;
}
