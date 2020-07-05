//
//  DesignList.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/5.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 Design your implementation of the linked list. You can choose to use the singly linked list or the doubly linked list. A node in a singly linked list should have two attributes: val and next. val is the value of the current node, and next is a pointer/reference to the next node. If you want to use the doubly linked list, you will need one more attribute prev to indicate the previous node in the linked list. Assume all nodes in the linked list are 0-indexed.

 Implement these functions in your linked list class:

 get(index) : Get the value of the index-th node in the linked list. If the index is invalid, return -1.
 addAtHead(val) : Add a node of value val before the first element of the linked list. After the insertion, the new node will be the first node of the linked list.
 addAtTail(val) : Append a node of value val to the last element of the linked list.
 addAtIndex(index, val) : Add a node of value val before the index-th node in the linked list. If index equals to the length of linked list, the node will be appended to the end of linked list. If index is greater than the length, the node will not be inserted.
 deleteAtIndex(index) : Delete the index-th node in the linked list, if the index is valid.
  

 Example:

 Input:
 ["MyLinkedList","addAtHead","addAtTail","addAtIndex","get","deleteAtIndex","get"]
 [[],[1],[3],[1,2],[1],[1],[1]]
 Output:
 [null,null,null,null,2,null,3]

 Explanation:
 MyLinkedList linkedList = new MyLinkedList(); // Initialize empty LinkedList
 linkedList.addAtHead(1);
 linkedList.addAtTail(3);
 linkedList.addAtIndex(1, 2);  // linked list becomes 1->2->3
 linkedList.get(1);            // returns 2
 linkedList.deleteAtIndex(1);  // now the linked list is 1->3
 linkedList.get(1);            // returns 3
  

 Constraints:

 0 <= index,val <= 1000
 Please do not use the built-in LinkedList library.
 At most 2000 calls will be made to get, addAtHead, addAtTail,  addAtIndex and deleteAtIndex.
 */

class MyLinkedList {
    
    class MyLinkNode {
        var val: Int = 0
        var next: MyLinkNode?
        var prev: MyLinkNode?
    }
    
    let listHead: MyLinkNode
    var listTail: MyLinkNode
    var listLength = 0
    
    init() {
        listHead = MyLinkNode()
        listTail = listHead
    }
    
    /** Get the value of the index-th node in the linked list. If the index is invalid, return -1. */
    func get(_ index: Int) -> Int {
        let targetNode = getNode(index)
        if targetNode == nil {
            return -1
        } else {
            return targetNode!.val
        }
    }
    
    func getNode(_ index: Int) -> MyLinkNode? {
        if index >= listLength { return nil }
        var currentNode = listHead.next
        var times = index
        while times > 0 {
            currentNode = currentNode?.next
            times -= 1
        }
        return currentNode
    }
    
    /** Add a node of value val before the first element of the linked list. After the insertion, the new node will be the first node of the linked list. */
    func addAtHead(_ val: Int) {
        let insertedFirst = MyLinkNode()
        insertedFirst.val = val
        insertedFirst.next = listHead.next
        insertedFirst.prev = listHead
        listHead.next?.prev = insertedFirst
        listHead.next = insertedFirst
        if listTail === listHead {
            listTail = insertedFirst
        }
        listLength += 1
    }
    
    /** Append a node of value val to the last element of the linked list. */
    func addAtTail(_ val: Int) {
        let addedTail = MyLinkNode()
        addedTail.val = val
        addedTail.prev = listTail
        listTail.next = addedTail
        listTail = addedTail
        listLength += 1
    }
    
    /** Add a node of value val before the index-th node in the linked list. If index equals to the length of linked list, the node will be appended to the end of linked list. If index is greater than the length, the node will not be inserted. */
    func addAtIndex(_ index: Int, _ val: Int) {
        guard index <= listLength else {
            return
        }
        if index == listLength {
            addAtTail(val)
        } else {
            let idxNode = getNode(index)
            let insertedNode = MyLinkNode()
            insertedNode.val = val
            insertedNode.prev = idxNode?.prev
            insertedNode.next = idxNode
            idxNode?.prev?.next = insertedNode
            idxNode?.prev = insertedNode
            listLength += 1
        }
    }
    
    /** Delete the index-th node in the linked list, if the index is valid. */
    func deleteAtIndex(_ index: Int) {
        guard index < listLength else {
            return
        }
        let targetNode = getNode(index)
        targetNode?.prev?.next = targetNode?.next
        targetNode?.next?.prev = targetNode?.prev
        if listTail === targetNode {
            listTail = (targetNode?.prev)!
        }
        listLength -= 1
    }
}

/**
 * Your MyLinkedList object will be instantiated and called as such:
 * let obj = MyLinkedList()
 * let ret_1: Int = obj.get(index)
 * obj.addAtHead(val)
 * obj.addAtTail(val)
 * obj.addAtIndex(index, val)
 * obj.deleteAtIndex(index)
 */
