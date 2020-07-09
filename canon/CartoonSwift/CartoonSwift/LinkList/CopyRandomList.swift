//
//  CopyRandomList.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/6.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 A linked list is given such that each node contains an additional random pointer which could point to any node in the list or null.

 Return a deep copy of the list.

 The Linked List is represented in the input/output as a list of n nodes. Each node is represented as a pair of [val, random_index] where:

 val: an integer representing Node.val
 random_index: the index of the node (range from 0 to n-1) where random pointer points to, or null if it does not point to any node.
  

 Example 1:


 Input: head = [[7,null],[13,0],[11,4],[10,2],[1,0]]
 Output: [[7,null],[13,0],[11,4],[10,2],[1,0]]
 Example 2:


 Input: head = [[1,1],[2,1]]
 Output: [[1,1],[2,1]]
 Example 3:



 Input: head = [[3,null],[3,0],[3,null]]
 Output: [[3,null],[3,0],[3,null]]
 Example 4:

 Input: head = []
 Output: []
 Explanation: Given linked list is empty (null pointer), so return null.
  

 Constraints:

 -10000 <= Node.val <= 10000
 Node.random is null or pointing to a node in the linked list.
 Number of Nodes will not exceed 1000.
 */

 public class RandomNode {
     public var val: Int
     public var next: RandomNode?
     public var random: RandomNode?
     public init(_ val: Int) {
         self.val = val
         self.next = nil
         self.random = nil
     }
 }

extension RandomNode: Hashable {
    public static func == (lhs: RandomNode, rhs: RandomNode) -> Bool {
        return lhs === rhs
    }
    public func hash(into hasher: inout Hasher) {
         hasher.combine(ObjectIdentifier(self).hashValue)
    }
}

/*
 Random pointer of node with val 13 points to a node not in the copied list
 */
class CopyRandomList {
    func copyRandomList(_ head: RandomNode?) -> RandomNode? {
        guard head != nil else {
            return nil
        }
        
        var srcNodeIdxMap = [RandomNode: Int]()
        var resultIdxNodeMap = [Int: RandomNode]()
        
        var srcCurNode = head
        let sentinelNode = RandomNode(0)
        var resultCurNode:RandomNode? = sentinelNode
        var idx = 0
        while let srcValueNode = srcCurNode {
            srcNodeIdxMap[srcValueNode] = idx
            
            let copiedNode = RandomNode(srcValueNode.val)
            resultIdxNodeMap[idx] = copiedNode
            
            srcCurNode = srcValueNode.next
            resultCurNode?.next = copiedNode
            resultCurNode = resultCurNode?.next
            
            idx += 1
        }
        
        srcCurNode = head
        resultCurNode = sentinelNode.next
        idx = 0
        while let srcValueNode = srcCurNode {
            if let randomNode = srcValueNode.random {
                let targetIdx:Int! = srcNodeIdxMap[randomNode]
                resultCurNode?.random = resultIdxNodeMap[targetIdx]
            }
            srcCurNode = srcValueNode.next
            resultCurNode = resultCurNode?.next
        }
        
        return sentinelNode.next
    }
}
