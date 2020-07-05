//
//  MergeList.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/5.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Merge two sorted linked lists and return it as a new sorted list. The new list should be made by splicing together the nodes of the first two lists.

 Example:

 Input: 1->2->4, 1->3->4
 Output: 1->1->2->3->4->4
 */

class MergeList {
    static func makeList(list: [Int]) -> ListNode? {
        if list.isEmpty { return nil }
        let sentinelNode = ListNode(0)
        var currentNode: ListNode? = sentinelNode
        for aNum in list {
            let newNode = ListNode(aNum)
            currentNode?.next = newNode
            currentNode = newNode
        }
        return sentinelNode.next
    }
    static func mergeTwoLists(_ l1: ListNode?, _ l2: ListNode?) -> ListNode? {
        let sentinelNode = ListNode(0)
        var leftCurrent = l1
        var rightCurrent = l2
        var resultCurrent:ListNode? = sentinelNode
        while let leftValueNode = leftCurrent,
              let rightValueNode = rightCurrent {
                if leftValueNode.val <= rightValueNode.val {
                    let copiedNode = ListNode(leftValueNode.val)
                    copiedNode.next = resultCurrent?.next
                    resultCurrent?.next = copiedNode
                    leftCurrent = leftCurrent?.next
                } else {
                    let copiedNode = ListNode(rightValueNode.val)
                    copiedNode.next = resultCurrent?.next
                    resultCurrent?.next = copiedNode
                    rightCurrent = rightCurrent?.next
                }
                resultCurrent = resultCurrent?.next
        }
        while let leftValueNode = leftCurrent {
            let copiedNode = ListNode(leftValueNode.val)
            copiedNode.next = resultCurrent?.next
            resultCurrent?.next = copiedNode
            leftCurrent = leftCurrent?.next
            resultCurrent = resultCurrent?.next
        }
        while let rightValue = rightCurrent {
            let copiedNode = ListNode(rightValue.val)
            copiedNode.next = resultCurrent?.next
            resultCurrent?.next = copiedNode
            rightCurrent = rightCurrent?.next
            resultCurrent = resultCurrent?.next
        }
        return sentinelNode.next
    }
}
