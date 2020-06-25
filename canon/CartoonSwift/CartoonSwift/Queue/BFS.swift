//
//  BFS.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/25.
//  Copyright © 2020 JustinLau. All rights reserved.
//
/*
 1. 结点的处理顺序是什么？

 在第一轮中，我们处理根结点。在第二轮中，我们处理根结点旁边的结点；在第三轮中，我们处理距根结点两步的结点；等等等等。

 与树的层序遍历类似，越是接近根结点的结点将越早地遍历。

 如果在第 k 轮中将结点 X 添加到队列中，则根结点与 X 之间的最短路径的长度恰好是 k。也就是说，第一次找到目标结点时，你已经处于最短路径中。

 2. 队列的入队和出队顺序是什么？

 如上面的动画所示，我们首先将根结点排入队列。然后在每一轮中，我们逐个处理已经在队列中的结点，并将所有邻居添加到队列中。值得注意的是，新添加的节点不会立即遍历，而是在下一轮中处理。

 结点的处理顺序与它们添加到队列的顺序是完全相同的顺序，即先进先出（FIFO）。这就是我们在 BFS 中使用队列的原因。
 
 遍历或找出最短路径。通常，这发生在树或图中。正如我们在章节描述中提到的，BFS 也可以用于更抽象的场景中。
 
 */

/*
 BFS JAVA
 // Return the length of the shortest path between root and target node.
 
 int BFS(Node root, Node target) {
     Queue<Node> queue;  // store all nodes which are waiting to be processed
     Set<Node> used;     // store all the used nodes
     int step = 0;       // number of steps neeeded from root to current node
     // initialize
     add root to queue;
     add root to used;
     // BFS
     while (queue is not empty) {
         step = step + 1;
         // iterate the nodes which are already in the queue
         int size = queue.size();
         for (int i = 0; i < size; ++i) {
             Node cur = the first node in queue;
             return step if cur is target;
             for (Node next : the neighbors of cur) {
                 if (next is not in used) {
                     add next to queue;
                     add next to used;
                 }
             }
             remove the first node from queue;
         }
     }
     return -1;          // there is no path from root to target
 }
 
 有两种情况你不需要使用哈希集：
 你完全确定没有循环，例如，在树遍历中；
 你确实希望多次将结点添加到队列中。
 */

/*
 Given a 2d grid map of '1's (land) and '0's (water), count the number of islands. An island is surrounded by water and is formed by connecting adjacent lands horizontally or vertically. You may assume all four edges of the grid are all surrounded by water.

 Example 1:

 Input:
 11110
 11010
 11000
 00000

 Output: 1
 Example 2:

 Input:
 11000
 11000
 00100
 00011

 Output: 3
 */
import Foundation

class Island {
    struct LandPoint:Hashable {
        var x: Int = 0
        var y: Int = 0
    }
    
    var used = Set<LandPoint>()
    var queue = [LandPoint]()
    var rowCount = 0
    var columnCount = 0
    var grids = [[Character]]()

    func isLand(pos: LandPoint) -> Bool {
        if used.contains(pos) { return false }
        if (pos.x < 0) { return false }
        if (pos.y < 0) { return false }
        if (pos.x >= columnCount) { return false }
        if (pos.y >= rowCount) { return false }
        let char = grids[pos.y][pos.x]
        return char == "1"
    }
    
    func numIslands(_ grid: [[Character]]) -> Int {
        used.removeAll()
        queue.removeAll()
        grids.removeAll()
        rowCount = 0
        columnCount = 0
        
        let rows = grid.count
        if (rows <= 0) { return 0 }
        let columns = grid.first!.count
        if (columns <= 0) { return 0 }
        rowCount = rows
        columnCount = columns
        grids = grid
        
        var result = 0
        
        for y in 0..<rowCount {
            for x in 0..<columnCount {
                let pos = LandPoint(x: x, y: y)
                if used.contains(pos) { continue }
                if !isLand(pos: pos) { continue }
                result += 1
                queue.append(pos)
                used.insert(pos)
                print(queue)
                while !queue.isEmpty {
                    let frontPos = queue.removeFirst()
                    let frontTopPos = LandPoint(x: frontPos.x, y: frontPos.y - 1)
                    if isLand(pos: frontTopPos) {
                        queue.append(frontTopPos)
                        used.insert(frontTopPos)
                    }
                    let frontLeftPos = LandPoint(x: frontPos.x - 1, y: frontPos.y)
                    if isLand(pos: frontLeftPos) {
                        queue.append(frontLeftPos)
                        used.insert(frontLeftPos)
                    }
                    let frontRightPos = LandPoint(x: frontPos.x + 1, y: frontPos.y)
                    if isLand(pos: frontRightPos) {
                        queue.append(frontRightPos)
                        used.insert(frontRightPos)
                    }
                    let frontBottomPos = LandPoint(x: frontPos.x, y: frontPos.y + 1)
                    if isLand(pos: frontBottomPos) {
                        queue.append(frontBottomPos)
                        used.insert(frontBottomPos)
                    }
                }
            }
        }
        return result
    }
}


/*
 You have a lock in front of you with 4 circular wheels. Each wheel has 10 slots: '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'. The wheels can rotate freely and wrap around: for example we can turn '9' to be '0', or '0' to be '9'. Each move consists of turning one wheel one slot.

 The lock initially starts at '0000', a string representing the state of the 4 wheels.

 You are given a list of deadends dead ends, meaning if the lock displays any of these codes, the wheels of the lock will stop turning and you will be unable to open it.

 Given a target representing the value of the wheels that will unlock the lock, return the minimum total number of turns required to open the lock, or -1 if it is impossible.

 Example 1:
 Input: deadends = ["0201","0101","0102","1212","2002"], target = "0202"
 Output: 6
 Explanation:
 A sequence of valid moves would be "0000" -> "1000" -> "1100" -> "1200" -> "1201" -> "1202" -> "0202".
 Note that a sequence like "0000" -> "0001" -> "0002" -> "0102" -> "0202" would be invalid,
 because the wheels of the lock become stuck after the display becomes the dead end "0102".
 Example 2:
 Input: deadends = ["8888"], target = "0009"
 Output: 1
 Explanation:
 We can turn the last wheel in reverse to move from "0000" -> "0009".
 Example 3:
 Input: deadends = ["8887","8889","8878","8898","8788","8988","7888","9888"], target = "8888"
 Output: -1
 Explanation:
 We can't reach the target without getting stuck.
 Example 4:
 Input: deadends = ["0000"], target = "8888"
 Output: -1
 Note:
 The length of deadends will be in the range [1, 500].
 target will not be in the list deadends.
 Every string in deadends and the string target will be a string of 4 digits from the 10,000 possibilities '0000' to '9999'.
 */


class Lock {
    func openLock(_ deadends: [String], _ target: String) -> Int {
        return 1
    }
}


/*
 Given a positive integer n, find the least number of perfect square numbers (for example, 1, 4, 9, 16, ...) which sum to n.

 Example 1:

 Input: n = 12
 Output: 3
 Explanation: 12 = 4 + 4 + 4.
 Example 2:

 Input: n = 13
 Output: 2
 Explanation: 13 = 4 + 9.
 */

class Square {
    func numSquares(_ n: Int) -> Int {
        return 1
    }
}
