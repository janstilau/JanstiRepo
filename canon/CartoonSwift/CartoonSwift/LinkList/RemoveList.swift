//
//  RemoveList.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/5.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Remove all elements from a linked list of integers that have value val.

 Example:

 Input:  1->2->6->3->4->5->6, val = 6
 Output: 1->2->3->4->5
 */

class RemoveElements {
    func removeElements(_ head: ListNode?, _ val: Int) -> ListNode? {
        guard  head != nil else {
            return nil
        }
        var result = head
        while result?.val == val {
            result = result?.next
        }
        
        var currentNode = result
        while currentNode != nil {
            while currentNode?.next?.val == val {
                currentNode?.next = currentNode?.next?.next
            }
            currentNode = currentNode?.next
        }
        return result
    }
}
