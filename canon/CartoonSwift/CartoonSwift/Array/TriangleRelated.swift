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
}
