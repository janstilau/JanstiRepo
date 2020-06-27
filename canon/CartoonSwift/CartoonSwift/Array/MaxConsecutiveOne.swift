//
//  MaxConsecutiveOne.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/27.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given a binary array, find the maximum number of consecutive 1s in this array.

 Example 1:
 Input: [1,1,0,1,1,1]
 Output: 3
 Explanation: The first two digits or the last three digits are consecutive 1s.
     The maximum number of consecutive 1s is 3.
 Note:

 The input array will only contain 0 and 1.
 The length of input array is a positive integer and will not exceed 10,000
 */

class MaxConsecutiveOne {
    static func findMaxConsecutiveOnes(_ nums: [Int]) -> Int {
        var iteratingOne = false
        var maxLength = 0
        var currentLength = 0
        for aNum in nums {
            if aNum == 0 {
                if  iteratingOne,
                    currentLength > maxLength{
                    maxLength = currentLength
                }
                currentLength = 0
                iteratingOne = false
            } else {
                currentLength += 1
                iteratingOne = true
            }
        }
        if  iteratingOne,
            currentLength > maxLength{
            maxLength = currentLength
        }
        return maxLength
    }
}

/*
 下面的思路, 更加能够体现, 双指针的用途.
 
 滑动窗口思路：
 当输出或比较的结果在原数据结构中是连续排列的时候，可以使用滑动窗口算法求解。
 将两个指针比作一个窗口，通过移动指针的位置改变窗口的大小，观察窗口中的元素是否符合题意。

 初始窗口中只有数组开头一个元素。
 当窗口中所有元素为 1 时，右指针向右移，扩大窗口。
 当窗口中存在 0 时，计算连续序列长度，左指针指向右指针。
 
 class Solution {
     public int findMaxConsecutiveOnes(int[] nums) {
         int length = nums.length;
         int left = 0;
         int right = 0;
         int maxSize = 0;
         
         while(right < length){
             //当窗口中所有元素为 1 时，右指针向右移，扩大窗口。
             if (nums[right++] == 0){
                 //当窗口中存在 0 时，计算连续序列长度，左指针指向右指针。
                 maxSize = Math.max(maxSize, right - left - 1);
                 left = right;
             }
         }
         // 因为最后一次连续序列在循环中无法比较，所以在循环外进行比较
         return Math.max(maxSize, right - left);
     }
 }

 作者：lxiaocode
 链接：https://leetcode-cn.com/problems/max-consecutive-ones/solution/java-485-zui-da-lian-xu-1de-ge-shu-hua-dong-chuang/
 来源：力扣（LeetCode）
 著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。
 */
