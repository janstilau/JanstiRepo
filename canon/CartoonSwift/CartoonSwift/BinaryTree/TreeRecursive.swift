//
//  TreeRecursive.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/10.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation
/*
 运用递归解决树的问题
 “自顶向下” 的解决方案
 “自底向上” 的解决方案
 总结


 在前面的章节中，我们已经介绍了如何利用递归求解树的遍历。 递归是解决树的相关问题最有效和最常用的方法之一。

 我们知道，树可以以递归的方式定义为一个节点（根节点），它包括一个值和一个指向其他节点指针的列表。 递归是树的特性之一。 因此，许多树问题可以通过递归的方式来解决。 对于每个递归层级，我们只能关注单个节点内的问题，并通过递归调用函数来解决其子节点问题。

 通常，我们可以通过 “自顶向下” 或 “自底向上” 的递归来解决树问题。



 “自顶向下” 的解决方案
 “自顶向下” 意味着在每个递归层级，我们将首先访问节点来计算一些值，并在递归调用函数时将这些值传递到子节点。 所以 “自顶向下” 的解决方案可以被认为是一种前序遍历。 具体来说，递归函数 top_down(root, params) 的原理是这样的：
 1. return specific value for null node
 2. update the answer if needed                      // anwer <-- params
 3. left_ans = top_down(root.left, left_params)      // left_params <-- root.val, params
 4. right_ans = top_down(root.right, right_params)   // right_params <-- root.val, params
 5. return the answer if needed                      // answer <-- left_ans, right_ans
 例如，思考这样一个问题：给定一个二叉树，请寻找它的最大深度。

 我们知道根节点的深度是1。 对于每个节点，如果我们知道某节点的深度，那我们将知道它子节点的深度。 因此，在调用递归函数的时候，将节点的深度传递为一个参数，那么所有的节点都知道它们自身的深度。 而对于叶节点，我们可以通过更新深度从而获取最终答案。 这里是递归函数 maximum_depth(root, depth) 的伪代码：

 1. return if root is null
 2. if root is a leaf node:
 3.      answer = max(answer, depth)         // update the answer if needed
 4. maximum_depth(root.left, depth + 1)      // call the function recursively for left child
 5. maximum_depth(root.right, depth + 1)     // call the function recursively for right child
 以下的例子可以帮助你理解它是如何工作的：

 Current
 1 / 12
 我们也提供了C ++和java代码以供参考。



 “自底向上” 的解决方案
 “自底向上” 是另一种递归方法。 在每个递归层次上，我们首先对所有子节点递归地调用函数，然后根据返回值和根节点本身的值得到答案。 这个过程可以看作是后序遍历的一种。 通常， “自底向上” 的递归函数 bottom_up(root) 为如下所示：
 1. return specific value for null node
 2. left_ans = bottom_up(root.left)          // call function recursively for left child
 3. right_ans = bottom_up(root.right)        // call function recursively for right child
 4. return answers                           // answer <-- left_ans, right_ans, root.val
 让我们继续讨论前面关于树的最大深度的问题，但是使用不同的思维方式：对于树的单个节点，以节点自身为根的子树的最大深度x是多少？

 如果我们知道一个根节点，以其左子节点为根的最大深度为l和以其右子节点为根的最大深度为r，我们是否可以回答前面的问题？ 当然可以，我们可以选择它们之间的最大值，再加上1来获得根节点所在的子树的最大深度。 那就是 x = max（l，r）+ 1。

 这意味着对于每一个节点来说，我们都可以在解决它子节点的问题之后得到答案。 因此，我们可以使用“自底向上“的方法。下面是递归函数 maximum_depth(root) 的伪代码：

 1. return 0 if root is null                 // return 0 for null node
 2. left_depth = maximum_depth(root.left)
 3. right_depth = maximum_depth(root.right)
 4. return max(left_depth, right_depth) + 1  // return depth of the subtree rooted at root
 以下的例子可以帮助你理解它是如何工作的：

 Current
 1 / 25
 我们也提供了C ++和java代码以供参考。



 总结
 了解递归并利用递归解决问题并不容易。
 当遇到树问题时，请先思考一下两个问题：

 你能确定一些参数，从该节点自身解决出发寻找答案吗？
 你可以使用这些参数和节点本身的值来决定什么应该是传递给它子节点的参数吗？
 如果答案都是肯定的，那么请尝试使用 “自顶向下” 的递归来解决此问题。

 或者你可以这样思考：对于树中的任意一个节点，如果你知道它子节点的答案，你能计算出该节点的答案吗？ 如果答案是肯定的，那么 “自底向上” 的递归可能是一个不错的解决方法。

 在接下来的章节中，我们将提供几个经典例题，以帮助你更好地理解树的结构和递归。
 */
