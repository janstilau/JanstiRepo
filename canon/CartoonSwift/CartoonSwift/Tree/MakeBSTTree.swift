//
//  MakeBSTTree.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/5.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given an array where elements are sorted in ascending order, convert it to a height balanced BST.

 For this problem, a height-balanced binary tree is defined as a binary tree in which the depth of the two subtrees of every node never differ by more than 1.

 Example:

 Given the sorted array: [-10,-3,0,5,9],

 One possible answer is: [0,-3,9,-10,null,5], which represents the following height balanced BST:

       0
      / \
    -3   9
    /   /
  -10  5
 */

class SortedArrayToBST {
    func makeNode(_ nums: [Int], leftIdx: Int, rightIdx: Int) -> TreeNode? {
        if leftIdx > rightIdx { return nil }
        let middle = leftIdx + (rightIdx-leftIdx)/2
        let result = TreeNode(nums[middle])
        result.left = makeNode(nums, leftIdx: leftIdx, rightIdx: middle-1)
        result.right = makeNode(nums, leftIdx: middle+1, rightIdx: rightIdx)
        return result
    }
    
    func sortedArrayToBST(_ nums: [Int]) -> TreeNode? {
        if nums.isEmpty { return nil }
        let result = makeNode(nums, leftIdx: 0, rightIdx: nums.count-1)
        return result
    }
}
