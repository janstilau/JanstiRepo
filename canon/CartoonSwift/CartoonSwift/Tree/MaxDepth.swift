//
//  MaxDepth.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/5.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given a binary tree, find its maximum depth.

 The maximum depth is the number of nodes along the longest path from the root node down to the farthest leaf node.

 Note: A leaf is a node with no children.

 Example:

 Given binary tree [3,9,20,null,null,15,7],

     3
    / \
   9  20
     /  \
    15   7
 return its depth = 3.
 */

/*
 [3,9,20,null,null,15,7],
 */

class TreeFactory {
    static func makeTree(nodes: [Int?]) -> TreeNode? {
        if nodes.isEmpty { return nil }
        
        var nodeMap = [Int: TreeNode]()
        for idx in 0..<nodes.count {
            if let val = nodes[idx] {
                let idxNode = TreeNode(val)
                nodeMap[idx] = idxNode
            } else {
                nodeMap[idx] = nil
            }
        }
        
        for idx in 0..<nodes.count {
            guard let idxNode = nodeMap[idx] else {
                continue
            }
            let leftIdx = (idx+1)*2-1
            if leftIdx < nodes.count {
                idxNode.left = nodeMap[leftIdx]
            }
            let rightIdx = (idx+1)*2
            if rightIdx < nodes.count {
                idxNode.right = nodeMap[rightIdx]
            }
        }
        
        return nodeMap[0]
    }
}
class MaxDepth {
    static func maxDepth(_ root: TreeNode?) -> Int {
        guard root != nil else {
            return 0
        }
        var stashQueue = [TreeNode]()
        var levelQueue = [TreeNode]()
        
        levelQueue.append(root!)
        var depth = 0
        while true {
            while !levelQueue.isEmpty {
                let node = levelQueue.removeFirst()
                if let leftNode = node.left {
                    stashQueue.append(leftNode)
                }
                if let rightNoe = node.right {
                    stashQueue.append(rightNoe)
                }
            }
            depth += 1
            if !stashQueue.isEmpty {
                levelQueue.append(contentsOf: stashQueue)
                stashQueue.removeAll()
            }
            if levelQueue.isEmpty && stashQueue.isEmpty { break }
        }
        return depth
    }
}
