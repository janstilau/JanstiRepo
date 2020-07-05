//
//  RemoveNthNode.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/5.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

class RemoveNthNode {
    static func removeNthFromEnd(_ head: ListNode?, _ n: Int) -> ListNode? {
        if head == nil { return nil }
        var step = n
        var preStepNode = head
        while step > 0 {
            step -= 1
            preStepNode = preStepNode?.next
            if preStepNode == nil && step == 0 {
                return head?.next
            }
        }
        var targetPreNode:ListNode? = nil
        var targetNode = head
        while preStepNode != nil {
            preStepNode = preStepNode?.next
            targetPreNode = targetNode
            targetNode = targetNode?.next
        }
        targetPreNode?.next = targetPreNode?.next?.next
        return head
    }
}
