//
//  OddEvenList.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/5.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given a singly linked list, group all odd nodes together followed by the even nodes. Please note here we are talking about the node number and not the value in the nodes.

 You should try to do it in place. The program should run in O(1) space complexity and O(nodes) time complexity.

 Example 1:

 Input: 1->2->3->4->5->NULL
 Output: 1->3->5->2->4->NULL
 Example 2:

 Input: 2->1->3->5->6->4->7->NULL
 Output: 2->3->6->7->1->5->4->NULL
  

 Constraints:

 The relative order inside both the even and odd groups should remain as it was in the input.
 The first node is considered odd, the second node even and so on ...
 The length of the linked list is between [0, 10^4].
 */

class OddEvenList {
    func oddEvenList(_ head: ListNode?) -> ListNode? {
        guard head != nil else {
            return nil
        }
        guard head?.next != nil else {
            return head
        }
        
        let oddListHead = head
        let eventListHead = head?.next
        var oddCurrentNode = oddListHead
        var evenCurrentNode = eventListHead
        
        var listCurrentNode = oddListHead?.next?.next
        while listCurrentNode != nil {
            oddCurrentNode?.next = listCurrentNode
            oddCurrentNode = oddCurrentNode?.next
            evenCurrentNode?.next = listCurrentNode?.next
            evenCurrentNode = evenCurrentNode?.next
            listCurrentNode = listCurrentNode?.next?.next
        }
        
        oddCurrentNode?.next = eventListHead
        return oddListHead
    }
}
