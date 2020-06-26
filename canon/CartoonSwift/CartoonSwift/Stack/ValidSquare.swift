//
//  ValidSquare.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/25.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
Given a string containing just the characters '(', ')', '{', '}', '[' and ']', determine if the input string is valid.

An input string is valid if:

Open brackets must be closed by the same type of brackets.
Open brackets must be closed in the correct order.
Note that an empty string is also considered valid.

Example 1:

Input: "()"
Output: true
Example 2:

Input: "()[]{}"
Output: true
Example 3:

Input: "(]"
Output: false
Example 4:

Input: "([)]"
Output: false
Example 5:

Input: "{[]}"
Output: true
 */

class ValidSquare {
    var leftSquares = [Character]()
    
    func isLeftSquare(char: Character) -> Bool {
        return char == "(" || char == "[" || char == "{"
    }
    func isRightSquare(char: Character) -> Bool {
        return char == ")" || char == "]" || char == "}"
    }
    func isValidRight(char: Character) -> Bool {
        if leftSquares.isEmpty { return false }
        if char == "}" {
            return leftSquares.last! == "{"
        } else if char == "]" {
            return leftSquares.last! == "["
        } else if char == ")" {
            return leftSquares.last! == "("
        } else {
            return false
        }
    }
    func isValid(_ s: String) -> Bool {
        leftSquares.removeAll()
        for aChar in s {
            if isLeftSquare(char: aChar) {
                leftSquares.append(aChar)
            } else if isRightSquare(char: aChar) {
                if isValidRight(char: aChar) {
                    leftSquares.removeLast()
                } else {
                    return false
                }
            }
        }
        return leftSquares.isEmpty
    }
}
