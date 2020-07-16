//
//  PushPopStack.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/16.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation


class ValidateStackSequences {
    func validateStackSequences(_ pushed: [Int], _ popped: [Int]) -> Bool {
        if pushed.count != popped.count { return false }
        var popped = popped
        var pushIdx = 0
        var stack = [Int]()
        stack.reserveCapacity(pushed.count)
        
        while !popped.isEmpty {
            let topPopValue = popped.removeFirst()
            if stack.last == topPopValue {
                stack.removeLast()
            } else {
                if pushIdx >= pushed.count {
                    return false
                }
                while pushIdx < pushed.count {
                    if pushed[pushIdx] != topPopValue {
                        stack.append(pushed[pushIdx])
                        pushIdx += 1
                    } else {
                        pushIdx += 1
                        break
                    }
                }
            }
        }
        return true
    }
}


class LevelOrder {
    func levelOrder(_ root: TreeNode?) -> [Int] {
        guard let root = root else {
            return [Int]()
        }
        var result = [Int]()
        var queue = [TreeNode]()
        queue.append(root)
        while !queue.isEmpty {
            let headNode = queue.removeFirst()
            result.append(headNode.val)
            if let leftNode = headNode.left {
                queue.append(leftNode)
            }
            if let rightNode = headNode.right {
                queue.append(rightNode)
            }
        }
        return result
    }
}

class LevelOrderLevel {
    func levelOrder(_ root: TreeNode?) -> [[Int]] {
        guard let root = root else {
            return [[Int]]()
        }
        var result = [[Int]]()
        var queue = [[TreeNode]]()
        queue.append([root])
        while !queue.isEmpty {
            var headLevel = queue.removeFirst()
            var headResult = [Int]()
            var nextLevel = [TreeNode]()
            while !headLevel.isEmpty {
                let headNode = headLevel.removeFirst()
                headResult.append(headNode.val)
                if let leftNode = headNode.left {
                    nextLevel.append(leftNode)
                }
                if let rightNode = headNode.right {
                    nextLevel.append(rightNode)
                }
            }
            result.append(headResult)
            queue.append(nextLevel)
            if nextLevel.isEmpty { break }
        }
        return result
    }
}

class LevelOrderLevelLevel {
    func levelOrder(_ root: TreeNode?) -> [[Int]] {
        guard let root = root else {
            return [[Int]]()
        }
        var result = [[Int]]()
        var queue = [[TreeNode]]()
        queue.append([root])
        var flag = true
        while !queue.isEmpty {
            var headLevel = queue.removeFirst()
            var headResult = [Int]()
            var nextLevel = [TreeNode]()
            while !headLevel.isEmpty {
                let headNode = headLevel.removeFirst()
                if flag {
                    headResult.append(headNode.val)
                } else {
                    headResult.insert(headNode.val, at: 0)
                }
               
                if let leftNode = headNode.left {
                    nextLevel.append(leftNode)
                }
                if let rightNode = headNode.right {
                    nextLevel.append(rightNode)
                }
            }
            result.append(headResult)
            queue.append(nextLevel)
            flag = !flag
            if nextLevel.isEmpty { break }
        }
        return result
    }
}


class VerifyPostorder {
    func verifyPostorder(_ postorder: [Int]) -> Bool {
        return true
    }
}
