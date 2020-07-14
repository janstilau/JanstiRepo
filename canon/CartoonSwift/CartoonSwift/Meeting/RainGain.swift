
//
//  RainGain.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/12.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given n non-negative integers representing an elevation map where the width of each bar is 1, compute how much water it is able to trap after raining.


 The above elevation map is represented by array [0,1,0,2,1,0,1,3,2,1,2,1]. In this case, 6 units of rain water (blue section) are being trapped. Thanks Marcos for contributing this image!

 Example:

 Input: [0,1,0,2,1,0,1,3,2,1,2,1]
 Output: 6
 */

class TrapRains {
    func trap(_ height: [Int]) -> Int {
        return 1
    }
}


class Pow {
    func myPow(_ x: Double, _ n: Int) -> Double {
        if x.isZero && n < 0 {
            return 0.0
        }
        let absN = n>0 ? n: -n;
        var result = powInRecursive(x, absN)
        if n < 0 {
            result = 1/result
        }
        return result
    }
    func powInRecursive(_ num: Double, _ n: Int) -> Double {
        if n == 0 {
            return 1.0
        } else if n == 1 {
            return num
        }
        
        var result = 1.0
        let halfResult = powInRecursive(num, n >> 1)
        result = halfResult * halfResult
        if n & 0x01 == 1 {
            result *= num
        }
        return result
    }
}

class PrintNum {
    func printNumbers(_ n: Int) -> [Int] {
        var limit = 1
        for _ in 1...n {
            limit *= 10
        }
        var result = [Int]()
        result.reserveCapacity(limit)
        for aNum in 1..<limit {
            result.append(aNum)
        }
        return result
    }
}

class DeleteNode {
    func deleteNode(_ head: ListNode?, _ val: Int) -> ListNode? {
        guard let head = head else {
            return nil
        }
        if head.val == val {
            return head.next
        }
        var preNode: ListNode? = head
        while let nextNode = preNode?.next, nextNode.val != val{
            preNode = preNode?.next
        }
        if preNode?.next?.val == val {
            preNode?.next = preNode?.next?.next
        }
        return head
    }
    
    func deleteRepeatedNode(_ head: ListNode?) -> ListNode? {
        guard let head = head else {
            return nil
        }
        var valStash = Set<Int>()
        var current = head
        valStash.insert(current.val)
        while let nextNode = current.next {
            if valStash.contains(nextNode.val) {
                current.next = nextNode.next
            } else {
                valStash.insert(nextNode.val)
                current = nextNode
            }
        }
        return head
    }
}


class OddEvenReSort {
    /*
     输入一个整数数组，实现一个函数来调整该数组中数字的顺序，使得所有奇数位于数组的前半部分，所有偶数位于数组的后半部分。
     示例：
     输入：nums = [1,2,3,4]
     输出：[1,3,2,4]
     注：[3,1,2,4] 也是正确的答案之一。
     */
    func exchange(_ nums: [Int]) -> [Int] {
        guard !nums.isEmpty else {
            return nums
        }
        var result = nums
        var left = 0
        var right = nums.count - 1
        while left < right {
            while nums[left] & 0x01 == 1 && left < right {
                left += 1
            }
            while nums[right] & 0x01 == 0 && left < right {
                right -= 1
            }
            let temp = nums[left]
            result[left] = nums[right]
            result[right] = temp
            left += 1
            right -= 1
        }
        return result
    }
}


class CollectWater {
    func trap(_ height: [Int]) -> Int {
        var result = 0
        var level = 0
        while true {
            var left = 0
            var right = 0
            var leftFound = false
            var solidNum = 0
            for i in 0..<height.count {
                if height[i] - level > 0  {
                    if !leftFound {
                        left = i
                        leftFound = true
                    } else {
                        if height[i-1] - level > 0 {
                            left = i
                        } else {
                            right = i
                            result += right - left - 1
                            left = right
                        }
                    }
                    solidNum += 1
                }
            }
            level += 1
            if solidNum <= 1 { break }
        }
        return result
    }
}


class WaterContainer {
    func maxArea(_ height: [Int]) -> Int {
        var result = 0
        var left = 0
        var right = height.count - 1
        
        while left < right {
            let currentArea = (right-left) * min(height[left], height[right])
            if currentArea > result {
                result = currentArea
            }
            if height[left] < height[right] {
                left += 1
            } else {
                right -= 1
            }
        }
        return result
    }
}
