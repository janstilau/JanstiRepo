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
            let topNode = stack.removeLast() // 访问节点
            result.append(topNode.val)
            if let rightNode = topNode.right {
                stack.append(rightNode) // 添加节点到栈中, 不访问
            }
            if let leftNode = topNode.left {
                stack.append(leftNode) // 添加节点到栈中, 不访问
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

/*
 栈的结构, 入栈不算访问数据, 出栈才算访问数据.
 所以, 用循环模拟递归的过程, 就是不断的控制入栈的顺序的过程.
 最晚进行访问的, 最先进行入栈的操作.
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
                stack.append(current!) // 添加节点, 此时节点有可能是左节点, 也有可能是右节点.
                current = current?.left
                continue
            }
            let topNode = stack.removeLast() // 访问节点
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
