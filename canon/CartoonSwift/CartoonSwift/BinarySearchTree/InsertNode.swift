//
//  InsertNode.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/10.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 nsert into a Binary Search Tree
 Given the root node of a binary search tree (BST) and a value to be inserted into the tree, insert the value into the BST. Return the root node of the BST after the insertion. It is guaranteed that the new value does not exist in the original BST.

 Note that there may exist multiple valid ways for the insertion, as long as the tree remains a BST after insertion. You can return any of them.

 For example,

 Given the tree:
         4
        / \
       2   7
      / \
     1   3
 And the value to insert: 5
 You can return this binary search tree:

          4
        /   \
       2     7
      / \   /
     1   3 5
 This tree is also valid:

          5
        /   \
       2     7
      / \
     1   3
          \
           4
  

 Constraints:

 The number of nodes in the given tree will be between 0 and 10^4.
 Each node will have a unique integer value from 0 to -10^8, inclusive.
 -10^8 <= val <= 10^8
 It's guaranteed that val does not exist in the original BST.
 */

/**
 * Definition for a binary tree node.
 * public class TreeNode {
 *     public var val: Int
 *     public var left: TreeNode?
 *     public var right: TreeNode?
 *     public init() { self.val = 0; self.left = nil; self.right = nil; }
 *     public init(_ val: Int) { self.val = val; self.left = nil; self.right = nil; }
 *     public init(_ val: Int, _ left: TreeNode?, _ right: TreeNode?) {
 *         self.val = val
 *         self.left = left
 *         self.right = right
 *     }
 * }
 */

class InsertIntoBST {
    func insertIntoBST(_ root: TreeNode?, _ val: Int) -> TreeNode? {
        let insertedNode = TreeNode(val)
        guard root != nil else {
            return insertedNode
        }
        var current = root
        while current != nil {
            let currentNode = current!
            let currentValue = current!.val
            if val == currentValue {
                if currentNode.left == nil {
                    currentNode.left = insertedNode
                    break
                } else {
                    current = currentNode.left
                }
            } else if val < currentValue {
                if currentNode.left == nil {
                    currentNode.left = insertedNode
                    break
                } else {
                    current = currentNode.left
                }
            } else {
                if currentNode.right == nil {
                    currentNode.right = insertedNode
                    break
                } else {
                    current = currentNode.right
                }
            }
        }
        return root
    }
}
