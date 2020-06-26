//
//  DailyTemperature.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/25.
//  Copyright © 2020 JustinLau. All rights reserved.
//


/*
 Given a list of daily temperatures T, return a list such that, for each day in the input, tells you how many days you would have to wait until a warmer temperature. If there is no future day for which this is possible, put 0 instead.

 For example, given the list of temperatures T = [73, 74, 75, 71, 69, 72, 76, 73], your output should be [1, 1, 4, 2, 1, 1, 0, 0].

 Note: The length of temperatures will be in the range [1, 30000]. Each temperature will be an integer in the range [30, 100].
 */

import Foundation

class DailyTemperature {
    /*
     超时了, 最后提交了一个 4000 多个元素的数组.
     */
    static func dailyTemperatures_1(_ T: [Int]) -> [Int] {
        var result = [Int](repeating: 0, count: T.count)
        for (i, aNum) in T.enumerated() {
            for j in i+1..<T.count {
                if T[j] > aNum {
                    result[i] = j-i
                    break
                }
            }
        }
        return result
    }
    
    struct TemperatureNode {
        var value: Int
        var index: Int
    }
    
    static func dailyTemperatures(_ T: [Int]) -> [Int] {
        var result = [Int](repeating: 0, count: T.count)
        var stack = [TemperatureNode]()
        for (i, aNum) in T.enumerated() {
            if stack.isEmpty {
                stack.append(TemperatureNode(value: aNum, index: i))
                continue
            }
            while !stack.isEmpty && stack.last!.value < aNum {
                let topNode = stack.popLast()!
                result[topNode.index] = i - topNode.index
            }
            stack.append(TemperatureNode(value: aNum, index: i))
        }
        return result
    }
}




/*
 
 之前一直想过, 栈就是存放某个数据, 然后在合适的时候, 在拿出来取用.
 这个题目, 一个温度被放置到栈里面, 需要等到更大的温度进入的时候, 才可以被取出使用. 而温度更小的元素进入的时候, 这些更小的温度应该入栈. 这其实是和表达式求值那道题是一个场景.
 
 https://leetcode-cn.com/problems/daily-temperatures/solution/leetcode-tu-jie-739mei-ri-wen-du-by-misterbooo/
 C++ 网上的讲解视频
 class Solution {
 public:
     vector<int> dailyTemperatures(vector<int>& temperatures) {
         int n = temperatures.size();
         vector<int> res(n, 0);
         stack<int> st;
         for (int i = 0; i < temperatures.size(); ++i) {
             while (!st.empty() && temperatures[i] > temperatures[st.top()]) {
                 auto t = st.top(); st.pop();
                 res[t] = i - t;
             }
             st.push(i);
         }
         return res;
     }
 };

 作者：MisterBooo
 链接：https://leetcode-cn.com/problems/daily-temperatures/solution/leetcode-tu-jie-739mei-ri-wen-du-by-misterbooo/
 来源：力扣（LeetCode）
 著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。
 */
