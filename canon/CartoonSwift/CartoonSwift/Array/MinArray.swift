//
//  MinArray.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/27.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation
/*
 Given an array of n positive integers and a positive integer s, find the minimal length of a contiguous subarray of which the sum ≥ s. If there isn't one, return 0 instead.

 Example:

 Input: s = 7, nums = [2,3,1,2,4,3]
 Output: 2
 Explanation: the subarray [4,3] has the minimal length under the problem constraint.
 Follow up:
 If you have figured out the O(n) solution, try coding another solution of which the time complexity is O(n log n).
 */

class MinArray {
    func minSubArrayLen(_ s: Int, _ nums: [Int]) -> Int {
        guard !nums.isEmpty else {
            return 0
        }
        
        var left = 0
        var right = 0
        var minLength = Int.max
        
        let count = nums.count
        
        var sum = 0
        
        while right < count {
            sum += nums[right]
            if sum >= s {
                let aNewLength = right - left + 1
                if aNewLength <= minLength {
                    minLength = aNewLength
                }
                while sum >= s {
                    let aNewLength = right - left + 1
                    if aNewLength <= minLength {
                        minLength = aNewLength
                    }
                    sum -= nums[left]
                    left += 1
                }
                right += 1
            } else {
                right += 1
            }
        }
        if (minLength == Int.max) { minLength = 0}
        return minLength
    }
}
