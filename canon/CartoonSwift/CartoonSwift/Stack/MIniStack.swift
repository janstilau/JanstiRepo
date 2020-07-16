//
//  MIniStack.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/25.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Design a stack that supports push, pop, top, and retrieving the minimum element in constant time.

 push(x) -- Push element x onto stack.
 pop() -- Removes the element on top of the stack.
 top() -- Get the top element.
 getMin() -- Retrieve the minimum element in the stack.
  

 Example 1:

 Input
 ["MinStack","push","push","push","getMin","pop","top","getMin"]
 [[],[-2],[0],[-3],[],[],[],[]]

 Output
 [null,null,null,null,-3,null,0,-2]

 Explanation
 MinStack minStack = new MinStack();
 minStack.push(-2);
 minStack.push(0);
 minStack.push(-3);
 minStack.getMin(); // return -3
 minStack.pop();
 minStack.top();    // return 0
 minStack.getMin(); // return -2
 
 Constraints:

 Methods pop, top and getMin operations will always be called on non-empty stacks.
 */

/*
 getMin in constant time means
 Can not iterater all the datas to find the min one.
 So we need to cache the minimum.
 But cache the minimum one is not successiful. Updating the mini will cause a O(n) compute, we need cache the same size minimum with datas.
 */

class MinStack {

    var datas: [Int]
    var minimumDatas: [Int]
    
    init() {
        datas = [Int]()
        minimumDatas = [Int]()
    }
    
    func push(_ x: Int) {
        datas.append(x)
        if (minimumDatas.count == 0) {
            minimumDatas.append(x)
        } else {
            let currentMin = minimumDatas.last!
            if (currentMin < x) {
                minimumDatas.append(currentMin)
            } else {
                minimumDatas.append(x)
            }
        }
    }
    
    func pop() {
        datas.removeLast()
        minimumDatas.removeLast()
    }
    
    func top() -> Int {
        return datas.last!
    }
    
    func getMin() -> Int {
        return minimumDatas.last!
    }
    
    func min() -> Int {
        return getMin()
    }
}

/**
 * Your MinStack object will be instantiated and called as such:
 * let obj = MinStack()
 * obj.push(x)
 * obj.pop()
 * let ret_3: Int = obj.top()
 * let ret_4: Int = obj.getMin()
 */


// LeetCode 其他作者的写法
/*
 这个其实就是用链表的方式, 实现了栈, 然后在每个 Node 的值域里面, 存放下当前的 mini 的值.
 */
class MinStackInLeetCode {
    class Node {
        var pre: Node?
        var next: Node?
        var min: Int
        var value: Int
        init(pre: Node?, next: Node?, min: Int, value: Int) {
            self.pre = pre
            self.next = next
            self.min = min
            self.value = value
        }
    }

    private var lastNode: Node?

    /** initialize your data structure here. */
    init() {
    }

    func push(_ x: Int) {
        if let lastNode = lastNode {
            let newNode = Node(pre: lastNode, next: nil, min: min(lastNode.min, x), value: x)
            lastNode.next = newNode
            self.lastNode = newNode
        } else {
            lastNode = Node(pre: nil, next: nil, min: x, value: x)
        }
    }

    func pop() {
        guard let lastNode = lastNode else {
            return
        }

        guard let preNode = lastNode.pre else {
            self.lastNode = nil
            return
        }

        preNode.next = nil
        self.lastNode = preNode
    }

    func top() -> Int  {
        return lastNode?.value ?? 0
    }

    func getMin() -> Int {
        return lastNode?.min ?? 0
    }

}

