//
//  PalindromeList.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/5.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given a singly linked list, determine if it is a palindrome.

 Example 1:

 Input: 1->2
 Output: false
 Example 2:

 Input: 1->2->2->1
 Output: true
 Follow up:
 Could you do it in O(n) time and O(1) space?
 */

class PalindromeList {
    func isPalindrome(_ head: ListNode?) -> Bool {
        if head == nil { return false }
        var nodes = [Int]()
        var currentNode = head
        while let valueNode = currentNode {
            nodes.append(valueNode.val)
            currentNode = currentNode?.next
        }
        var left = 0
        var right = nodes.count - 1
        while left <= right {
            if nodes[left] != nodes[right] {
                return false
            }
            left += 1
            right -= 1
        }
        return true
    }
}
