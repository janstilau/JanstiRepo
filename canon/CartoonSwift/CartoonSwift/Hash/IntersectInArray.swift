//
//  IntersectInArray.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/8.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given two arrays, write a function to compute their intersection.

 Example 1:

 Input: nums1 = [1,2,2,1], nums2 = [2,2]
 Output: [2]
 Example 2:

 Input: nums1 = [4,9,5], nums2 = [9,4,9,8,4]
 Output: [9,4]
 Note:

 Each element in the result must be unique.
 The result can be in any order.
 */

class IntersectnArray {
    func intersection(_ nums1: [Int], _ nums2: [Int]) -> [Int] {
        let numsSet = Set(nums1)
        return [Int](numsSet.intersection(nums2))
    }
}


/*
 Write an algorithm to determine if a number n is "happy".

 A happy number is a number defined by the following process: Starting with any positive integer, replace the number by the sum of the squares of its digits, and repeat the process until the number equals 1 (where it will stay), or it loops endlessly in a cycle which does not include 1. Those numbers for which this process ends in 1 are happy numbers.

 Return True if n is a happy number, and False if not.

 Example:

 Input: 19
 Output: true
 Explanation:
 12 + 92 = 82
 82 + 22 = 68
 62 + 82 = 100
 12 + 02 + 02 = 1
 */

class HappyNum {
    static func isHappy(_ n: Int) -> Bool {
        if n == 1 { return true }
        var happendNum = Set<Int>()
        var loopSum = n
        while loopSum != 1 {
            happendNum.insert(loopSum)
            
            var accumSum = 0
            while loopSum > 0 {
                let lastDigit = loopSum % 10
                accumSum += lastDigit * lastDigit
                loopSum /= 10
            }
            loopSum = accumSum
            if happendNum.contains(loopSum) { return false }
        }
        return true
    }
}
