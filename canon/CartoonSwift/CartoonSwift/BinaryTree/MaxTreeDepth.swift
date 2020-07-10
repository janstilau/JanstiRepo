//
//  MaxDepth.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/10.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Given a binary tree, find its maximum depth.

 The maximum depth is the number of nodes along the longest path from the root node down to the farthest leaf node.

 Note: A leaf is a node with no children.

 Example:

 Given binary tree [3,9,20,null,null,15,7],

     3
    / \
   9  20
     /  \
    15   7
 return its depth = 3.
 */


class MaxTreeDepth {
    func maxDepth(_ root: TreeNode?) -> Int {
        guard let root = root else {
            return 0
        }
        let leftDepth = maxDepth(root.left)
        let rightDepth = maxDepth(root.right)
        return max(leftDepth, rightDepth) + 1
    }
}

/*
 Given a binary tree, check whether it is a mirror of itself (ie, symmetric around its center).

 For example, this binary tree [1,2,2,3,4,4,3] is symmetric:

     1
    / \
   2   2
  / \ / \
 3  4 4  3
  

 But the following [1,2,2,null,3,null,3] is not:

     1
    / \
   2   2
    \   \
    3    3
  

 Follow up: Solve it both recursively and iteratively.
 */

class IsSymmetricTree {
    func isSymmetric(_ root: TreeNode?) -> Bool {
        var queue = [TreeNode?]()
        queue.append(root)
        while !queue.isEmpty {
            var left = 0
            var right = queue.count-1
            while left <= right {
                if queue[left] != queue[right] { return false }
                left += 1
                right -= 1
            }
            var stash = [TreeNode?]()
            for aNode in queue {
                stash.append(aNode?.left)
                stash.append(aNode?.right)
            }
            if stash.allSatisfy({$0 == nil}) { return true }
            queue.removeAll()
            queue.append(contentsOf: stash)
        }
        return true
    }
}


/*
 Given a binary tree and a sum, determine if the tree has a root-to-leaf path such that adding up all the values along the path equals the given sum.

 Note: A leaf is a node with no children.

 Example:

 Given the below binary tree and sum = 22,

       5
      / \
     4   8
    /   / \
   11  13  4
  /  \      \
 7    2      1
 return true, as there exist a root-to-leaf path 5->4->11->2 which sum is 22.
 */

class HasPathSum {
    func hasPathSum(_ root: TreeNode?, _ sum: Int) -> Bool {
        guard let root = root else {
            return false
        }
        let remain = sum - root.val
        if remain == 0 && root.left == nil && root.right == nil {
            return true
        }
        let leftResult = hasPathSum(root.left, remain)
        let rightResult = hasPathSum(root.right, remain)
        return leftResult || rightResult
    }
}


class BuildTreeFromInPostOrder {
    
    func buildTreeInSegment(inorder: [Int], inLeft: Int, inRight: Int, postorder: [Int], postLeft: Int, postRight: Int) -> TreeNode? {
        if inLeft < 0 || inRight >= inorder.count || inLeft > inRight ||
            postLeft < 0 || postRight >= postorder.count || postLeft > postRight {
            return nil
        }
        let rootValue = postorder[postRight]
        let root = TreeNode(rootValue)
        let rootIndexInOrder = inorder.firstIndex(of: rootValue)!
        let leftTreeLength = rootIndexInOrder - inLeft
        let rightTreeLength = inRight - rootIndexInOrder
        root.left = buildTreeInSegment(inorder: inorder, inLeft: inLeft, inRight: rootIndexInOrder-1, postorder: postorder, postLeft: postLeft, postRight: postLeft + leftTreeLength - 1)
        root.right = buildTreeInSegment(inorder: inorder, inLeft: rootIndexInOrder + 1, inRight: inRight, postorder: postorder, postLeft: postRight - 1 - rightTreeLength + 1, postRight: postRight - 1)
        return root
    }
    
    func buildTree(_ inorder: [Int], _ postorder: [Int]) -> TreeNode? {
        return buildTreeInSegment(inorder: inorder, inLeft: 0, inRight: inorder.count-1, postorder: postorder, postLeft: 0, postRight: postorder.count-1)
    }
}


