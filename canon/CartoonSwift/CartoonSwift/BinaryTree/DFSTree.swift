//
//  TreeNode.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/9.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given a binary tree, return the preorder traversal of its nodes' values.

 Example:

 Input: [1,null,2,3]
    1
     \
      2
     /
    3

 Output: [1,2,3]
 Follow up: Recursive solution is trivial, could you do it iteratively?
 */

class PreOrder {
    func preorderTraversal(_ root: TreeNode?) -> [Int] {
        guard let root = root else {
            return [Int]()
        }
        var result = [Int]()
        var stack = [TreeNode]()
        stack.append(root)
        while !stack.isEmpty {
            let topNode = stack.removeLast() // 访问节点
            result.append(topNode.val)
            if let rightNode = topNode.right {
                stack.append(rightNode) // 添加节点到栈中, 不访问
            }
            if let leftNode = topNode.left {
                stack.append(leftNode) // 添加节点到栈中, 不访问
            }
        }
        return result
    }
    
    func preorderRecursive(_ root: TreeNode?, nums: inout [Int]) {
        guard let root = root else {
            return
        }
        nums.append(root.val)
        preorderRecursive(root.left, nums: &nums)
        preorderRecursive(root.right, nums: &nums)
    }
}

/*
 Given a binary tree, return the inorder traversal of its nodes' values.

 Example:

 Input: [1,null,2,3]
    1
     \
      2
     /
    3

 Output: [1,3,2]
 Follow up: Recursive solution is trivial, could you do it iteratively?
 */

/*
 栈的结构, 入栈不算访问数据, 出栈才算访问数据.
 所以, 用循环模拟递归的过程, 就是不断的控制入栈的顺序的过程.
 最晚进行访问的, 最先进行入栈的操作.
 */

class Inorder {
    func inorderTraversal(_ root: TreeNode?) -> [Int] {
//        var nums = [Int]()
//        inorderRecursive(root, nums: &nums)
//        return nums
        
        var result = [Int]()
        var stack = [TreeNode]()
        var current = root
        while current != nil || !stack.isEmpty {
            if current != nil {
                stack.append(current!) // 添加节点, 此时节点有可能是左节点, 也有可能是右节点.
                current = current?.left
                continue
            }
            let topNode = stack.removeLast() // 访问节点
            result.append(topNode.val)
            current = topNode.right
        }
        return result
    }
    
    func inorderRecursive(_ root: TreeNode?, nums: inout [Int]) {
        guard let root = root else {
            return
        }
        inorderRecursive(root.left, nums: &nums)
        nums.append(root.val)
        inorderRecursive(root.right, nums: &nums)
    }
}


class PostOrder {
    func postorderTraversal(_ root: TreeNode?) -> [Int] {
        var result = [Int]()
        postoderRecursive(root, nums: &result)
        return result
    }
    
    func postoderRecursive(_ root: TreeNode?, nums: inout [Int]) {
        guard let root = root else {
            return
        }
        postoderRecursive(root.left, nums: &nums)
        postoderRecursive(root.right, nums: &nums)
        nums.append(root.val)
    }
}

class MajorityElementS {
    func majorityElement(_ nums: [Int]) -> Int {
        var counter = [Int: Int]()
        for aNum in nums {
            if let numCount = counter[aNum] {
                let addedCount = numCount + 1
                counter[aNum] = addedCount
                if addedCount > nums.count/2 {
                    return aNum
                }
            } else {
                counter[aNum] = 1
            }
        }
        return -1
    }
}

