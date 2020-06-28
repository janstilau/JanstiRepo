//
//  FindMin.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/29.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Suppose an array sorted in ascending order is rotated at some pivot unknown to you beforehand.

 (i.e.,  [0,1,2,4,5,6,7] might become  [4,5,6,7,0,1,2]).

 Find the minimum element.

 You may assume no duplicate exists in the array.

 Example 1:

 Input: [3,4,5,1,2]
 Output: 1
 Example 2:

 Input: [4,5,6,7,0,1,2]
 Output: 0
 */

/*
 这道题, 已经想到了, 二分查找的办法了, mid 和 left, right 比较, 消除一半的空间. 但是, 如果是没有发生旋转的数组, 会让这个算法死循环.
 */

class FindMinPivot {
    static func findMin(_ nums: [Int]) -> Int {
        if nums.count == 1 { return nums[0] }
        if nums.first! < nums.last! { return nums.first! }
        var left = 0
        var right = nums.count - 1
        var mid = left + (right-left)/2
        while true {
            if mid == 0 {
                if nums.last! > nums[mid] {
                    return nums[mid]
                } else if nums[mid+1] < nums[mid]{
                    return nums[mid+1]
                }
            } else if mid == nums.count-1 {
                if nums[mid-1] > nums[mid] {
                    return nums[mid]
                } else if nums[0] < nums[mid] {
                    return nums[0]
                }
            } else {
                if nums[mid-1] > nums[mid] {
                    return nums[mid]
                } else if nums[mid+1] < nums[mid] {
                    return nums[mid+1]
                }
            }
            if nums[left] < nums[mid] {
                left = mid
            } else {
                right = mid
            }
            mid = left + (right-left)/2
        }
    }
}
