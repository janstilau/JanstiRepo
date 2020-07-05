//
//  ReversePint.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/4.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation


/**
 * Definition for singly-linked list.
 * public class ListNode {
 *     public var val: Int
 *     public var next: ListNode?
 *     public init(_ val: Int) {
 *         self.val = val
 *         self.next = nil
 *     }
 * }
 */

/*
 输入一个链表的头节点，从尾到头反过来返回每个节点的值（用数组返回）。
 */
class ReversePrint {
    func reversePrint(_ head: ListNode?) -> [Int] {
        var stack = [Int]()
        var currentNode = head
        while  let aNode = currentNode {
            stack.append(aNode.val)
            currentNode = currentNode?.next
        }
        var result = [Int]()
        result.reserveCapacity(stack.count)
        for aNum in stack.reversed() {
            result.append(aNum)
        }
        return result
    }
}
