//
//  RotateMatrix.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/26.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given an image represented by an N x N matrix, where each pixel in the image is 4 bytes, write a method to rotate the image by 90 degrees. Can you do this in place?

  

 Example 1:

 Given matrix =
 [
   [1,2,3],
   [4,5,6],
   [7,8,9]
 ],

 Rotate the matrix in place. It becomes:
 [
   [7,4,1],
   [8,5,2],
   [9,6,3]
 ]
 Example 2:

 Given matrix =
 [
   [ 5, 1, 9,11],
   [ 2, 4, 8,10],
   [13, 3, 6, 7],
   [15,14,12,16]
 ],

 Rotate the matrix in place. It becomes:
 [
   [15,13, 2, 5],
   [14, 3, 4, 1],
   [12, 6, 8, 9],
   [16, 7,10,11]
 ]
 */
/*
 这道题思路并不难, 但是寻找四个位置原始位置和对应位置的关系, 花费了不少时间. 并且, 遍历的开始和结束位置, 也花费了不少时间才理清.
 */

class RotateMatrix {
    static func rotate(_ matrix: inout [[Int]]) {
        guard !matrix.isEmpty else {
            return
        }
        let rowCount = matrix.count
        let columnCount = matrix.first!.count
        guard rowCount == columnCount else {
            return
        }
        let sizeCount = rowCount
        
        let midIdx = (rowCount-1) / 2
        var columnEnd = sizeCount-1
        let rowEnd = midIdx
        var columnStart = 0
        for row in 0...rowEnd {
            columnStart = row
            columnEnd -= 1
            if columnStart > columnEnd { break }
            for column in columnStart...columnEnd {
                var stashValue = matrix[row][column]
                var temp = -1
                
                let leftTopTargetRow = column
                let leftTopTargetColumn = sizeCount-row-1
                temp = matrix[leftTopTargetRow][leftTopTargetColumn]
                matrix[leftTopTargetRow][leftTopTargetColumn] = stashValue
                stashValue = temp
                
                let rightTopTargetRow = leftTopTargetColumn
                let rightTopTargetColumn = sizeCount-leftTopTargetRow-1
                temp = matrix[rightTopTargetRow][rightTopTargetColumn]
                matrix[rightTopTargetRow][rightTopTargetColumn] = stashValue
                stashValue = temp
                
                let rightBottomTargetRow = rightTopTargetColumn
                let rightBottomTargetColumn =  sizeCount-rightTopTargetRow-1
                temp = matrix[rightBottomTargetRow][rightBottomTargetColumn]
                matrix[rightBottomTargetRow][rightBottomTargetColumn] = stashValue
                stashValue = temp
                
                let leftBottomTargetRow = rightBottomTargetColumn
                let leftBottomTargetColumn = sizeCount-rightBottomTargetRow-1
                temp = matrix[leftBottomTargetRow][leftBottomTargetColumn]
                matrix[leftBottomTargetRow][leftBottomTargetColumn] = stashValue
                stashValue = temp
            }
        }
    }
}
