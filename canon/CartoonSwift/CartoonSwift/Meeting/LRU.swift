//
//  LRU.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/12.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation


/*
 /**
 * Your LRUCache object will be instantiated and called as such:
 * let obj = LRUCache(capacity)
 * let ret_1: Int = obj.get(key)
 * obj.put(key, value)
 */
 */

/*
 Design and implement a data structure for Least Recently Used (LRU) cache. It should support the following operations: get and put.

 get(key) - Get the value (will always be positive) of the key if the key exists in the cache, otherwise return -1.
 put(key, value) - Set or insert the value if the key is not already present. When the cache reached its capacity, it should invalidate the least recently used item before inserting a new item.

 The cache is initialized with a positive capacity.

 Follow up:
 Could you do both operations in O(1) time complexity?

 Example:

 LRUCache cache = new LRUCache( 2 /* capacity */ );

 cache.put(1, 1);
 cache.put(2, 2);
 cache.get(1);       // returns 1
 cache.put(3, 3);    // evicts key 2
 cache.get(2);       // returns -1 (not found)
 cache.put(4, 4);    // evicts key 1
 cache.get(1);       // returns -1 (not found)
 cache.get(3);       // returns 3
 cache.get(4);       // returns 4
 */

class LRUCache {
    
    class LRUNode {
        var val: Int = 0
        var key: Int = 0
        var next: LRUNode?
        var previous: LRUNode?
    }
    
    var list: LRUNode
    var mapper: [Int: LRUNode]
    let capacity: Int
    var count: Int = 0

    init(_ capacity: Int) {
        self.capacity = capacity
        mapper = [Int: LRUNode]()
        mapper.reserveCapacity(capacity)
        list = LRUNode()
    }
    
    func get(_ key: Int) -> Int {
        guard let targetNode = mapper[key] else {
            return -1
        }
        targetNode.previous?.next = targetNode.next
        targetNode.next?.previous = targetNode.previous
        
        targetNode.next = list.next
        list.next?.previous = targetNode
        
        list.next = targetNode
        targetNode.previous = list
        
        return targetNode.val
    }
    
    func put(_ key: Int, _ value: Int) {
        if let targetNode = mapper[key] {
            targetNode.val = value
            
            targetNode.previous?.next = targetNode.next
            targetNode.next?.previous = targetNode.previous
            
            targetNode.next = list.next
            list.next?.previous = targetNode
            
            list.next = targetNode
            targetNode.previous = list
            print(mapper)
        } else {
            if count >= capacity {
                var currentNode = list.next
                while currentNode?.next != nil {
                    currentNode = currentNode?.next
                }
                mapper[currentNode!.key] = nil
                currentNode?.previous?.next = nil
                count -= 1
            }
            let insertedNode = LRUNode()
            insertedNode.val = value
            insertedNode.key = key
            
            insertedNode.next = list.next
            list.next?.previous = insertedNode
            
            list.next = insertedNode
            insertedNode.previous = list
            
            mapper[key] = insertedNode
            count += 1
            print(mapper)
        }
    }
}
