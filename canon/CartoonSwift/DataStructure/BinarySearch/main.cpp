//
//  main.cpp
//  BinarySearch
//
//  Created by JustinLau on 2019/3/10.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#include <iostream>

/*
 整体的框架, 还是这样的, 而下面的各种, 按照不同的条件进行搜索, 主要还是在各个位置, 安插合适的判断条件.
 在合适的位置安插判断条件, 而不更改主流程, 让代码更加的清晰.
 */
int binarySearch(int datas[], int n, int value) {
    if (!datas) { return -1;}
    if (n < 1) { return -1; }
    if (value < datas[0] || datas[n-1] < value ) { return -1; }
    int left = 0;
    int right = n;
    int mid;
    while (left <= right) {
        mid = left + (right-left)/2;
        if (value == datas[mid]) { return mid; }
        if (value < datas[mid]) {
            right = mid - 1;
        } else {
            left = mid + 1;
        }
    }
    return -1;
}

int binarySearchRecuriveImp(int datas[], int left, int right, int value) {
    if (left < right) { return -1; }
    int mid = left + (right-left)/2;
    /*
     这里, 不应该用 guard 处理. 到处使用 guard 处理逻辑, 反而打乱了清晰的处理流程.
    */
    if (datas[mid] == value) {
        return mid;
    } else if (datas[mid] > value) {
        return binarySearchRecuriveImp(datas, mid + 1, right, value);
    } else {
        return binarySearchRecuriveImp(datas, left, mid - 1, value);
    }
}

int binarySearchRecurive(int datas[], int n, int value) {
    if (!datas) { return -1;}
    if (n < 1) { return -1; }
    if (value < datas[0] || datas[n-1] < value ) { return -1; }
    return binarySearchRecuriveImp(datas, 0, n, value);
}

int binarySearchFirst(int datas[], int n, int value) {
    if (!datas) { return -1;}
    if (n < 1) { return -1; }
    if (value < datas[0] || datas[n-1] < value ) { return -1; }
    int left = 0;
    int right = n;
    while (left <= right) {
        int mid = left + (right - left)/2;
        int midValue = datas[mid];
        if (midValue > value) {
            right = mid - 1;
        } else if (midValue < value) {
            left = mid + 1;
        } else {
            /*
             查找第一个元素, 那么如果 mid 左侧的元素, 还是 value 的值的话, 第一个元素的位置一定在 mid 的左侧.
             */
            if (mid == 0 || datas[mid-1] != value) { return mid;}
            right = mid - 1;
        }
    }
    return -1;
}

int binarySearchLast(int datas[], int n, int value) {
    if (!datas) { return -1;}
    if (n < 1) { return -1; }
    if (value < datas[0] || datas[n-1] < value ) { return -1; }
    int left = 0;
    int right = n;
    while (left <= right) {
        int mid = left + (right - left)/2;
        int midValue = datas[mid];
        if (midValue > value) {
            right = mid - 1;
        } else if (midValue < value) {
            left = mid + 1;
        } else {
            /*
            查找第一个元素, 那么如果 mid 右侧的元素, 还是 value 的值的话, 第一个元素的位置一定在 mid 的右侧.
            */
            if (mid == n-1 || datas[mid+1] != value) { return mid;}
            left = mid+1;
        }
    }
    return -1;
}

int binarySearchFirstBigerOrEqual(int datas[], int n, int value) {
    if (!datas) { return -1;}
    if (n < 1) { return -1; }
    if (value < datas[0] || datas[n-1] < value ) { return -1; }
    int left = 0;
    int right = n;
    while (left <= right) {
        int mid = left + (right-left)/2;
        if (datas[mid] >= value) {
            // 因为是 biggerOrEqual, 所以, 相等就合并到了 > 的判断条件里面
            if (mid == 0 || datas[mid - 1] < value) { return mid;}
            right = mid - 1;
        } else {
            left = left + 1;
        }
    }
    return -1;
}

int binarySearchLastEqualSamll(int datas[], int n, int value) {
    if (!datas) { return -1;}
    if (n < 1) { return -1; }
    if (value < datas[0] || datas[n-1] < value ) { return -1; }
    int left = 0;
    int right = n;
    while (left <= right) {
        int mid = left + (right-left)/2;
        if (datas[mid] <= value) {
            if (mid == n-1 || datas[mid + 1] > value) { return mid;}
            left = mid + 1;
        } else {
            right = mid - 1;
        }
    }
    return -1;
}


int main(int argc, const char * argv[]) {
    
    
    return 0;
}
