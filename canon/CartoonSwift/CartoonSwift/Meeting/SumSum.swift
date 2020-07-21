//
//  SumSum.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/19.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

class MaxSubArray {
    func maxSubArray(_ nums: [Int]) -> Int {
        guard !nums.isEmpty else {
            return 0
        }
        var sum = 0
        var right = 0
        var result = Int.min
        while right < nums.count {
            sum += nums[right]
            result = max(sum, result)
            if sum < 0 {
                sum = 0
            }
            right += 1
        }
        return result
    }
    
    

}

class CountDigitOne {
    func countDigitOne(_ num: Int) -> Int {
        var target = num
        if num < 0 {
            target = -num
        }
        
        var base = 1
        var exceed = false
        var result = 0
        while !exceed {
            let multipler = target / (base*10)
            if multipler == 0 { exceed = true }
            result += multipler * base
            result += (target/base%10 > 1) ? base : 0
            base *= 10
        }
        return result
    }
}

extension Int {
    func firstNum() -> Int {
        var target = self
        if target == 0 {
            return 0
        }
        if target < 0 {
            target = -target
        }
        var result = 0
        while target != 0 {
            result = target % 10
            target /= 10
        }
        return result
    }
    
    func digitNum() -> Int {
        var target = self
        if target == 0 {
            return 1
        }
        if target < 0 {
            target = -target
        }
        var result = 0
        while target != 0 {
            result += 1
            target /= 10
        }
        return result
    }
}

class MinNumber {
    
    class NumContainer {
        let numStart: Int
        var nums: [Int] = [Int]()
        init(start:Int) {
            numStart = start
        }
    }
    
    struct NumPair {
        let srcNum: Int
        let transfomredNum: Int
        init(src: Int, max: Int, firstNum: Int) {
            srcNum = src
            if src == max {
                transfomredNum = max * 10 + firstNum
            } else {
                var temp = src
                let highLimit = (Int)(pow((Double)(10), (Double)(max.digitNum())))
                while temp < highLimit {
                    temp = temp * 10 + firstNum
                }
                transfomredNum = temp
            }
        }
    }
    
    func minNumber(_ nums: [Int]) -> String {
        var result = [Int]()
        var numStash = [Int: NumContainer]()
        for aNum in nums {
            let firstNum = aNum.firstNum()
            
            if let numItem = numStash[firstNum] {
                numItem.nums.append(aNum)
                numStash[firstNum] = numItem
            } else {
                let insertNumItem = NumContainer(start: firstNum)
                insertNumItem.nums.append(aNum)
                numStash[firstNum] = insertNumItem
            }
        }
        for firstNum in numStash.keys.sorted() {
            let sameFirstNums = numStash[firstNum]!.nums
            let max = sameFirstNums.max()!
            var numPairs = sameFirstNums.map { (num) -> NumPair in
                return NumPair(src: num, max: max, firstNum: firstNum)
            }
            numPairs.sort { (lhs, rhs) -> Bool in
                if (lhs.transfomredNum == rhs.transfomredNum) {
                    let lhsFormer = "\(lhs.srcNum)\(rhs.srcNum)"
                    let rhsFormer = "\(rhs.srcNum)\(lhs.srcNum)"
                    return Int(lhsFormer)! < Int(rhsFormer)!
                } else {
                    return lhs.transfomredNum < rhs.transfomredNum
                }
            }
            for aNumPair in numPairs {
                result.append(aNumPair.srcNum)
            }
        }
        let resultText = getText(result)
        print(resultText)
        return resultText
    }
    
    func getText(_ nums: [Int]) -> String {
        var result = ""
        nums.forEach { (aNum) in
            let numTxt = String(aNum)
            result.append(contentsOf: numTxt)
        }
        return result
    }
}
