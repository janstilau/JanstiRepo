//
//  CopyRandomList.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/6.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

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

class CopyRandomList {
    func copyRandomList(_ head: RandomNode?) -> RandomNode? {
        guard head != nil else {
            return nil
        }
        
        var srcNodeInxMap = [RandomNode: Int]()
        var resultIdxNodeMap = [Int: RandomNode]()
        
        var srcCurNode = head
        let sentinelNode = RandomNode(0)
        var resultCurNode:RandomNode? = sentinelNode
        var idx = 0
        while let srcValueNode = srcCurNode {
            let copiedNode = RandomNode(srcValueNode.val)
            resultCurNode?.next = copiedNode
            srcNodeInxMap[srcValueNode] = idx
            resultIdxNodeMap[idx] = resultCurNode
            srcCurNode = srcValueNode.next
            resultCurNode = resultCurNode?.next
            idx += 1
        }
        
        srcCurNode = head
        idx = 0
        while let srcValueNode = srcCurNode {
            
        }
        
        
        return nil
    }
}
