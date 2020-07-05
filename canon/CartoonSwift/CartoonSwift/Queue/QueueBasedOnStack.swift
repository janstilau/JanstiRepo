//
//  QueueBasedOnStack.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/4.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 用两个栈实现一个队列。队列的声明如下，请实现它的两个函数 appendTail 和 deleteHead ，分别完成在队列尾部插入整数和在队列头部删除整数的功能。(若队列中没有元素，deleteHead 操作返回 -1 )

 示例 1：

 输入：
 ["CQueue","appendTail","deleteHead","deleteHead"]
 [[],[3],[],[]]
 输出：[null,null,3,-1]
 示例 2：

 输入：
 ["CQueue","deleteHead","appendTail","appendTail","deleteHead","deleteHead"]
 [[],[],[5],[2],[],[]]
 输出：[null,-1,null,null,5,2]
 提示：

 1 <= values <= 10000
 最多会对 appendTail、deleteHead 进行 10000 次调用

 来源：力扣（LeetCode）
 链接：https://leetcode-cn.com/problems/yong-liang-ge-zhan-shi-xian-dui-lie-lcof
 著作权归领扣网络所有。商业转载请联系官方授权，非商业转载请注明出处。
 */

class CQueue {
    /*
     只应该调用 append, removelast 方法
     */
    var stack_1: [Int]
    var stack_2: [Int]
    init() {
        stack_1 = [Int]()
        stack_2 = [Int]()
    }
    
    func appendTail(_ value: Int) {
        stack_1.append(value)
    }
    
    func deleteHead() -> Int {
        if stack_2.isEmpty && stack_1.isEmpty { return -1 }
        if !stack_2.isEmpty {
            return stack_2.removeLast()
        }
        stack_2.append(contentsOf: stack_1.reversed())
        stack_1.removeAll()
        return stack_2.removeLast()
    }
}

/*
 用两个队列, 模拟一个栈
 */

class CStack {
    /*
     只应该调用 append, first() 方法.
     */
    var queue_1: [Int]
    var queue_2: [Int]
    init() {
        queue_1 = [Int]()
        queue_2 = [Int]()
    }
    
    func enqueue(_ value: Int) {
        if queue_1.isEmpty && queue_2.isEmpty {
            queue_1.append(value)
        } else if queue_1.isEmpty {
            queue_2.append(value)
        } else {
            queue_1.append(value)
        }
    }
    
    func dequeue() -> Int {
        if queue_1.isEmpty && queue_2.isEmpty {
            return -1
        } else if queue_1.isEmpty {
            queue_1[0..<queue_2.count-1] = queue_2[0..<queue_2.count-1]
            let result = queue_2.last!
            queue_2.removeAll()
            return result
        } else {
            queue_2[0..<queue_1.count-1] = queue_1[0..<queue_1.count-1]
            let result = queue_1.last!
            queue_1.removeAll()
            return result
        }
    }
}
