//
//  LevelIterator.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/5.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given a binary tree, return the level order traversal of its nodes' values. (ie, from left to right, level by level).

 For example:
 Given binary tree [3,9,20,null,null,15,7],
     3
    / \
   9  20
     /  \
    15   7
 return its level order traversal as:
 [
   [3],
   [9,20],
   [15,7]
 ]
 */

class LevelIterator {
    func levelOrder(_ root: TreeNode?) -> [[Int]] {
        var result = [[Int]]()
        guard let root = root else {
            return result
        }
        var levelQueue = [TreeNode]()
        levelQueue.append(root)
        while !levelQueue.isEmpty {
            var levelValueStash = [Int]()
            var levelNodeStash = [TreeNode]()
            for idx in 0..<levelQueue.count {
                let aNode = levelQueue[idx]
                levelValueStash.append(aNode.val)
                if let leftNode = aNode.left {
                    levelNodeStash.append(leftNode)
                }
                if let rightNode = aNode.right {
                    levelNodeStash.append(rightNode)
                }
            }
            levelQueue.removeAll()
            levelQueue.append(contentsOf: levelNodeStash)
            result.append(levelValueStash)
        }
        return result
    }
}
