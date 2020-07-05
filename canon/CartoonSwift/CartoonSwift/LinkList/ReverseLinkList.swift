//
//  ReverseLinkList.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/5.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation
/*
 Reverse a singly linked list.

 Example:

 Input: 1->2->3->4->5->NULL
 Output: 5->4->3->2->1->NULL
 Follow up:

 A linked list can be reversed either iteratively or recursively. Could you implement both?
 */

class ReverseList {
    
    func reverseList_iterative(_ head: ListNode?) -> ListNode? {
        if head == nil { return nil }
        let sentinelNode = ListNode(0)
        sentinelNode.next = nil
        var iteratorNode = head
        while let valueNode = iteratorNode {
            let copiedNode = ListNode(valueNode.val)
            copiedNode.next = sentinelNode.next
            sentinelNode.next = copiedNode
            iteratorNode = iteratorNode?.next
        }
        return sentinelNode.next
    }
}
