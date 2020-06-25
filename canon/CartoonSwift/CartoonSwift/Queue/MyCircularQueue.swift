//
//  MyCircularQueue.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/25.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Design your implementation of the circular queue. The circular queue is a linear data structure in which the operations are performed based on FIFO (First In First Out) principle and the last position is connected back to the first position to make a circle. It is also called "Ring Buffer".

 One of the benefits of the circular queue is that we can make use of the spaces in front of the queue. In a normal queue, once the queue becomes full, we cannot insert the next element even if there is a space in front of the queue. But using the circular queue, we can use the space to store new values.

 Your implementation should support following operations:

 MyCircularQueue(k): Constructor, set the size of the queue to be k.
 Front: Get the front item from the queue. If the queue is empty, return -1.
 Rear: Get the last item from the queue. If the queue is empty, return -1.
 enQueue(value): Insert an element into the circular queue. Return true if the operation is successful.
 deQueue(): Delete an element from the circular queue. Return true if the operation is successful.
 isEmpty(): Checks whether the circular queue is empty or not.
 isFull(): Checks whether the circular queue is full or not.
  

 Example:

 MyCircularQueue circularQueue = new MyCircularQueue(3); // set the size to be 3
 circularQueue.enQueue(1);  // return true
 circularQueue.enQueue(2);  // return true
 circularQueue.enQueue(3);  // return true
 circularQueue.enQueue(4);  // return false, the queue is full
 circularQueue.Rear();  // return 3
 circularQueue.isFull();  // return true
 circularQueue.deQueue();  // return true
 circularQueue.enQueue(4);  // return true
 circularQueue.Rear();  // return 4
  
 Note:

 All values will be in the range of [0, 1000].
 The number of operations will be in the range of [1, 1000].
 Please do not use the built-in Queue library.
 */

/*
 LeetCode 里面这道题有点问题, 默认了非法数字是 -1, 并且在为空的时候, 还可以进行 front, rear 的操作. 在 dequeue 的时候, 还要把里面的值, 设置为 -1.
 这都是非法的假设.
 */


class MyCircularQueue {
    
    var datas:[Int]
    var size = 0
    var head = 0
    var tail = 0

    /** Initialize your data structure here. Set the size of the queue to be k. */
    init(_ k: Int) {
        size = k+1
        datas = Array<Int>.init(repeating: -1, count: size)
    }
    
    /** Checks whether the circular queue is empty or not. */
    func isEmpty() -> Bool {
       return head == tail
    }

    /** Checks whether the circular queue is full or not. */
    func isFull() -> Bool {
       return (tail+1)%size == head
    }
    
    /** Insert an element into the circular queue. Return true if the operation is successful. */
    func enQueue(_ value: Int) -> Bool {
        if self.isFull() { return false }
        tail = (tail+1) % size
        datas[tail] = value
        return true
    }
    
    /** Delete an element from the circular queue. Return true if the operation is successful. */
    func deQueue() -> Bool {
        if self.isEmpty() { return false }
        head = (head+1) % size
        return true
    }
    
    /** Get the front item from the queue. */
    func Front() -> Int {
        if isEmpty() { return -1 }
        return datas[head]
    }
    
    /** Get the last item from the queue. */
    func Rear() -> Int {
        if isEmpty() { return -1 }
        return datas[tail]
    }
}

/**
 * Your MyCircularQueue object will be instantiated and called as such:
 * let obj = MyCircularQueue(k)
 * let ret_1: Bool = obj.enQueue(value)
 * let ret_2: Bool = obj.deQueue()
 * let ret_3: Int = obj.Front()
 * let ret_4: Int = obj.Rear()
 * let ret_5: Bool = obj.isEmpty()
 * let ret_6: Bool = obj.isFull()
 */


/*
 
 C++ 版本
 这里, tail 不是即将插入的地址, 而是最后一个元素的地址.
 这里, 用了一个特殊值来判断, isEmpty, 就是 -1, 在 dequeue 的时候, 如果发现 head = tail 了, 就进行特殊处理.
 这种写法, 不比浪费一个空间要好.
 class MyCircularQueue {
 private:
     vector<int> data;
     int head;
     int tail;
     int size;
 public:
     /** Initialize your data structure here. Set the size of the queue to be k. */
     MyCircularQueue(int k) {
         data.resize(k);
         head = -1;
         tail = -1;
         size = k;
     }
     
     /** Insert an element into the circular queue. Return true if the operation is successful. */
     bool enQueue(int value) {
         if (isFull()) {
             return false;
         }
         if (isEmpty()) {
             head = 0;
         }
         tail = (tail + 1) % size;
         data[tail] = value;
         return true;
     }
     
     /** Delete an element from the circular queue. Return true if the operation is successful. */
     bool deQueue() {
         if (isEmpty()) {
             return false;
         }
         if (head == tail) {
             head = -1;
             tail = -1;
             return true;
         }
         head = (head + 1) % size;
         return true;
     }
     
     /** Get the front item from the queue. */
     int Front() {
         if (isEmpty()) {
             return -1;
         }
         return data[head];
     }
     
     /** Get the last item from the queue. */
     int Rear() {
         if (isEmpty()) {
             return -1;
         }
         return data[tail];
     }
     
     /** Checks whether the circular queue is empty or not. */
     bool isEmpty() {
         return head == -1;
     }
     
     /** Checks whether the circular queue is full or not. */
     bool isFull() {
         return ((tail + 1) % size) == head;
     }
 };

 /**
  * Your MyCircularQueue object will be instantiated and called as such:
  * MyCircularQueue obj = new MyCircularQueue(k);
  * bool param_1 = obj.enQueue(value);
  * bool param_2 = obj.deQueue();
  * int param_3 = obj.Front();
  * int param_4 = obj.Rear();
  * bool param_5 = obj.isEmpty();
  * bool param_6 = obj.isFull();
  */
 */
