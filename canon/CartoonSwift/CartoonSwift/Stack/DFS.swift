//
//  DFS.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/26.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 1. 结点的处理顺序是什么？
 在上面的例子中，我们从根结点 A 开始。首先，我们选择结点 B 的路径，并进行回溯，直到我们到达结点 E，我们无法更进一步深入。然后我们回溯到 A 并选择第二条路径到结点 C 。从 C 开始，我们尝试第一条路径到 E 但是 E 已被访问过。所以我们回到 C 并尝试从另一条路径到 F。最后，我们找到了 G。

 总的来说，在我们到达最深的结点之后，我们只会回溯并尝试另一条路径。

 因此，你在 DFS 中找到的第一条路径并不总是最短的路径。例如，在上面的例子中，我们成功找出了路径 A-> C-> F-> G 并停止了 DFS。但这不是从 A 到 G 的最短路径。

 2. 栈的入栈和退栈顺序是什么？
 如上面的动画所示，我们首先将根结点推入到栈中；然后我们尝试第一个邻居 B 并将结点 B 推入到栈中；等等等等。当我们到达最深的结点 E 时，我们需要回溯。当我们回溯时，我们将从栈中弹出最深的结点，这实际上是推入到栈中的最后一个结点。

 结点的处理顺序是完全相反的顺序，就像它们被添加到栈中一样，它是后进先出（LIFO）。这就是我们在 DFS 中使用栈的原因。
 
 与 BFS 不同，更早访问的结点可能不是更靠近根结点的结点。因此，你在 DFS 中找到的第一条路径可能不是最短路径。
 栈的大小正好是 DFS 的深度。因此，在最坏的情况下，维护系统栈需要 O(h)，其中 h 是 DFS 的最大深度。在计算空间复杂度时，永远不要忘记考虑系统栈。
 使用系统的函数栈, 路径的记录是个问题, 如果要记录路径过程, 还是要手动记录下.
 
 和 BFS 把数据装到一个队列不同, DFS 是,
 优先执行某些操作,
 然后循环, 对循环里面的每一个元素, 递归调用自己.
 然后执行清理工作.
 对于 BFS 算法来说, 要保证开始和结束的工作是配对的.
 
 /*
  * Return true if there is a path from cur to target.
  */
 boolean DFS(Node cur, Node target, Set<Node> visited) {
     return true if cur is target;
     for (next : each neighbor of cur) {
         if (next is not in visited) {
             add next to visted;
             return true if DFS(next, target, visited) == true;
         }
     }
     return false;
 }
 
 递归解决方案的优点是它更容易实现。 但是，存在一个很大的缺点：如果递归的深度太高，你将遭受堆栈溢出。 在这种情况下，您可能会希望使用 BFS，或使用显式栈实现 DFS.
 /*
  * Return true if there is a path from cur to target.
  */
 boolean DFS(int root, int target) {
     Set<Node> visited;
     Stack<Node> s;
     add root to visited;
     add root to s;
     while (s is not empty) {
         Node cur = the top element in s;
         return true if cur is target;
         for (Node next : the neighbors of cur) {
             if (next is not in visited) {
                 add next to s;
                 add next to visited;
             }
         }
         remove cur from s;
     }
     return false;
 }
 
 */
