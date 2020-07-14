//
//  IteratorSearchTree.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/10.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Implement an iterator over a binary search tree (BST). Your iterator will be initialized with the root node of a BST.

 Calling next() will return the next smallest number in the BST.

  

 Example:



 BSTIterator iterator = new BSTIterator(root);
 iterator.next();    // return 3
 iterator.next();    // return 7
 iterator.hasNext(); // return true
 iterator.next();    // return 9
 iterator.hasNext(); // return true
 iterator.next();    // return 15
 iterator.hasNext(); // return true
 iterator.next();    // return 20
 iterator.hasNext(); // return false
  

 Note:

 next() and hasNext() should run in average O(1) time and uses O(h) memory, where h is the height of the tree.
 You may assume that next() call will always be valid, that is, there will be at least a next smallest number in the BST when next() is called.
 */

/*
 var stack = [TreeNode]()
 var current = root
 while current != nil || !stack.isEmpty {
     if current != nil {
         stack.append(current!)
         current = current?.left
         continue
     }
     let topNode = stack.removeLast()
     current = topNode.right
 }
 */

class BSTIterator {

    var stack: [TreeNode]
    var currentTreeNode: TreeNode?
    
    init(_ root: TreeNode?) {
        stack = [TreeNode]()
        currentTreeNode = root
    }

    /** @return the next smallest number */
    func next() -> Int {
        while let currentNode = currentTreeNode {
            stack.append(currentNode)
            currentTreeNode = currentNode.left
        }
        let topNode = stack.removeLast()
        currentTreeNode = topNode.right
        return topNode.val
    }

    /** @return whether we have a next smallest number */
    func hasNext() -> Bool {
        return currentTreeNode != nil || !stack.isEmpty
    }
}


/**
 * Your BSTIterator object will be instantiated and called as such:
 * BSTIterator* obj = new BSTIterator(root);
 * int param_1 = obj->next();
 * bool param_2 = obj->hasNext();
 */
