//
//  FlatList.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/5.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation


class FlattenList {
     static func flatten(_ head: Node?) -> Node? {
        guard let head = head else {
            return nil
        }
        let result = flattenList(head)
        return result.head
    }
    
    static func flattenList(_ head: Node) -> (head: Node, tail: Node) {
        var currentNode:Node? = head
        var preNode = head
        while currentNode != nil {
            if let childNode = currentNode?.child {
                let nextNode = currentNode?.next
                let flattenChildList = flattenList(childNode)
                flattenChildList.head.prev = currentNode
                flattenChildList.tail.next = nextNode
                currentNode?.next = flattenChildList.head
                nextNode?.prev = flattenChildList.tail
                currentNode?.child = nil
                currentNode = nextNode
                preNode = flattenChildList.tail
            } else {
                preNode = currentNode!
                currentNode = currentNode?.next
            }
        }
        return (head, preNode)
    }
}
