//
//  MoveZero.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/28.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given an array nums, write a function to move all 0's to the end of it while maintaining the relative order of the non-zero elements.

 Example:

 Input: [0,1,0,3,12]
 Output: [1,3,12,0,0]
 Note:

 You must do this in-place without making a copy of the array.
 Minimize the total number of operations.
 */

class MoveZero {
    static func moveZeroes(_ nums: inout [Int]) {
        var zeroCount = 0
        var numCount = 0
        for (idx, aNum ) in nums.enumerated() {
            if aNum == 0 {
                if numCount != 0 {
                    nums[(idx-numCount-zeroCount)...(idx-zeroCount-1)] = nums[(idx-numCount)...(idx-1)]
                }
                zeroCount += 1
                numCount = 0
            } else {
                numCount += 1
            }
        }
        if (numCount != 0) {
            let idx = nums.count
            nums[(idx-numCount-zeroCount)...(idx-zeroCount-1)] = nums[(idx-numCount)...(idx-1)]
        }
        for i in nums.count-zeroCount..<nums.count {
            nums[i] = 0
        }
    }
    
    /*
     感觉这道题想复杂了, 下面是网上别人的写法, 就是双指针的运用.
     */
    func moveZeroes(_ nums: inout [Int]) {
    
          var insertPos = 0
          
          for i in 0..<nums.count {
              if nums[i] != 0 {
                  nums[insertPos] = nums[i]
                  insertPos += 1
              }
          }
          
          for j in insertPos..<nums.count {
              nums[j] = 0
          }
      }
}
