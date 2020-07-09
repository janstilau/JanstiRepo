//
//  PlainSearch.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/8.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given a sorted (in ascending order) integer array nums of n elements and a target value, write a function to search target in nums. If target exists, then return its index, otherwise return -1.


 Example 1:

 Input: nums = [-1,0,3,5,9,12], target = 9
 Output: 4
 Explanation: 9 exists in nums and its index is 4

 Example 2:

 Input: nums = [-1,0,3,5,9,12], target = 2
 Output: -1
 Explanation: 2 does not exist in nums so return -1
  

 Note:

 You may assume that all elements in nums are unique.
 n will be in the range [1, 10000].
 The value of each element in nums will be in the range [-9999, 9999].
 */

class PlainSearch {
    /*
     二分查找的最基础和最基本的形式。
     查找条件可以在不与元素的两侧进行比较的情况下确定（或使用它周围的特定元素）。
     不需要后处理，因为每一步中，你都在检查是否找到了元素。如果到达末尾，则知道未找到该元素。
     初始条件：left = 0, right = length-1
     终止：left > right
     向左查找：right = mid-1
     向右查找：left = mid+1
     */
    func search(_ nums: [Int], _ target: Int) -> Int {
        var left = 0
        var right = nums.count - 1
        while left <= right {
            let mid = left + (right-left)/2
            let midValue = nums[mid]
            if midValue == target {
                return mid
            } else if midValue < target {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }
        return -1
    }
}


/*
 二分查找是一种在每次比较之后将查找空间一分为二的算法。每次需要查找集合中的索引或元素时，都应该考虑二分查找。如果集合是无序的，我们可以总是在应用二分查找之前先对其进行排序。

 二分查找一般由三个主要部分组成：

 预处理 —— 如果集合未排序，则进行排序。

 二分查找 —— 使用循环或递归在每次比较后将查找空间划分为两半。

 后处理 —— 在剩余空间中确定可行的候选者。
 
 */


/*
 Implement int sqrt(int x).

 Compute and return the square root of x, where x is guaranteed to be a non-negative integer.

 Since the return type is an integer, the decimal digits are truncated and only the integer part of the result is returned.

 Example 1:

 Input: 4
 Output: 2
 Example 2:

 Input: 8
 Output: 2
 Explanation: The square root of 8 is 2.82842..., and since
              the decimal part is truncated, 2 is returned.
 */

class Sqrt {
    static func mySqrt(_ x: Int) -> Int {
        var left = 1
        var right = x
        while left <= right {
            let mid = left + (right-left)/2
            let square = mid * mid
            if square == x {
                return mid
            } else if square > x {
                right = mid - 1
            } else {
                left = mid + 1
            }
        }
        return right
    }
}


/*
 We are playing the Guess Game. The game is as follows:

 I pick a number from 1 to n. You have to guess which number I picked.

 Every time you guess wrong, I'll tell you whether the number is higher or lower.

 You call a pre-defined API guess(int num) which returns 3 possible results (-1, 1, or 0):

 -1 : My number is lower
  1 : My number is higher
  0 : Congrats! You got it!
 Example :

 Input: n = 10, pick = 6
 Output: 6
 */

class GuessNum {
    func guess(_ num: Int) -> Int {
        return -1
    }
    func guessNumber(_ n: Int) -> Int {
        var left = 1
        var right = n
        while left < right {
            let mid = left + (right-left)/2
            let result = guess(mid)
            if result == 0 {
                return mid
            } else if result == -1 {
                right = mid-1
            } else {
                left = mid+1
            }
        }
        return -1
    }
}

/*
 Suppose an array sorted in ascending order is rotated at some pivot unknown to you beforehand.

 (i.e., [0,1,2,4,5,6,7] might become [4,5,6,7,0,1,2]).

 You are given a target value to search. If found in the array return its index, otherwise return -1.

 You may assume no duplicate exists in the array.

 Your algorithm's runtime complexity must be in the order of O(log n).

 Example 1:

 Input: nums = [4,5,6,7,0,1,2], target = 0
 Output: 4
 Example 2:

 Input: nums = [4,5,6,7,0,1,2], target = 3
 Output: -1
 */


class SearchPivot {
    static func binarySearch(_ nums: [Int], left: Int, right: Int , _ target: Int) -> Int {
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
    static func findPivot(_ nums: [Int]) -> Int {
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
    static func search(_ nums: [Int], _ target: Int) -> Int {
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
        if target > nums[0] {
            return binarySearch(nums, left: 0, right: pivot-1, target)
        } else {
            return binarySearch(nums, left: pivot, right: nums.count-1, target)
        }
    }
}

/*
 class Solution {
 public:
     int search(vector<int>& nums, int target) {
         int n = (int)nums.size();
         if (!n) return -1;
         if (n == 1) return nums[0] == target ? 0 : -1;
         int l = 0, r = n - 1;
         while (l <= r) {
             int mid = (l + r) / 2;
             if (nums[mid] == target) return mid;
             if (nums[0] <= nums[mid]) { // 通过 nums[0] <= nums[mid] 来判断, 0 到 mid 是不是在有序的状态.
                 if (nums[0] <= target && target < nums[mid]) {
                     r = mid - 1; // 如果在target 在范围内, 继续寻找.
                 } else {
                     l = mid + 1; // 否则到另一侧寻找.
                 }
             } else { // 如果上面是无序的, 那么这边就是有序的.
                 if (nums[mid] < target && target <= nums[n - 1]) {
                     l = mid + 1; // 在范围内, 范围内寻找
                 } else {
                     r = mid - 1; // 在另一侧寻找.
                 }
             }
         }
         return -1;
     }
 };

 作者：LeetCode-Solution
 链接：https://leetcode-cn.com/problems/search-in-rotated-sorted-array/solution/sou-suo-xuan-zhuan-pai-xu-shu-zu-by-leetcode-solut/
 来源：力扣（LeetCode）
 著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。
 */
