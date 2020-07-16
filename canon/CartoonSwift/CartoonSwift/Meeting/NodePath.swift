//
//  NodePath.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/16.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 输入一棵二叉树和一个整数，打印出二叉树中节点值的和为输入整数的所有路径。从树的根节点开始往下一直到叶节点所经过的节点形成一条路径。
 
 示例:
 给定如下二叉树，以及目标和 sum = 22，

               5
              / \
             4   8
            /   / \
           11  13  4
          /  \    / \
         7    2  5   1
 返回:

 [
    [5,4,11,2],
    [5,8,4,5]
 ]

 来源：力扣（LeetCode）
 链接：https://leetcode-cn.com/problems/er-cha-shu-zhong-he-wei-mou-yi-zhi-de-lu-jing-lcof
 著作权归领扣网络所有。商业转载请联系官方授权，非商业转载请注明出处。
 */

class PathSum {
    func pathSum(_ root: TreeNode?, _ sum: Int) -> [[Int]] {
        guard root != nil else {
            return [[Int]]()
        }
        var result = [[Int]]()
        var path = [Int]()
        preOrder(root, remain: sum, path: &path, result: &result)
        return result
    }
    
    func preOrder(_ root: TreeNode?, remain: Int, path: inout [Int], result: inout [[Int]]) {
        guard let root = root else {
            return
        }
        path.append(root.val)
        let subTreeRemain = remain - root.val
        if subTreeRemain == 0 && root.left == nil && root.right == nil {
            result.append(path)
        }
        preOrder(root.left, remain: subTreeRemain, path: &path, result: &result)
        preOrder(root.right, remain: subTreeRemain, path: &path, result: &result)
        path.removeLast()
    }
}


