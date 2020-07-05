//
//  CircleList.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/5.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation
/*
 Given a linked list, determine if it has a cycle in it.

 To represent a cycle in the given linked list, we use an integer pos which represents the position (0-indexed) in the linked list where tail connects to. If pos is -1, then there is no cycle in the linked list.

  

 Example 1:

 Input: head = [3,2,0,-4], pos = 1
 Output: true
 Explanation: There is a cycle in the linked list, where tail connects to the second node.


 Example 2:

 Input: head = [1,2], pos = 0
 Output: true
 Explanation: There is a cycle in the linked list, where tail connects to the first node.


 Example 3:

 Input: head = [1], pos = -1
 Output: false
 Explanation: There is no cycle in the linked list.


  

 Follow up:

 Can you solve it using O(1) (i.e. constant) memory?
 */

class CycleList {
    func hasCycle(_ head: ListNode?) -> Bool {
        var fastNode = head
        var slowNode = head
        while fastNode != nil && slowNode != nil {
            fastNode = fastNode?.next?.next
            slowNode = slowNode?.next
            if (fastNode === slowNode && fastNode != nil) { return true }
        }
        return false
    }
    
    func detectCycleSet(_ head: ListNode?) -> ListNode? {
        guard head != nil else {
            return nil
        }
        var stash = Set<ListNode?>()
        var currentNode = head
        while currentNode != nil {
            if stash.contains(currentNode) { return currentNode }
            stash.insert(currentNode)
            currentNode = currentNode?.next
        }
        return nil
    }
    
    func detectCycle(_ head: ListNode?) -> ListNode? {
        var fastNode = head
        var slowNode = head
        var crashNode: ListNode? = nil
        while fastNode != nil && slowNode != nil {
            fastNode = fastNode?.next?.next
            slowNode = slowNode?.next
            if (fastNode === slowNode && fastNode != nil) {
                crashNode = fastNode
            }
        }
        if crashNode == nil { return nil }
        var circleInNode = crashNode
        var lineNode = head
        while lineNode !== circleInNode {
            lineNode = lineNode?.next
            circleInNode = circleInNode?.next
        }
        return circleInNode
    }
}
