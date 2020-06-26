//
//  MergeArray.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/26.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation
/*
 Given a collection of intervals, merge all overlapping intervals.

 Example 1:

 Input: [[1,3],[2,6],[8,10],[15,18]]
 Output: [[1,6],[8,10],[15,18]]
 Explanation: Since intervals [1,3] and [2,6] overlaps, merge them into [1,6].
 Example 2:

 Input: [[1,4],[4,5]]
 Output: [[1,5]]
 Explanation: Intervals [1,4] and [4,5] are considered overlapping.
 NOTE: input types have been changed on April 15, 2019. Please reset to default code definition to get new method signature.
 */

/*
 这道题没有解出来. 之前做过一个 id 生成器的, 实现的是 indexSet 的逻辑.
 这种问题, 首先应该是排序, 排序之后, 遍历操作的时候, 就可以有序的考虑问题.
 
 */


class MergeArray {
    struct MergePoint {
        var left: Int
        var right: Int
    }
    func merge(_ intervals: [[Int]]) -> [[Int]] {
        if intervals.isEmpty { return [] }
        var points = intervals.map { (point) -> MergePoint in
            let left = point.first!
            let right = point.last!
            return MergePoint(left: left, right: right)
        }
        points.sort { (lhs, rhs) -> Bool in
            return lhs.left < rhs.left
        }
        
        var result: [MergePoint] = []
        result.append(points.first!)
        for aPoint in points {
            var endPoint = result.last!
            if aPoint.left > endPoint.right {
                result.append(aPoint)
            } else {
                if aPoint.right > endPoint.right {
                    endPoint.right = aPoint.right
                    result[result.count-1] = endPoint
                }
            }
        }
        return result.map { (point)  in
            return [point.left, point.right]
        }
    }
}


/*
 
 题解:
 
 如果我们按照区间的左端点排序，那么在排完序的列表中，可以合并的区间一定是连续的。如下图所示，标记为蓝色、黄色和绿色的区间分别可以合并成一个大区间，它们在排完序的列表中是连续的：

 算法

 我们用数组 merged 存储最终的答案。

 首先，我们将列表中的区间按照左端点升序排序。然后我们将第一个区间加入 merged 数组中，并按顺序依次考虑之后的每个区间：

 如果当前区间的左端点在数组 merged 中最后一个区间的右端点之后，那么它们不会重合，我们可以直接将这个区间加入数组 merged 的末尾；

 否则，它们重合，我们需要用当前区间的右端点更新数组 merged 中最后一个区间的右端点，将其置为二者的较大值。

 作者：LeetCode-Solution
 链接：https://leetcode-cn.com/problems/merge-intervals/solution/he-bing-qu-jian-by-leetcode-solution/
 来源：力扣（LeetCode）
 著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。
 */
