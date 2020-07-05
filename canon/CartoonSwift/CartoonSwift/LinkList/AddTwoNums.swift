//
//  AddTwoNums.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/5.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation


/*
 You are given two non-empty linked lists representing two non-negative integers. The digits are stored in reverse order and each of their nodes contain a single digit. Add the two numbers and return it as a linked list.

 You may assume the two numbers do not contain any leading zero, except the number 0 itself.

 Example:

 Input: (2 -> 4 -> 3) + (5 -> 6 -> 4)
 Output: 7 -> 0 -> 8
 Explanation: 342 + 465 = 807.
 */

class AddTwoNumbers {
    func addTwoNumbers(_ l1: ListNode?, _ l2: ListNode?) -> ListNode? {
        guard l1 != nil else {
            return l2
        }
        guard l2 != nil else {
            return l1
        }
        
        var extraAddNum = 0
        var lhsCurrent = l1
        var rhsCurrent = l2
        let sentinelHead = ListNode(0)
        var current:ListNode? = sentinelHead
        while lhsCurrent != nil && rhsCurrent != nil {
            let sum = lhsCurrent!.val + rhsCurrent!.val + extraAddNum
            let sumNode = ListNode(sum % 10)
            current?.next = sumNode
            current = current?.next
            if sum >= 10 {
                extraAddNum = 1
            } else {
                extraAddNum = 0
            }
            lhsCurrent = lhsCurrent?.next
            rhsCurrent = rhsCurrent?.next
        }
        while lhsCurrent != nil {
            let sum = lhsCurrent!.val + extraAddNum
            let tailNode = ListNode(sum % 10)
            current?.next = tailNode
            current = current?.next
            lhsCurrent = lhsCurrent?.next
            if sum >= 10 {
                extraAddNum = 1
            } else {
                extraAddNum = 0
            }
        }
        while rhsCurrent != nil {
            let sum = rhsCurrent!.val + extraAddNum
            let tailNode = ListNode(sum % 10)
            current?.next = tailNode
            current = current?.next
            rhsCurrent = rhsCurrent?.next
            if sum >= 10 {
                extraAddNum = 1
            } else {
                extraAddNum = 0
            }
        }
        
        if extraAddNum == 1 {
            let tailNode = ListNode(extraAddNum)
            current?.next = tailNode
            current = current?.next
        }
        
        return sentinelHead.next
    }
}
