//
//  SearchTree.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/10.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 二叉搜索树（BST）是二叉树的一种特殊表示形式，它满足如下特性：
 
 每个节点中的值必须大于（或等于）存储在其左侧子树中的任何值。
 每个节点中的值必须小于（或等于）存储在其右子树中的任何值。
 下面是一个二叉搜索树的例子：
 这篇文章之后，我们提供了一个习题来让你验证一个树是否是二叉搜索树。 你可以运用我们上述提到的性质来判断。 前一章介绍的递归思想也可能会对你解决这个问题有所帮助。

 像普通的二叉树一样，我们可以按照前序、中序和后序来遍历一个二叉搜索树。 但是值得注意的是，对于二叉搜索树，我们可以通过中序遍历得到一个递增的有序序列。因此，中序遍历是二叉搜索树中最常用的遍历方法。

 在文章习题中，我们也添加了让你求解二叉搜索树的中序后继节点（in-order successor）的题目。显然，你可以通过中序遍历来找到二叉搜索树的中序后继节点。 你也可以尝试运用二叉搜索树的特性，去寻求更好的解决方案。
 
 */


/*
 在二叉搜索树中实现搜索操作
 二叉搜索树主要支持三个操作：搜索、插入和删除。 在本章中，我们将讨论如何在二叉搜索树中搜索特定的值。

 根据BST的特性，对于每个节点：

 如果目标值等于节点的值，则返回节点;
 如果目标值小于节点的值，则继续在左子树中搜索;
 如果目标值大于节点的值，则继续在右子树中搜索。
  

 我们一起来看一个例子：我们在上面的二叉搜索树中搜索目标值为 4 的节点。
  
 */
