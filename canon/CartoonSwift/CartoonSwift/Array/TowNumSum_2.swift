//
//  TowNumSum_2.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/27.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation
/*
 Given an array of integers that is already sorted in ascending order, find two numbers such that they add up to a specific target number.

 The function twoSum should return indices of the two numbers such that they add up to the target, where index1 must be less than index2.

 Note:

 Your returned answers (both index1 and index2) are not zero-based.
 You may assume that each input would have exactly one solution and you may not use the same element twice.
 Example:

 Input: numbers = [2,7,11,15], target = 9
 Output: [1,2]
 Explanation: The sum of 2 and 7 is 9. Therefore index1 = 1, index2 = 2.
 */

class TwoSum_2 {
    static func twoSum(_ numbers: [Int], _ target: Int) -> [Int] {
        let endIdx = numbers.count - 1
        var leftIdx = 0
        var rightIdx = endIdx
        
        while leftIdx < rightIdx {
            if numbers[leftIdx] + numbers[rightIdx] == target { break }
            if numbers[leftIdx] + numbers[rightIdx] > target {
                rightIdx -= 1
            } else if numbers[leftIdx] + numbers[rightIdx] < target {
                leftIdx += 1
            }
        }
        return [leftIdx+1, rightIdx+1]
    }
}
