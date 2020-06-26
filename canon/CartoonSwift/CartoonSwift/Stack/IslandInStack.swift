//
//  IslandInStack.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/26.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

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

class Solution {
    struct LandPoint:Hashable {
        var x: Int = 0
        var y: Int = 0
    }
    
    var used = Set<LandPoint>()
    var queue = [LandPoint]()
    var stack = [LandPoint]()
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
    
    func numIslandsInBFS(_ grid: [[Character]]) -> Int {
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
    
    func numIslandsInDFS(_ grid: [[Character]]) -> Int {
        used.removeAll()
        stack.removeAll()
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
                DFSSearch(pos: pos)
            }
        }
        return result
    }
    
    func DFSSearch(pos: LandPoint)  {
        used.insert(pos)
        stack.append(pos)
        let topPos = LandPoint(x: pos.x, y: pos.y - 1)
        let leftPos = LandPoint(x: pos.x - 1, y: pos.y)
        let rightPos = LandPoint(x: pos.x + 1, y: pos.y)
        let bottomPos = LandPoint(x: pos.x, y: pos.y + 1)
        let surroundPos = [topPos, leftPos, rightPos, bottomPos]
        for aPos in surroundPos {
            if !used.contains(pos),
                isLand(pos: aPos) {
                DFSSearch(pos: aPos)
            }
        }
        stack.removeLast()
    }
}
