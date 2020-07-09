//
//  RotateList.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/6.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given a linked list, rotate the list to the right by k places, where k is non-negative.

 Example 1:

 Input: 1->2->3->4->5->NULL, k = 2
 Output: 4->5->1->2->3->NULL
 Explanation:
 rotate 1 steps to the right: 5->1->2->3->4->NULL
 rotate 2 steps to the right: 4->5->1->2->3->NULL
 Example 2:

 Input: 0->1->2->NULL, k = 4
 Output: 2->0->1->NULL
 Explanation:
 rotate 1 steps to the right: 2->0->1->NULL
 rotate 2 steps to the right: 1->2->0->NULL
 rotate 3 steps to the right: 0->1->2->NULL
 rotate 4 steps to the right: 2->0->1->NULL
 */

class RotateList {
    
    func getListLength(_ head: ListNode?) -> Int {
        var length = 0
        var currentNode = head
        while currentNode != nil {
            length += 1
            currentNode = currentNode?.next
        }
        return length
    }
    
    func getNodeAt(_ head: ListNode, idx: Int) -> ListNode {
        var step = idx
        var currentNode:ListNode? = head
        while step > 0 && currentNode != nil {
            step -= 1
            currentNode = currentNode?.next
        }
        return currentNode!
    }
    
    func rotateRight(_ head: ListNode?, _ k: Int) -> ListNode? {
        guard let head = head else {
            return nil
        }
        
        let length = getListLength(head)
        let step = k % length
        if step == 0 { return head }
        
        let tailNode = getNodeAt(head, idx: length-1)
        tailNode.next = head
        let preNode = getNodeAt(head, idx: length-step-1)
        let result = preNode.next
        preNode.next = nil
        return result
    }
}
