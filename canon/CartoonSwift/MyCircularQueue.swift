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


class MyCircularQueue {

    /** Initialize your data structure here. Set the size of the queue to be k. */
    init(_ k: Int) {
        
    }
    
    /** Insert an element into the circular queue. Return true if the operation is successful. */
    func enQueue(_ value: Int) -> Bool {
        
    }
    
    /** Delete an element from the circular queue. Return true if the operation is successful. */
    func deQueue() -> Bool {
        
    }
    
    /** Get the front item from the queue. */
    func Front() -> Int {
        
    }
    
    /** Get the last item from the queue. */
    func Rear() -> Int {
        
    }
    
    /** Checks whether the circular queue is empty or not. */
    func isEmpty() -> Bool {
        
    }
    
    /** Checks whether the circular queue is full or not. */
    func isFull() -> Bool {
        
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
