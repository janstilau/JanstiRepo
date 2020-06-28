//
//  TriangleRelated.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/28.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given a non-negative integer numRows, generate the first numRows of Pascal's triangle.


 In Pascal's triangle, each number is the sum of the two numbers directly above it.

 Example:

 Input: 5
 Output:
 [
      [1],
     [1,1],
    [1,2,1],
   [1,3,3,1],
  [1,4,6,4,1]
 ]
 */


/*
 Given a non-negative index k where k ≤ 33, return the kth index row of the Pascal's triangle.

 Note that the row index starts from 0.


 In Pascal's triangle, each number is the sum of the two numbers directly above it.

 Example:

 Input: 3
 Output: [1,3,3,1]
 Follow up:

 Could you optimize your algorithm to use only O(k) extra space?
 */


class Triangle {
    static func generate(_ numRows: Int) -> [[Int]] {
        var result: [[Int]] = [[Int]]()
        if numRows == 0 { return result }
        if numRows == 1 {
            result.append([1])
            return result
        }
        result.append([1])
        var preLine = [1]
        for idx in 2...numRows {
            var lineResult = [Int]()
            lineResult.reserveCapacity(idx)
            lineResult.append(1)
            for innerIdx in 1..<idx-1 {
                lineResult.append(preLine[innerIdx] + preLine[innerIdx-1])
            }
            lineResult.append(1)
            result.append(lineResult)
            preLine = lineResult
        }
        return result
    }
    
    static func getRowUsingGenerate(_ rowIndex: Int) -> [Int] {
        let values = generate(rowIndex+1)
        return values[rowIndex]
    }
    
    static func getRow(_ rowIndex: Int) -> [Int] {
        /*
         最简单的方法, 当然是利用 generate 这个方法, 获取所有的数组, 然后得到相应位置的数组就可以了
         题目提到了 O(k) 的空间复杂度, 就是让你将生成过程, 用算法模拟出来.
         */
        if (rowIndex == 0) { return [1] }
        if (rowIndex == 1) { return [1, 1] }
        let capacity = rowIndex+1
        var result = [Int](repeating: 1, count: capacity)
        var cache = result
        for rowIdx in 2...rowIndex {
            for columnIdx in 1..<rowIdx {
                result[columnIdx] = cache[columnIdx] + cache[columnIdx-1]
            }
            cache = result
        }
        return result
    }
}

