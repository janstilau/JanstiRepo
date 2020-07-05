
//
//  SymmetricNode.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/5.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given a binary tree, check whether it is a mirror of itself (ie, symmetric around its center).

 For example, this binary tree [1,2,2,3,4,4,3] is symmetric:

     1
    / \
   2   2
  / \ / \
 3  4 4  3
  

 But the following [1,2,2,null,3,null,3] is not:

     1
    / \
   2   2
    \   \
    3    3
  

 Follow up: Solve it both recursively and iteratively.
 */

extension TreeNode: Equatable {
    public static func == (lhs: TreeNode, rhs: TreeNode) -> Bool {
        return lhs.val == rhs.val
    }
}

class SymmetricTree {
    func isSymmetric(_ root: TreeNode?) -> Bool {
        var queue = [TreeNode?]()
        queue.append(root)
        while !queue.isEmpty {
            var left = 0
            var right = queue.count-1
            while left <= right {
                if queue[left] != queue[right] { return false }
                left += 1
                right -= 1
            }
            var stash = [TreeNode?]()
            for aNode in queue {
                stash.append(aNode?.left)
                stash.append(aNode?.right)
            }
            if stash.allSatisfy({$0 == nil}) { return true }
            queue.removeAll()
            queue.append(contentsOf: stash)
        }
        return true
    }
}
