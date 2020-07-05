//
//  RemoveNode.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/1.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation



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
}

class FindNumIn2d {
    static func findNumberIn2DArray(_ matrix: [[Int]], _ target: Int) -> Bool {
        let rowCount = matrix.count
        guard rowCount > 0 else {
            return false
        }
        let columnCount = matrix[0].count
        guard columnCount > 0 else {
            return false
        }
        
        var rowIdx = rowCount-1
        var columnIdx = 0
        
        while rowIdx >= 0 && columnIdx < columnCount {
            if matrix[rowIdx][columnIdx] == target {
                return true
            } else if matrix[rowIdx][columnIdx] > target {
                rowIdx -= 1
            } else {
                columnIdx += 1
            }
        }
        return false
    }
}

