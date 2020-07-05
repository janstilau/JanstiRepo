//
//  MergeTwoArray.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/5.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given two sorted integer arrays nums1 and nums2, merge nums2 into nums1 as one sorted array.

 Note:

 The number of elements initialized in nums1 and nums2 are m and n respectively.
 You may assume that nums1 has enough space (size that is equal to m + n) to hold additional elements from nums2.
 Example:

 Input:
 nums1 = [1,2,3,0,0,0], m = 3
 nums2 = [2,5,6],       n = 3

 Output: [1,2,2,3,5,6]
  

 Constraints:

 -10^9 <= nums1[i], nums2[i] <= 10^9
 nums1.length == m + n
 nums2.length == n
 */

class MergeSortedTwoArray {
    static func merge(_ nums1: inout [Int], _ m: Int, _ nums2: [Int], _ n: Int) {
        let totalLength = m+n
        if nums1.capacity < totalLength {
            nums1.reserveCapacity(totalLength)
        }
        while nums1.count < totalLength {
            nums1.append(-1)
        }
        
        var lhsPtr = m - 1
        var rhsPtr = n - 1
        var totalPtr = totalLength - 1
        while lhsPtr >= 0 && rhsPtr >= 0 {
            if nums1[lhsPtr] > nums2[rhsPtr] {
                nums1[totalPtr] = nums1[lhsPtr]
                lhsPtr -= 1
            } else {
                nums1[totalPtr] = nums2[rhsPtr]
                rhsPtr -= 1
            }
            totalPtr -= 1
        }
        while lhsPtr >= 0 {
            nums1[totalPtr] = nums1[lhsPtr]
            lhsPtr -= 1
            totalPtr -= 1
        }
        while rhsPtr >= 0 {
            nums1[totalPtr] = nums2[rhsPtr]
            rhsPtr -= 1
            totalPtr -= 1
        }
    }
}
