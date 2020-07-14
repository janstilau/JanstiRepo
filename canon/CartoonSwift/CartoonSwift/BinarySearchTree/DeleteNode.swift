//
//  DeleteNode.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/10.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation


/*
 Given a root node reference of a BST and a key, delete the node with the given key in the BST. Return the root node reference (possibly updated) of the BST.

 Basically, the deletion can be divided into two stages:

 Search for a node to remove.
 If the node is found, delete the node.
 Note: Time complexity should be O(height of tree).

 Example:

 root = [5,3,6,2,4,null,7]
 key = 3

     5
    / \
   3   6
  / \   \
 2   4   7

 Given key to delete is 3. So we find the node with value 3 and delete it.

 One valid answer is [5,4,6,2,null,null,7], shown in the following BST.

     5
    / \
   4   6
  /     \
 2       7

 Another valid answer is [5,2,6,null,4,null,7].

     5
    / \
   2   6
    \   \
     4   7
 */

class CheckPermutation {
    func CheckPermutation(_ s1: String, _ s2: String) -> Bool {
        var frequenciesS1 = [Character: Int]()
        for aChar in s1 {
            if frequenciesS1.keys.contains(aChar) {
                frequenciesS1[aChar]? += 1
            } else {
                frequenciesS1[aChar] = 1
            }
        }
        var frequenciesS2 = [Character: Int]()
        for aChar in s2 {
            if frequenciesS2.keys.contains(aChar) {
                frequenciesS2[aChar]? += 1
            } else {
                frequenciesS2[aChar] = 1
            }
        }
        return frequenciesS2 == frequenciesS1
    }
}

class FindShortestSubArray {
    func findShortestSubArray(_ nums: [Int]) -> Int {
        guard !nums.isEmpty else {
            return 0
        }
        var rangeStash = [Int: (Int, Int)]()
        var numCounter = [Int: Int]()
        for (idx, aNum) in nums.enumerated() {
            if let range = rangeStash[aNum] {
                rangeStash[aNum] = (range.0, idx)
            } else {
                rangeStash[aNum] = (idx, idx)
            }
            if let count = numCounter[aNum] {
                numCounter[aNum] = count + 1
            } else {
                numCounter[aNum] = 1
            }
        }
        
        let maxAppearTimes = numCounter.values.max()!
        let keys = numCounter.keys.filter { (key) -> Bool in
            numCounter[key] == maxAppearTimes
        }
        let keySet = Set(keys)
        
        var result = Int.max
        for (key, value) in rangeStash {
            if !keySet.contains(key) { continue }
            let length = value.1 - value.0 + 1
            result = min(result, length)
        }
        return result
    }
}


class LeafSimilar {
    func leafSequence(root: TreeNode?) -> [Int] {
        guard let root = root else {
            return [Int]()
        }
        var result = [Int]()
        var stack = [TreeNode]()
        stack.append(root)
        while !stack.isEmpty {
            let topNode = stack.removeLast()
            if topNode.left == nil && topNode.right == nil {
                result.append(topNode.val)
                continue
            }
            if let rightNode = topNode.right {
                stack.append(rightNode)
            }
            if let leftNode = topNode.left {
                stack.append(leftNode)
            }
        }
        return result
    }
    
    func leafSimilar(_ root1: TreeNode?, _ root2: TreeNode?) -> Bool {
        guard root1 != nil && root2 != nil else {
            return false
        }
        let leftSequence = leafSequence(root: root1)
        let rightSequence = leafSequence(root: root2)
        return leftSequence == rightSequence
    }
}


class RunningSum {
    func runningSum(_ nums: [Int]) -> [Int] {
        var result = [Int]()
        result.reserveCapacity(nums.count)
        
        var sum = 0
        for (_, aNum) in nums.enumerated() {
            result.append(aNum + sum)
            sum += aNum
        }
        return result
    }
}

class MajorityElement {
    func majorityElement(_ nums: [Int]) -> Int {
        var timeCounter = [Int: Int]()
        for aNum in nums {
            if let times = timeCounter[aNum] {
                timeCounter[aNum] = times + 1
            } else {
                timeCounter[aNum] = 1
            }
        }
        let maxTimes = timeCounter.values.max()!
        return timeCounter.keys.first { (key) -> Bool in
            timeCounter[key] == maxTimes
        }!
    }
}


class ReverseList_Demo {
    func reverseList(_ head: ListNode?) -> ListNode? {
        guard head != nil else {
            return nil
        }
        let sentinelHead = ListNode(-1)
        sentinelHead.next = head
        var nextNode = head?.next
        head?.next = nil
        while nextNode != nil {
            let tempNode = nextNode?.next
            nextNode?.next = sentinelHead.next
            sentinelHead.next = nextNode
            nextNode = tempNode
        }
        return sentinelHead.next
    }
}

/*
 Given two strings s and t, determine if they are isomorphic.

 Two strings are isomorphic if the characters in s can be replaced to get t.

 All occurrences of a character must be replaced with another character while preserving the order of characters. No two characters may map to the same character but a character may map to itself.

 Example 1:

 Input: s = "egg", t = "add"
 Output: true
 Example 2:

 Input: s = "foo", t = "bar"
 Output: false
 Example 3:

 Input: s = "paper", t = "title"
 Output: true
 Note:
 You may assume both s and t have the same length.
 */

