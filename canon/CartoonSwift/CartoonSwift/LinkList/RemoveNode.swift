//
//  RemoveNode.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/1.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

 public class ListNode {
     public var val: Int
     public var next: ListNode?
     public init(_ val: Int) {
         self.val = val
         self.next = nil
     }
 }

/*
 Given a linked list, remove the n-th node from the end of list and return its head.

 Example:

 Given linked list: 1->2->3->4->5, and n = 2.

 After removing the second node from the end, the linked list becomes 1->2->3->5.
 Note:

 Given n will always be valid.

 Follow up:

 Could you do this in one pass?
 */
class RemoveNode {
    func deleteNode(_ node: ListNode?) {
        guard let removedNode = node else {
            return
        }
        guard removedNode.next != nil else {
            return
        }
        removedNode.val = removedNode.next!.val
        removedNode.next = removedNode.next!.next
    }
    
    func removeNthFromEnd(_ head: ListNode?, _ n: Int) -> ListNode? {
        
    }
}
