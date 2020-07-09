//
//  TreeNode.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/9.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given a binary tree, return the preorder traversal of its nodes' values.

 Example:

 Input: [1,null,2,3]
    1
     \
      2
     /
    3

 Output: [1,2,3]
 Follow up: Recursive solution is trivial, could you do it iteratively?
 */

class PreOrder {
    func preorderTraversal(_ root: TreeNode?) -> [Int] {
        guard let root = root else {
            return [Int]()
        }
        var result = [Int]()
        var stack = [TreeNode]()
        stack.append(root)
        while !stack.isEmpty {
            let topNode = stack.removeLast()
            result.append(topNode.val)
            if let rightNode = topNode.right {
                stack.append(rightNode)
            }
            if let leftNode = topNode.left {
                stack.append(leftNode)
            }
        }
        return result
    }
    
    func preorderRecursive(_ root: TreeNode?, nums: inout [Int]) {
        guard let root = root else {
            return
        }
        nums.append(root.val)
        preorderRecursive(root.left, nums: &nums)
        preorderRecursive(root.right, nums: &nums)
    }
}

/*
 Given a binary tree, return the inorder traversal of its nodes' values.

 Example:

 Input: [1,null,2,3]
    1
     \
      2
     /
    3

 Output: [1,3,2]
 Follow up: Recursive solution is trivial, could you do it iteratively?
 */

class Inorder {
    func inorderTraversal(_ root: TreeNode?) -> [Int] {
//        var nums = [Int]()
//        inorderRecursive(root, nums: &nums)
//        return nums
        
        var result = [Int]()
        var stack = [TreeNode]()
        var current = root
        while current != nil || !stack.isEmpty {
            if current != nil {
                stack.append(current!)
                current = current?.left
                continue
            }
            let topNode = stack.removeLast()
            result.append(topNode.val)
            current = topNode.right
        }
        return result
    }
    
    func inorderRecursive(_ root: TreeNode?, nums: inout [Int]) {
        guard let root = root else {
            return
        }
        inorderRecursive(root.left, nums: &nums)
        nums.append(root.val)
        inorderRecursive(root.right, nums: &nums)
    }
}


class PostOrder {
    func postorderTraversal(_ root: TreeNode?) -> [Int] {
        var result = [Int]()
        postoderRecursive(root, nums: &result)
        return result
    }
    
    func postoderRecursive(_ root: TreeNode?, nums: inout [Int]) {
        guard let root = root else {
            return
        }
        postoderRecursive(root.left, nums: &nums)
        postoderRecursive(root.right, nums: &nums)
        nums.append(root.val)
    }
}
