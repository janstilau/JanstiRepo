//
//  RotateArrayK.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/30.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given an array, rotate the array to the right by k steps, where k is non-negative.

 Follow up:

 Try to come up as many solutions as you can, there are at least 3 different ways to solve this problem.
 Could you do it in-place with O(1) extra space?
  

 Example 1:

 Input: nums = [1,2,3,4,5,6,7], k = 3
 Output: [5,6,7,1,2,3,4]
 Explanation:
 rotate 1 steps to the right: [7,1,2,3,4,5,6]
 rotate 2 steps to the right: [6,7,1,2,3,4,5]
 rotate 3 steps to the right: [5,6,7,1,2,3,4]
 Example 2:

 Input: nums = [-1,-100,3,99], k = 2
 Output: [3,99,-1,-100]
 Explanation:
 rotate 1 steps to the right: [99,-1,-100,3]
 rotate 2 steps to the right: [3,99,-1,-100]
  

 Constraints:

 1 <= nums.length <= 2 * 10^4
 It's guaranteed that nums[i] fits in a 32 bit-signed integer.
 k >= 0
 */

class RotateArrayK {
    static func rotate(_ nums: inout [Int], _ k: Int) {
        guard !nums.isEmpty else {
            return
        }
        guard k >= 0 else {
            return
        }
        if k == 0 { return }
        
        let length = nums.count
        let step = k%length
        if step == 0 { return }
        
        let leftSize = length - step
        let rightSize = step
        
        let cacheLeft = nums[0...leftSize-1]
        nums[0..<rightSize] = nums[length-rightSize...length-1]
        nums[rightSize...length-1] = cacheLeft
    }
}

/*
 Given two arrays, write a function to compute their intersection.

 Example 1:

 Input: nums1 = [1,2,2,1], nums2 = [2,2]
 Output: [2,2]
 Example 2:

 Input: nums1 = [4,9,5], nums2 = [9,4,9,8,4]
 Output: [4,9]
 Note:

 Each element in the result should appear as many times as it shows in both arrays.
 The result can be in any order.
 Follow up:

 What if the given array is already sorted? How would you optimize your algorithm?
 What if nums1's size is small compared to nums2's size? Which algorithm is better?
 What if elements of nums2 are stored on disk, and the memory is limited such that you cannot load all elements into the memory at once?
 */

class IntersectInArray {
    func intersect(_ nums1: [Int], _ nums2: [Int]) -> [Int] {
        var nums1Times = [Int:Int]()
        for aNum in nums1 {
            if nums1Times.keys.contains(aNum) {
                nums1Times[aNum]! += 1
            } else {
                nums1Times[aNum] = 1
            }
        }
        var result = [Int]()
        for aNum in nums2 {
            if nums1Times.keys.contains(aNum) {
                result.append(aNum)
                nums1Times[aNum]! -= 1
                if nums1Times[aNum]! == 0 {
                    nums1Times.removeValue(forKey: aNum)
                }
            }
        }
        return result
    }
}



/*
 Given a non-empty array of digits representing a non-negative integer, plus one to the integer.

 The digits are stored such that the most significant digit is at the head of the list, and each element in the array contain a single digit.

 You may assume the integer does not contain any leading zero, except the number 0 itself.

 Example 1:

 Input: [1,2,3]
 Output: [1,2,4]
 Explanation: The array represents the integer 123.
 Example 2:

 Input: [4,3,2,1]
 Output: [4,3,2,2]
 Explanation: The array represents the integer 4321.
 */

class PlusOne {
    func plusOne(_ digits: [Int]) -> [Int] {
        var added = 1
        var result = digits
        for idx in (0...digits.count-1).reversed() {
            let sum = digits[idx] + added
            added = sum / 10
            result[idx] = sum % 10
            if added == 0 { break }
        }
        if added == 1 {
            result.insert(1, at: 0)
        }
        return result
    }
}

/*
 Given an array of integers, return indices of the two numbers such that they add up to a specific target.

 You may assume that each input would have exactly one solution, and you may not use the same element twice.

 Example:

 Given nums = [2, 7, 11, 15], target = 9,

 Because nums[0] + nums[1] = 2 + 7 = 9,
 return [0, 1].
 */

class TwoSum__1 {
    func twoSum(_ nums: [Int], _ target: Int) -> [Int] {
        var dict = [Int:(Int, Int)]()
        dict.reserveCapacity(nums.count)
        for (idx, aNum) in nums.enumerated() {
            if let (_, targetIdx) = dict[target - aNum] {
                return [idx, targetIdx]
            }
            dict[aNum] = (target - aNum, idx)
        }
        return [0, 0]
    }
}
