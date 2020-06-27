//
//  ZeroMatrix.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/27.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Write an algorithm such that if an element in an MxN matrix is 0, its entire row and column are set to 0.

  

 Example 1:

 Input:
 [
   [1,1,1],
   [1,0,1],
   [1,1,1]
 ]
 Output:
 [
   [1,0,1],
   [0,0,0],
   [1,0,1]
 ]
 Example 2:

 Input:
 [
   [0,1,2,0],
   [3,4,5,2],
   [1,3,1,5]
 ]
 Output:
 [
   [0,0,0,0],
   [0,4,5,0],
   [0,3,1,0]
 ]
 */

class ZeroMatrix {
    func setZeroes(_ matrix: inout [[Int]]) {
        if matrix.isEmpty { return }
        var rowZeroSet = Set<Int>()
        var columnZeroSet = Set<Int>()
        for (rowIdx, aRow) in matrix.enumerated() {
            for (columnIdx, aNum) in aRow.enumerated() {
                if aNum == 0 {
                    rowZeroSet.insert(rowIdx)
                    columnZeroSet.insert(columnIdx)
                }
            }
        }
        
        let rowCount = matrix.count
        let columnCount = matrix.first!.count
        
        for rowIdx in 0..<rowCount {
            if !rowZeroSet.contains(rowIdx) { continue }
            for columnIdx in 0..<columnCount {
                matrix[rowIdx][columnIdx] = 0
            }
        }
        
        for columnIdx in 0..<columnCount {
            if !columnZeroSet.contains(columnIdx) { continue }
            for rowIdx in 0..<rowCount {
                matrix[rowIdx][columnIdx] = 0
            }
        }
    }
}
