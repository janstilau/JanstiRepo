//
//  ValidSquare.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/25.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
Given a string containing just the characters '(', ')', '{', '}', '[' and ']', determine if the input string is valid.

An input string is valid if:

Open brackets must be closed by the same type of brackets.
Open brackets must be closed in the correct order.
Note that an empty string is also considered valid.

Example 1:

Input: "()"
Output: true
Example 2:

Input: "()[]{}"
Output: true
Example 3:

Input: "(]"
Output: false
Example 4:

Input: "([)]"
Output: false
Example 5:

Input: "{[]}"
Output: true
 */

class ValidSquare {
    var leftSquares = [Character]()
    
    func isLeftSquare(char: Character) -> Bool {
        return char == "(" || char == "[" || char == "{"
    }
    func isRightSquare(char: Character) -> Bool {
        return char == ")" || char == "]" || char == "}"
    }
    func isValidRight(char: Character) -> Bool {
        if leftSquares.isEmpty { return false }
        if char == "}" {
            return leftSquares.last! == "{"
        } else if char == "]" {
            return leftSquares.last! == "["
        } else if char == ")" {
            return leftSquares.last! == "("
        } else {
            return false
        }
    }
    func isValid(_ s: String) -> Bool {
        leftSquares.removeAll()
        for aChar in s {
            if isLeftSquare(char: aChar) {
                leftSquares.append(aChar)
            } else if isRightSquare(char: aChar) {
                if isValidRight(char: aChar) {
                    leftSquares.removeLast()
                } else {
                    return false
                }
            }
        }
        return leftSquares.isEmpty
    }
}


/*
 假设按照升序排序的数组在预先未知的某个点上进行了旋转。

 ( 例如，数组 [0,1,2,4,5,6,7] 可能变为 [4,5,6,7,0,1,2] )。

 搜索一个给定的目标值，如果数组中存在这个目标值，则返回它的索引，否则返回 -1 。

 你可以假设数组中不存在重复的元素。

 你的算法时间复杂度必须是 O(log n) 级别。

 示例 1:

 输入: nums = [4,5,6,7,0,1,2], target = 0
 输出: 4
 示例 2:

 输入: nums = [4,5,6,7,0,1,2], target = 3
 输出: -1
 */


class findPivotSolution {
    func binarySearch(_ nums: [Int], left: Int, right: Int , _ target: Int) -> Int {
        if right < left { return -1 }
        var left = left
        var right = right
        while left <= right {
            let mid = left + (right-left)/2
            if nums[mid] == target {
                return mid
            } else if nums[mid] > target {
                right = mid - 1
            } else {
                left = mid + 1
            }
        }
        return -1
    }
    
    func findPivot(_ nums: [Int]) -> Int {
        var left = 0
        var right = nums.count - 1
        while left <= right {
            let mid = left + (right-left)/2
            if nums[mid] < nums[0] {
                if nums[mid-1] > nums[mid] {
                    return mid
                } else {
                    right = mid - 1
                }
            } else {
                if nums[mid+1] < nums[mid] {
                    return mid+1
                } else {
                    left = mid + 1
                }
            }
        }
        return -1
    }
    
    func search(_ nums: [Int], _ target: Int) -> Int {
        guard !nums.isEmpty else {
            return -1
        }
        if nums.first! <= nums.last! {
            return binarySearch(nums, left: 0, right: nums.count-1, target)
        }
        let pivot = findPivot(nums)
        let max = nums[pivot-1]
        let min = nums[pivot]
        if target > max || target < min { return -1 }
        if target >= nums[0] {
            return binarySearch(nums, left: 0, right: pivot-1, target)
        } else {
            return binarySearch(nums, left: pivot, right: nums.count-1, target)
        }
    }
}


/*
 在未排序的数组中找到第 k 个最大的元素。请注意，你需要找的是数组排序后的第 k 个最大的元素，而不是第 k 个不同的元素。

 示例 1:
123456
 输入: [3,2,1,5,6,4] 和 k = 2
 输出: 5
 示例 2:
122334556
 输入: [3,2,3,1,2,4,5,5,6] 和 k = 4
 输出: 4
 说明:

 你可以假设 k 总是有效的，且 1 ≤ k ≤ 数组的长度。
 */


class findKthLargestSolution {
    func findKthLargest(_ nums: [Int], _ k: Int) -> Int {
        var numTimes = [Int: Int]()
        for aNum in nums {
            if let _ = numTimes[aNum] {
                numTimes[aNum]! += 1
            } else {
                numTimes[aNum] = 1
            }
        }
        
        var kTh = k
        for aKey in numTimes.keys.sorted().reversed() {
            let times = numTimes[aKey]!
            kTh -= times
            if kTh <= 0 { return aKey }
        }
        return 1
    }
}
