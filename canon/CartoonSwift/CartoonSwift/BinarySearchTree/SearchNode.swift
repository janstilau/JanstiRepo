//
//  SearchNode.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/10.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given the root node of a binary search tree (BST) and a value. You need to find the node in the BST that the node's value equals the given value. Return the subtree rooted with that node. If such node doesn't exist, you should return NULL.

 For example,

 Given the tree:
         4
        / \
       2   7
      / \
     1   3

 And the value to search: 2
 You should return this subtree:

       2
      / \
     1   3
 In the example above, if we want to search the value 5, since there is no node with value 5, we should return NULL.

 Note that an empty tree is represented by NULL, therefore you would see the expected output (serialized tree format) as [], not null.
 */

class SearchBST {
    func searchBST(_ root: TreeNode?, _ val: Int) -> TreeNode? {
        var current = root
        while current != nil {
            let currentValue = current!.val
            if currentValue == val {
                return current
            } else if currentValue > val {
                current = current?.left
            } else {
                current = current?.right
            }
        }
        return nil
    }
}
