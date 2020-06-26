//
//  ReversePolish.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/25.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation
/*
 Evaluate the value of an arithmetic expression in Reverse Polish Notation.

 Valid operators are +, -, *, /. Each operand may be an integer or another expression.

 Note:

 Division between two integers should truncate toward zero.
 The given RPN expression is always valid. That means the expression would always evaluate to a result and there won't be any divide by zero operation.
 Example 1:

 Input: ["2", "1", "+", "3", "*"]
 Output: 9
 Explanation: ((2 + 1) * 3) = 9
 Example 2:

 Input: ["4", "13", "5", "/", "+"]
 Output: 6
 Explanation: (4 + (13 / 5)) = 6
 Example 3:

 Input: ["10", "6", "9", "3", "+", "-11", "*", "/", "*", "17", "+", "5", "+"]
 Output: 22
 Explanation:
   ((10 * (6 / ((9 + 3) * -11))) + 17) + 5
 = ((10 * (6 / (12 * -11))) + 17) + 5
 = ((10 * (6 / -132)) + 17) + 5
 = ((10 * 0) + 17) + 5
 = (0 + 17) + 5
 = 17 + 5
 = 22
 */


class ReversePolish {
    var numDatas = [Int]()
    var result = 0
    func isOperator(text: String) -> Bool {
        if text == "+" || text == "-" || text == "*" || text == "/" {
            return true
        } else {
            return false
        }
    }
    func evalRPN(_ tokens: [String]) -> Int {
        for aText in tokens {
            if isOperator(text: aText) {
                let rhs = numDatas.popLast()!
                let lhs = numDatas.popLast()!
                switch aText {
                case "+":
                    let added = lhs + rhs
                    numDatas.append(added)
                case "-":
                    let minused = lhs - rhs
                    numDatas.append(minused)
                case "*":
                    let multied = lhs * rhs
                    numDatas.append(multied)
                case "/":
                    let divided = lhs / rhs
                    numDatas.append(divided)
                default:
                    break
                }
            } else {
                numDatas.append(Int(aText)!)
            }
        }
        return numDatas.last!
    }
}
