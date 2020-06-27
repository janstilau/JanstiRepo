//
//  DiagonalMatrix.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/27.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given a matrix of M x N elements (M rows, N columns), return all elements of the matrix in diagonal order as shown in the below image.

  

 Example:

 Input:
 [
  [ 1, 2, 3 ],
  [ 4, 5, 6 ],
  [ 7, 8, 9 ]
 ]

 Output:  [1,2,4,7,5,3,6,8,9]

 Explanation:

  

 Note:

 The total number of elements of the given matrix will not exceed 10,000.
 */

class DiagonalMatrix {
    struct SegmentMeta {
        var startIdx: Int
        var length: Int
    }
    static func findDiagonalOrder(_ matrix: [[Int]]) -> [Int] {
        return []
//        guard !matrix.isEmpty else {
//            return []
//        }
//        guard !matrix.first!.isEmpty else {
//            return []
//        }
//        let rowCount = matrix.count
//        let columnCount = matrix.first!.count
//
//        var segmentMap = [Int: SegmentMeta]()
//
//        for rowIdx in 0..<rowCount {
//            for columnIdx in 0..<columnCount {
//                let segmentIdx = rowIdx + columnIdx
//                if segmentMap.keys.contains(segmentIdx) {
//                    segmentMap[segmentIdx]!.length += 1
//                } else {
//                    segmentMap[segmentIdx] = SegmentMeta(startIdx: -1, length: 1)
//                }
//            }
//        }
//
//        var startIdx = 0
//        for aSegmentIdx in segmentMap.keys.sorted() {
//            segmentMap[aSegmentIdx]!.startIdx = startIdx
//            startIdx += segmentMap[aSegmentIdx]!.length
//        }
//
//        var result = Array<Int>(repeating: -1, count: rowCount * columnCount)
//        for (key, value) in segmentMap {
//            if key % 2 == 0{
//                if key > columnCount || key > rowCount {
//
//                } else {
//                    var row = key
//                    var column = 0
//                    for rowIdx in (0...key).reversed() {
//                    }
//                }
//            } else {
//            }
//        }
//        return result
//    }
    }
}
