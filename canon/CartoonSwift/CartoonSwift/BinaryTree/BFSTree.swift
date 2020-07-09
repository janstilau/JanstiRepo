//
//  BFS.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/10.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 层序遍历就是逐层遍历树结构。

 广度优先搜索是一种广泛运用在树或图这类数据结构中，遍历或搜索的算法。 该算法从一个根节点开始，首先访问节点本身。 然后遍历它的相邻节点，其次遍历它的二级邻节点、三级邻节点，以此类推。

 当我们在树中进行广度优先搜索时，我们访问的节点的顺序是按照层序遍历顺序的。

 这是一个层序顺序遍历的例子：
 通常，我们使用一个叫做队列的数据结构来帮助我们做广度优先搜索。 如果您对队列不熟悉，可以在我们即将推出的另一张卡片中找到更多有关信息。
 */

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

class LevelOrser {
    func levelOrder(_ root: TreeNode?) -> [[Int]] {
        guard let root = root else {
            return [[Int]]()
        }
        var levelNodes = [TreeNode]()
        var nextLevelNodes = [TreeNode]()
        var levelQueue = [Int]()
        var result = [[Int]]()
        levelNodes.append(root)
        while !levelNodes.isEmpty {
            levelQueue.removeAll()
            nextLevelNodes.removeAll()
            while !levelNodes.isEmpty {
                let topNode = levelNodes.removeFirst()
                levelQueue.append(topNode.val)
                if let leftNode = topNode.left {
                    nextLevelNodes.append(leftNode)
                }
                if let rightNode = topNode.right {
                    nextLevelNodes.append(rightNode)
                }
            }
            result.append(levelQueue)
            levelNodes = nextLevelNodes
        }
        return result
    }
}
