//
//  InvertChars.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/27.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation
/*
 Write a function that reverses a string. The input string is given as an array of characters char[].

 Do not allocate extra space for another array, you must do this by modifying the input array in-place with O(1) extra memory.

 You may assume all the characters consist of printable ascii characters.

  

 Example 1:

 Input: ["h","e","l","l","o"]
 Output: ["o","l","l","e","h"]
 Example 2:

 Input: ["H","a","n","n","a","h"]
 Output: ["h","a","n","n","a","H"]
 */

class InvertChars {
    func reverseString(_ s: inout [Character]) {
        guard !s.isEmpty else {
            return
        }
        let count = s.count
        var leftPointer = 0
        var rightPointer = count-1
        while leftPointer < rightPointer {
            let temp = s[leftPointer]
            s[leftPointer] = s[rightPointer]
            s[rightPointer] = temp
            leftPointer += 1
            rightPointer -= 1
        }
    }
}

/*
 Given an array of 2n integers, your task is to group these integers into n pairs of integer, say (a1, b1), (a2, b2), ..., (an, bn) which makes sum of min(ai, bi) for all i from 1 to n as large as possible.

 Example 1:
 Input: [1,4,3,2]

 Output: 4
 Explanation: n is 2, and the maximum sum of pairs is 4 = min(1, 2) + min(3, 4).
 Note:
 n is a positive integer, which is in the range of [1, 10000].
 All the integers in the array will be in the range of [-10000, 10000].
 */

/*
 桶排序的解法
 
 这里, 还是利用空间排序而已. 然后, 一次加, 一次不加, 还是按照排序完以后, 取奇数偶数 index 的规则而已.
 
 public class Solution {
     public int arrayPairSum(int[] nums) {
         int[] arr = new int[20001];
         int lim = 10000;
         for (int num: nums)
             arr[num + lim]++;
         int d = 0, sum = 0;
         for (int i = -10000; i <= 10000; i++) {
             sum += (arr[i + lim] + 1 - d) / 2 * i;
             d = (2 + arr[i + lim] - d) % 2;
         }
         return sum;
     }
 }

 作者：LeetCode
 链接：https://leetcode-cn.com/problems/array-partition-i/solution/shu-zu-chai-fen-i-by-leetcode/
 来源：力扣（LeetCode）
 著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。

 作者：LeetCode
 链接：https://leetcode-cn.com/problems/array-partition-i/solution/shu-zu-chai-fen-i-by-leetcode/
 来源：力扣（LeetCode）
 著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。
 */

class SplitArray {
    static func arrayPairSum(_ nums: [Int]) -> Int {
        let sorted = nums.sorted()
        var result = 0
        for (idx, aNum) in sorted.enumerated() {
            if idx%2 == 0 {
                result += aNum
            }
        }
        return result
    }
}