/*
 You are given a perfect binary tree where all leaves are on the same level, and every parent has two children. The binary tree has the following definition:

 struct Node {
   int val;
   Node *left;
   Node *right;
   Node *next;
 }
 Populate each next pointer to point to its next right node. If there is no next right node, the next pointer should be set to NULL.

 Initially, all next pointers are set to NULL.

  

 Follow up:

 You may only use constant extra space.
 Recursive approach is fine, you may assume implicit stack space does not count as extra space for this problem.
  

 Example 1:



 Input: root = [1,2,3,4,5,6,7]
 Output: [1,#,2,3,#,4,5,6,7,#]
 Explanation: Given the above perfect binary tree (Figure A), your function should populate each next pointer to point to its next right node, just like in Figure B. The serialized output is in level order as connected by the next pointers, with '#' signifying the end of each level.
  

 Constraints:

 The number of nodes in the given tree is less than 4096.
 -1000 <= node.val <= 1000
 */


/*
 Given a binary tree, find the lowest common ancestor (LCA) of two given nodes in the tree.

 According to the definition of LCA on Wikipedia: “The lowest common ancestor is defined between two nodes p and q as the lowest node in T that has both p and q as descendants (where we allow a node to be a descendant of itself).”

 Given the following binary tree:  root = [3,5,1,6,2,0,8,null,null,7,4]


  

 Example 1:

 Input: root = [3,5,1,6,2,0,8,null,null,7,4], p = 5, q = 1
 Output: 3
 Explanation: The LCA of nodes 5 and 1 is 3.
 Example 2:

 Input: root = [3,5,1,6,2,0,8,null,null,7,4], p = 5, q = 4
 Output: 5
 Explanation: The LCA of nodes 5 and 4 is 5, since a node can be a descendant of itself according to the LCA definition.
  

 Note:

 All of the nodes' values will be unique.
 p and q are different and both values will exist in the binary tree.
 */

/**
 * Definition for a binary tree node.
 * public class TreeNode {
 *     public var val: Int
 *     public var left: TreeNode?
 *     public var right: TreeNode?
 *     public init(_ val: Int) {
 *         self.val = val
 *         self.left = nil
 *         self.right = nil
 *     }
 * }
 */

class CommonAncestor {
    
    func fillPath(_ root: TreeNode, target: TreeNode, path: inout [TreeNode], flag: inout Bool) {
        path.append(root)
        if root.val == target.val {
            flag = true
            return
        }
        if let leftNode = root.left {
            fillPath(leftNode, target: target, path: &path, flag: &flag)
            if flag {
                return
            }
        }
        if let rightNode = root.right {
            fillPath(rightNode, target: target, path: &path, flag: &flag)
            if flag {
                return
            }
        }
        path.removeLast()
    }
    
    func pathForNode(_ root: TreeNode, target: TreeNode) -> [TreeNode] {
        var result = [TreeNode]()
        var flag = false
        fillPath(root, target: target, path: &result, flag: &flag)
        return result
    }
    
    func lowestCommonAncestor(_ root: TreeNode?, _ p: TreeNode?, _ q: TreeNode?) -> TreeNode? {
        guard let root = root else {
            return nil
        }
        guard let p = p else {
            return nil
        }
        guard let q = q else {
            return nil
        }
        let pPath = pathForNode(root, target: p)
        let qPath = pathForNode(root, target: q)
        for aNode in pPath.reversed() {
            if qPath.contains(aNode) {
                return aNode
            }
        }
        return nil
    }
}


/*
 
 先序遍历.
   1
  / \
 2   3
    / \
   4   5
 
 1, 2, null, null, 3, 4, null, null, 5, null, null
        1
     2
 null null  3
        4           5
    null null   null null
 
 class Codec {
 public:
      string serialize(TreeNode* root) {
         ostringstream out;
         serialize(root, out);
         return out.str();
     }
     // Decodes your encoded data to tree.
     TreeNode* deserialize(string data) {
         istringstream in(data);
         return deserialize(in);
     }
 private:
     void serialize(TreeNode *root, ostringstream &out) {
         if (root) {
             out << root->val << ' ';
             serialize(root->left, out);
             serialize(root->right, out);
         } else {
             out << "# ";
         }
     }
     TreeNode* deserialize(istringstream &in) {
         string val;
         in >> val;
         if (val == "#") return nullptr;
         TreeNode *root = new TreeNode(stoi(val));
         root->left = deserialize(in);
         root->right = deserialize(in);
         return root;
     }
 };
 */
