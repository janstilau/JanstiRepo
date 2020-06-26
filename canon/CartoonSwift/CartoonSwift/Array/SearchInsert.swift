//
//  SearchInsert.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/26.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given a sorted array and a target value, return the index if the target is found. If not, return the index where it would be if it were inserted in order.

 You may assume no duplicates in the array.

 Example 1:

 Input: [1,3,5,6], 5
 Output: 2
 Example 2:

 Input: [1,3,5,6], 2
 Output: 1
 Example 3:

 Input: [1,3,5,6], 7
 Output: 4
 Example 4:

 Input: [1,3,5,6], 0
 Output: 0
 */

class SearchInsert {
    /*
     二分查找就可以
     */
    static func searchInsert(_ nums: [Int], _ target: Int) -> Int {
        if nums.isEmpty { return 0 }
        var left = 0
        var right = nums.count-1
        while left <= right {
            let midIdx = (left+right) / 2
            let midNum = nums[midIdx]
            if midNum == target {
                return midIdx
            } else if midNum < target {
                left = midIdx + 1
            } else {
                right = midIdx - 1
            }
        }
        return left
    }
}
