//
//  CenterIndex.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/26.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation
/*
 Given an array of integers nums, write a method that returns the "pivot" index of this array.

 We define the pivot index as the index where the sum of all the numbers to the left of the index is equal to the sum of all the numbers to the right of the index.

 If no such index exists, we should return -1. If there are multiple pivot indexes, you should return the left-most pivot index.

  

 Example 1:

 Input: nums = [1,7,3,6,5,6]
 Output: 3
 Explanation:
 The sum of the numbers to the left of index 3 (nums[3] = 6) is equal to the sum of numbers to the right of index 3.
 Also, 3 is the first index where this occurs.
 Example 2:

 Input: nums = [1,2,3]
 Output: -1
 Explanation:
 There is no index that satisfies the conditions in the problem statement.
  

 Constraints:

 The length of nums will be in the range [0, 10000].
 Each element nums[i] will be an integer in the range [-1000, 1000].
 */

class CenterIndex {
    /*
     [-1,-1,-1,-1,-1,0] 失败. 因为原来的思路, 默认了所有数字都是正数, 在遇到负数的时候, 下面的思路, 不能正常运行.
     */
    static func pivotIndex_error(_ nums: [Int]) -> Int {
        if nums.count <= 2 { return -1 }
        var leftIdx = 0
        var rightIdx = nums.count - 1
        
        var leftSum = nums[0]
        var rightSum = nums.last!
        
        while leftIdx < rightIdx {
            if leftSum < rightSum {
                leftIdx += 1
                leftSum += nums[leftIdx]
            } else {
                rightIdx -= 1
                rightSum += nums[rightIdx]
            }
        }
        if leftSum == rightSum {
            return leftIdx
        } else {
            return -1
        }
    }
    
    static func pivotIndex(_ nums: [Int]) -> Int {
        if nums.count <= 2 { return -1 }
        let sum = nums.reduce(0) { (result, aItem) -> Int in
            return result + aItem
        }
        var currentSum = 0
        for (idx, aNum) in nums.enumerated() {
            /*
             开头 idx, 和结尾 idx, 也被题目当做了 pivot, 我感觉是有问题的.
             */
//            if idx == 0 { continue }
//            if idx == nums.count - 1 { continue }
            /*
             除法这里会有损失, 乘法判断
             */
//            if currentSum == (sum-aNum)/2 {
            if currentSum*2 == sum-aNum {
                return idx
            }
            currentSum += aNum
        }
        return -1
    }
}
