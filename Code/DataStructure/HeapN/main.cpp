//
//  main.cpp
//  HeapN
//
//  Created by JustinLau on 2019/3/12.
//  Copyright © 2019年 JustinLau. All rights reserved.
//

#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <time.h>

/* Implement heap */

#define MAX_HEAP_SIZE (1 << 8)

struct element {
    int data;
};

struct heap {
    union {// 因为堆实际上是从1开始的, 所以第一个元素的位置浪费掉了. 所以, 这里用 union, 将数组的第一个元素使用了. 个人觉得没有必要.
        int size; // 这个命名不好, 应该叫 size 或者 length 之类的.
        struct element *elem[MAX_HEAP_SIZE];
    };
};

void init_heap(struct heap *heap)
{
    int i;
    
    for(i = 0; i < MAX_HEAP_SIZE; i++) {
        heap->elem[i] = NULL;
    }
}

// 打印多少个元素.
void dump(struct heap *heap, int elements)
{
    int i;
    
    for (i = 1; i <= elements; i++)
        printf("[%02d]: %4d\n", i, heap->elem[i]->data);
}

struct element* create_element(int data)
{
    struct element *elem;
    
    elem = (struct element *)malloc(sizeof(element));
    
    
    if (elem)
        elem->data = data;
    
    return elem;
}

void fake_a_heap(struct heap *heap)
{
    /* data is in ordered */
    int i, data[10] = {7, 4, 9, 2, 6, 8, 10, 1, 3, 5};
    
    init_heap(heap);
    
    /* root start at 1 */
    for (i = 0; i < 10; i++)
        heap->elem[i+1] = create_element(data[i]);
    
    heap->size = 10;
}

void swap(struct heap *heap, int i, int j)
{
    struct element *tmp;
    
    tmp = heap->elem[j];
    heap->elem[j] = heap->elem[i];
    heap->elem[i] = tmp;
}
// 堆化.
void heapify(struct heap *heap, int parent)
{
    struct element **elem = heap->elem;
    int elements = heap->size;
    int left, right, max;
    
    while (true) {
        left = parent * 2;
        right = left + 1;
        
        max = parent;
        if (left <= elements && elem[max]->data < elem[left]->data)
            max = left;
        if (right <= elements && elem[max]->data < elem[right]->data)
            max = right;
        
        if (max == parent)
            break;
        
        swap(heap, max, parent);
        parent = max;
    }
}

void build_heap(struct heap *heap)
{
    int i;
    
    for (i = heap->size / 2; i >= 1; i--)
        heapify(heap, i); // 为什么这样写.
}

// 把第一位放到最后面, 然后重新堆化
int heap_sort(struct heap *heap)
{
    int elements = heap->size;
    
    while (heap->size) {
        swap(heap, 1, heap->size);
        heap->size--;
        heapify(heap, 1);
    }
    
    return elements;
}

int main()
{
    struct heap heap;
    int elements = 10;
    
    fake_a_heap(&heap);
    dump(&heap, elements);
    printf("After Heapify:\n");
    build_heap(&heap);
    dump(&heap, elements);
    printf("After Heap sort:\n");
    elements = heap_sort(&heap);
    dump(&heap, elements);
    return 0;
}
