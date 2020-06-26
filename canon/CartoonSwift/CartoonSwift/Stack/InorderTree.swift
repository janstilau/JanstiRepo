//
//  InorderTree.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/26.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation


public class TreeNode {
  public var val: Int
  public var left: TreeNode?
  public var right: TreeNode?
  public init(_ val: Int) {
      self.val = val
      self.left = nil
      self.right = nil
  }
}

class InorderTree {
    func inorderTraversal(_ root: TreeNode?) -> [Int] {
        if root == nil { return [] }
        var stack = [TreeNode?]()
        var result = [Int]()
        var node = root
        while node != nil || !stack.isEmpty {
            if node != nil {
                stack.append(node)
                node = node!.left
            } else {
                node = stack.removeLast()
                if (node == nil) {
                    continue
                } else {
                    result.append(node!.val)
                    node = node?.right
                }
            }
        }
        return result
    }
}