class GetLeastNumbers {
    func getLeastNumbers(_ arr: [Int], _ k: Int) -> [Int] {
        guard k > 0 else {
            return [Int]()
        }
        guard arr.count > k else {
            return arr
        }
        var heap: [Int] = [Int](repeating: Int.max, count: k+1)
        var insertedCount = 0
        for aNum in arr {
            
            if insertedCount < k {
                insertedCount += 1
                heap[insertedCount] = aNum
                var idx = insertedCount
                while heap[idx/2] < heap[idx] && idx > 1{
                    let temp = heap[idx]
                    heap[idx] = heap[idx/2]
                    heap[idx/2] = temp
                    idx = idx/2
                }
            } else if aNum <= heap[1] {
                heap[1] = aNum
                var idx = 1
                while idx*2+1 <= k {
                    if heap[idx*2] <= heap[idx] && heap[idx*2+1] <= heap[idx] { break }
                    var target = idx * 2
                    if heap[idx*2+1] > heap[idx*2] {
                        target = idx * 2 + 1
                    }
                    let temp = heap[idx]
                    heap[idx] = heap[target]
                    heap[target] = temp
                    idx = target
                }
            }
        }
        return Array(heap[1...k])
    }
}



class MedianFinder {

    var maxHeap: [Int] // 左边
    var minHeap: [Int] // 右边
    var totalCount: Int = 0
    
    init() {
        minHeap = [Int]()
        minHeap.append(0)
        
        maxHeap = [Int]()
        maxHeap.append(0)
    }
    
    func insertHeap(heap: inout [Int], num: Int, compare: (Int, Int) -> Bool) {
        heap.append(num)
        var idx = heap.count - 1
        while idx > 1 {
            if (compare(heap[idx], heap[idx/2])) {
                let temp = heap[idx]
                heap[idx] = heap[idx/2]
                heap[idx/2] = temp
                idx /= 2
            } else {
                break
            }
        }
    }
    
    func removeHeap(heap: inout [Int], compare: (Int, Int) -> Bool) -> Int{
        guard heap.count >= 1 else {
            return -1
        }
        let result = heap[1]
        heap[1] = heap[heap.count-1]
        heap.removeLast()
        var idx = 1
        while idx*2 < heap.count {
            let leftIdx = idx*2
            let rightIdx = idx*2 + 1
            var targetIdx = idx
            if leftIdx < heap.count && compare(heap[leftIdx], heap[idx]) {
                targetIdx = leftIdx
            }
            if rightIdx < heap.count && compare(heap[rightIdx], heap[idx]) && compare(heap[rightIdx], heap[leftIdx]) {
                targetIdx = rightIdx
            }
            if targetIdx == idx { break }
            let temp = heap[targetIdx]
            heap[targetIdx] = heap[idx]
            heap[idx] = temp
            idx = targetIdx
        }
        return result
    }
    
    func addNum(_ num: Int) {
        totalCount += 1
        if maxHeap.count <= 1 {
            insertHeap(heap: &maxHeap, num: num, compare: >)
            balanceHeap()
            return
        }
        if minHeap.count <= 1 {
            insertHeap(heap: &maxHeap, num: num, compare: >)
            balanceHeap()
            return
        }
        if num > minHeap[1] {
            let rightMin = removeHeap(heap: &minHeap, compare: <)
            insertHeap(heap: &maxHeap, num: rightMin, compare: >)
            insertHeap(heap: &minHeap, num: num, compare: <)
            balanceHeap()
        } else {
            insertHeap(heap: &maxHeap, num: num, compare: >)
            balanceHeap()
        }
    }
    
    func balanceHeap() {
        while minHeap.count > maxHeap.count{
            let rightMin = removeHeap(heap: &minHeap, compare: <)
            insertHeap(heap: &maxHeap, num: rightMin, compare: >)
        }
        while maxHeap.count - minHeap.count > 1 {
            let leftMax = removeHeap(heap: &maxHeap, compare: >)
            insertHeap(heap: &minHeap, num: leftMax, compare: <)
        }
    }
    
    func findMedian() -> Double {
        if maxHeap.count > minHeap.count {
            return (Double)(maxHeap[1])
        } else {
            return (Double)(minHeap[1]+maxHeap[1]) / 2
        }
    }
}
