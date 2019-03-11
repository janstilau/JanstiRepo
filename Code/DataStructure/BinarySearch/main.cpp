//
//  main.cpp
//  BinarySearch
//
//  Created by JustinLau on 2019/3/10.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#include <iostream>

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
    if (datas[mid] == value) { return mid; }
    if (datas[mid] > value) { return binarySearchRecuriveImp(datas, mid + 1, right, value);}
    return binarySearchRecuriveImp(datas, left, mid - 1, value);
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
