//
//  RebuldTree.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/1.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation
/*
 二叉树的前序遍历顺序是：根节点、左子树、右子树，每个子树的遍历顺序同样满足前序遍历顺序。

 二叉树的中序遍历顺序是：左子树、根节点、右子树，每个子树的遍历顺序同样满足中序遍历顺序。

 前序遍历的第一个节点是根节点，只要找到根节点在中序遍历中的位置，在根节点之前被访问的节点都位于左子树，在根节点之后被访问的节点都位于右子树，由此可知左子树和右子树分别有多少个节点。

 由于树中的节点数量与遍历方式无关，通过中序遍历得知左子树和右子树的节点数量之后，可以根据节点数量得到前序遍历中的左子树和右子树的分界，因此可以进一步得到左子树和右子树各自的前序遍历和中序遍历，可以通过递归的方式，重建左子树和右子树，然后重建整个二叉树。

 使用一个 Map 存储中序遍历的每个元素及其对应的下标，目的是为了快速获得一个元素在中序遍历中的位置。调用递归方法，对于前序遍历和中序遍历，下标范围都是从 0 到 n-1，其中 n 是二叉树节点个数。

 递归方法的基准情形有两个：判断前序遍历的下标范围的开始和结束，若开始大于结束，则当前的二叉树中没有节点，返回空值 null。若开始等于结束，则当前的二叉树中恰好有一个节点，根据节点值创建该节点作为根节点并返回。

 若开始小于结束，则当前的二叉树中有多个节点。在中序遍历中得到根节点的位置，从而得到左子树和右子树各自的下标范围和节点数量，知道节点数量后，在前序遍历中即可得到左子树和右子树各自的下标范围，然后递归重建左子树和右子树，并将左右子树的根节点分别作为当前根节点的左右子节点。

 Java

 /**
  * Definition for a binary tree node.
  * public class TreeNode {
  *     int val;
  *     TreeNode left;
  *     TreeNode right;
  *     TreeNode(int x) { val = x; }
  * }
  */
 class Solution {
     public TreeNode buildTree(int[] preorder, int[] inorder) {
         if (preorder == null || preorder.length == 0) {
             return null;
         }
         Map<Integer, Integer> indexMap = new HashMap<Integer, Integer>();
         int length = preorder.length;
         for (int i = 0; i < length; i++) {
             indexMap.put(inorder[i], i);
         }
         TreeNode root = buildTree(preorder, 0, length - 1, inorder, 0, length - 1, indexMap);
         return root;
     }

     public TreeNode buildTree(int[] preorder, int preorderStart, int preorderEnd, int[] inorder, int inorderStart, int inorderEnd, Map<Integer, Integer> indexMap) {
         if (preorderStart > preorderEnd) {
             return null;
         }
         int rootVal = preorder[preorderStart];
         TreeNode root = new TreeNode(rootVal);
         if (preorderStart == preorderEnd) {
             return root;
         } else {
             int rootIndex = indexMap.get(rootVal);
             int leftNodes = rootIndex - inorderStart, rightNodes = inorderEnd - rootIndex;
             TreeNode leftSubtree = buildTree(preorder, preorderStart + 1, preorderStart + leftNodes, inorder, inorderStart, rootIndex - 1, indexMap);
             TreeNode rightSubtree = buildTree(preorder, preorderEnd - rightNodes + 1, preorderEnd, inorder, rootIndex + 1, inorderEnd, indexMap);
             root.left = leftSubtree;
             root.right = rightSubtree;
             return root;
         }
     }
 }
 复杂度分析

 时间复杂度：O(n)O(n)。对于每个节点都有创建过程以及根据左右子树重建过程。
 空间复杂度：O(n)O(n)。存储整棵树的开销。

 作者：LeetCode-Solution
 链接：https://leetcode-cn.com/problems/zhong-jian-er-cha-shu-lcof/solution/mian-shi-ti-07-zhong-jian-er-cha-shu-by-leetcode-s/
 来源：力扣（LeetCode）
 著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。
 */
class RebuildTree {
    
    /*
     使用下面的Range的方法, 反而让代码变得复杂.
     */
    func makeNode(preorder: [Int], preRange:ClosedRange<Int>, inorder: [Int], inRange:ClosedRange<Int>) -> TreeNode?{
        let rootNode = TreeNode(preorder[preRange.lowerBound])
        if preRange.count == 1 { return rootNode }
        let rootValue = preorder[preRange.lowerBound]
        var leftLength = 0
        var rightLength = 0
        var foundRoot = false
        
        for aIdx in inRange {
            if inorder[aIdx] == rootValue {
                foundRoot = true
                continue
            }
            if !foundRoot {
                leftLength += 1
            } else {
                rightLength += 1
            }
        }
        
        if leftLength > 0 {
            let leftPreRange = preRange.lowerBound+1...preRange.lowerBound+leftLength
            let leftInRange = inRange.lowerBound...inRange.lowerBound+leftLength-1
            rootNode.left = makeNode(preorder: preorder, preRange: leftPreRange, inorder: inorder, inRange: leftInRange)
        }
        if rightLength > 0 {
            let rightPreRange = preRange.upperBound-rightLength+1...preRange.upperBound
            let rightInRange = inRange.upperBound-rightLength+1...inRange.upperBound
            rootNode.right = makeNode(preorder: preorder, preRange: rightPreRange, inorder: inorder, inRange: rightInRange)
        }
        return rootNode
    }
    
    func buildTree(_ preorder: [Int], _ inorder: [Int]) -> TreeNode? {
        guard !preorder.isEmpty else {
            return nil
        }
        guard !inorder.isEmpty else {
            return nil
        }
        let nodeCount = preorder.count
        let left = 0
        let right = nodeCount-1
        
        return makeNode(preorder: preorder, preRange: left...right, inorder: inorder, inRange: left...right)
    }
}
