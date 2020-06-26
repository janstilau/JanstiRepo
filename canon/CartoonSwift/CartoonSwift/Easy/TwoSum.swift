//
//  TwoSum.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/26.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation
/*
 Given an array of integers, return indices of the two numbers such that they add up to a specific target.

 You may assume that each input would have exactly one solution, and you may not use the same element twice.

 Example:

 Given nums = [2, 7, 11, 15], target = 9,

 Because nums[0] + nums[1] = 2 + 7 = 9,
 return [0, 1].
 */
class TwoSum {
    func twoSum(_ nums: [Int], _ target: Int) -> [Int] {
        var remain = [Int: Int]()
        for (idx, aNum) in nums.enumerated() {
            remain[target-aNum] = idx
        }
        for (idx, aNum) in nums.enumerated() {
            if remain.keys.contains(aNum),
                remain[aNum]! != idx{
                return [idx, remain[aNum]!]
            }
        }
        return []
    }
}
