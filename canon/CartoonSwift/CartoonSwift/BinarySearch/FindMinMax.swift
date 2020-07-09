//
//  FindMinMax.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/9.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given an array of integers nums sorted in ascending order, find the starting and ending position of a given target value.

 Your algorithm's runtime complexity must be in the order of O(log n).

 If the target is not found in the array, return [-1, -1].

 Example 1:

 Input: nums = [5,7,7,8,8,10], target = 8
 Output: [3,4]
 Example 2:

 Input: nums = [5,7,7,8,8,10], target = 6
 Output: [-1,-1]
  

 Constraints:

 0 <= nums.length <= 10^5
 -10^9 <= nums[i] <= 10^9
 nums is a non decreasing array.
 -10^9 <= target <= 10^9
 */

class FindMinMax {
    func findStart(_ nums: [Int], _ target: Int) -> Int {
        guard !nums.isEmpty else {
            return -1
        }
        
        var left = 0
        var right = nums.count - 1
        while left <= right {
            let mid = left + (right-left)/2
            let midValue = nums[mid]
            if midValue == target {
                if mid == 0 {
                    return mid
                } else if nums[mid-1] != nums[mid] {
                    return mid
                } else {
                    right = mid - 1
                }
            } else if midValue < target {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }
        
        return -1
    }
    func findEnd(_ nums: [Int], _ target: Int) -> Int {
        guard !nums.isEmpty else {
            return -1
        }
        
        var left = 0
        var right = nums.count - 1
        while left <= right {
            let mid = left + (right-left)/2
            let midValue = nums[mid]
            if midValue == target {
                if mid == nums.count-1 {
                    return mid
                } else if nums[mid+1] != nums[mid] {
                    return mid
                } else {
                    left = mid + 1
                }
            } else if midValue < target {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }
        
        return -1
    }
    func searchRange(_ nums: [Int], _ target: Int) -> [Int] {
        return [findStart(nums, target), findEnd(nums, target)]
    }
}


/*
 Given a sorted array arr, two integers k and x, find the k closest elements to x in the array. The result should also be sorted in ascending order. If there is a tie, the smaller elements are always preferred.
 Example 1:

 Input: arr = [1,2,3,4,5], k = 4, x = 3
 Output: [1,2,3,4]
 Example 2:

 Input: arr = [1,2,3,4,5], k = 4, x = -1
 Output: [1,2,3,4]
  

 Constraints:

 1 <= k <= arr.length
 1 <= arr.length <= 10^4
 Absolute value of elements in the array and x will not exceed 104
 */


class findClosestElements {
    func findInsertIdx(_ arr: [Int], _ x: Int) -> Int {
        var left = 0
        var right = arr.count - 1
        while left <= right {
            let mid = left + (right-left)/2
            let midVal = arr[mid]
            if midVal == x {
                if mid == arr.count - 1 {
                    return mid
                } else if arr[mid+1] == arr[mid] {
                    left = mid + 1
                }
                return mid
            } else if midVal < x {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }
        return left
    }
    
    func isValidIdx(_ arr: [Int], idx: Int) -> Bool {
        return 0 <= idx && idx < arr.count
    }
    
    func findClosestElements(_ arr: [Int], _ k: Int, _ x: Int) -> [Int] {
        guard arr.count >= k else {
            return []
        }
        var left = 0
        var right = arr.count - 1
        var counter = 0
        let maxStep = arr.count - k
        while counter < maxStep {
            let leftValue = arr[left]
            let rightValue = arr[right]
            if x - leftValue <= rightValue - x {
                right -= 1
            } else {
                left += 1
            }
            counter += 1
        }
        return [Int](arr[left...right])
    }
}


/*

     public List<Integer> findClosestElements(int[] arr, int k, int x) {
         int size = arr.length;

         int left = 0;
         int right = size - k;

         while (left < right) {
             int mid = (left + right) >>> 1;
             // 尝试从长度为 k + 1 的连续子区间删除一个元素
             // 从而定位左区间端点的边界值
             if (x - arr[mid] > arr[mid + k] - x) {
                 left = mid + 1;
             } else {
                 right = mid;
             }
         }

         List<Integer> res = new ArrayList<>();
         for (int i = left; i < left + k; i++) {
             res.add(arr[i]);
         }
         return res;
     }

 作者：liweiwei1419
 链接：https://leetcode-cn.com/problems/find-k-closest-elements/solution/pai-chu-fa-shuang-zhi-zhen-er-fen-fa-python-dai-ma/
 来源：力扣（LeetCode）
 著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。
 */


/*
 A peak element is an element that is greater than its neighbors.

 Given an input array nums, where nums[i] ≠ nums[i+1], find a peak element and return its index.

 The array may contain multiple peaks, in that case return the index to any one of the peaks is fine.

 You may imagine that nums[-1] = nums[n] = -∞.

 Example 1:

 Input: nums = [1,2,3,1]
 Output: 2
 Explanation: 3 is a peak element and your function should return the index number 2.
 Example 2:

 Input: nums = [1,2,1,3,5,6,4]
 Output: 1 or 5
 Explanation: Your function can return either index number 1 where the peak element is 2,
              or index number 5 where the peak element is 6.
 Follow up: Your solution should be in logarithmic complexity.
 */

