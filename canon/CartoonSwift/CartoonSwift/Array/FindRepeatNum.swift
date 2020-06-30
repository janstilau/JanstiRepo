//
//  FindRepeatNum.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/30.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation
/*
 找出数组中重复的数字。


 在一个长度为 n 的数组 nums 里的所有数字都在 0～n-1
 的范围内。数组中某些数字是重复的，但不知道有几个数字重复了，也不知道每个数字重复了几次。请找出数组中任意一个重复的数字。

 示例 1：

 输入：
 [2, 3, 1, 0, 2, 5, 3]
 输出：2 或 3
 */

class FindRepeatNum {
    func findRepeatNumberInSet(_ nums: [Int]) -> Int {
        guard !nums.isEmpty else {
            return -1
        }
        var numSet = Set<Int>()
        for aNum in nums {
            if numSet.contains(aNum) { return aNum }
            numSet.insert(aNum)
        }
        return -1
    }
}
