//
//  SearchTree.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/5.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given a binary tree, determine if it is a valid binary search tree (BST).

 Assume a BST is defined as follows:

 The left subtree of a node contains only nodes with keys less than the node's key.
 The right subtree of a node contains only nodes with keys greater than the node's key.
 Both the left and right subtrees must also be binary search trees.
  

 Example 1:

     2
    / \
   1   3

 Input: [2,1,3]
 Output: true
 Example 2:

     5
    / \
   1   4
      / \
     3   6

 Input: [5,1,4,null,null,3,6]
 Output: false
 Explanation: The root node's value is 5 but its right child's value is 4.
 */

/*
 [10,5,15,null,null,6,20]
 */
class ValidBst {
    func isValidBST(_ root: TreeNode?) -> Bool {
        var inorderValues = [TreeNode]()
        inorder(array: &inorderValues, currentNode: root)
        if inorderValues.count <= 1 { return true }
        for idx in 0..<inorderValues.count-1 {
            if inorderValues[idx].val >= inorderValues[idx+1].val { return false}
        }
        return true
    }
    
    func inorder(array: inout [TreeNode], currentNode:TreeNode?) {
        guard let currentNode = currentNode else {
            return
        }
        inorder(array: &array, currentNode: currentNode.left)
        array.append(currentNode)
        inorder(array: &array, currentNode: currentNode.right)
    }
    
}

/*
 class Solution {
 public:
     bool helper(TreeNode* root, long long lower, long long upper) {
         if (root == nullptr) return true;
         if (root -> val <= lower || root -> val >= upper) return false;
         return helper(root -> left, lower, root -> val) && helper(root -> right, root -> val, upper);
     }
     bool isValidBST(TreeNode* root) {
         return helper(root, LONG_MIN, LONG_MAX);
     }
 };

 用递归的解法, 判断的应该是一个界限, 而不是仅仅是和 rootNode 的值进行比较.
 这样, 每次进入下层的递归, 界限都在进行缩小.
 */
