//
//  Queue.swift
//  Platform
//
//  Created by Krunoslav Zaher on 3/21/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
Data structure that represents queue.

Complexity of `enqueue`, `dequeue` is O(1) when number of operations is
averaged over N operations.

Complexity of `peek` is O(1).
*/

/*
 
 */
struct Queue<T>: Sequence {
    /// Type of generator.
    typealias Generator = AnyIterator<T>

    private let resizeFactor = 2
    
    private var storage: ContiguousArray<T?>
    private var innerCount = 0
    private var pushNextIndex = 0
    private let initialCapacity: Int

    /**
    Creates new queue.
    
    - parameter capacity: Capacity of newly created queue.
    */
    init(capacity: Int) {
        initialCapacity = capacity

        storage = ContiguousArray<T?>(repeating: nil, count: capacity)
    }
    
    private var dequeueIndex: Int {
        let index = pushNextIndex - count
        return index < 0 ? index + storage.count : index
    }
    
    /// - returns: Is queue empty.
    var isEmpty: Bool { count == 0 }
    
    /// - returns: Number of elements inside queue.
    var count: Int { innerCount }
    
    /// - returns: Element in front of a list of elements to `dequeue`.
    func peek() -> T {
        precondition(count > 0)
        
        return storage[dequeueIndex]!
    }
    
    mutating private func resizeTo(_ size: Int) {
        var newStorage = ContiguousArray<T?>(repeating: nil, count: size)
        
        let count = self.count
        
        let dequeueIndex = self.dequeueIndex
        let spaceToEndOfQueue = storage.count - dequeueIndex
        
        // first batch is from dequeue index to end of array
        let countElementsInFirstBatch = Swift.min(count, spaceToEndOfQueue)
        // second batch is wrapped from start of array to end of queue
        let numberOfElementsInSecondBatch = count - countElementsInFirstBatch
        
        newStorage[0 ..< countElementsInFirstBatch] = storage[dequeueIndex ..< (dequeueIndex + countElementsInFirstBatch)]
        newStorage[countElementsInFirstBatch ..< (countElementsInFirstBatch + numberOfElementsInSecondBatch)] = storage[0 ..< numberOfElementsInSecondBatch]
        
        self.innerCount = count
        pushNextIndex = count
        storage = newStorage
    }
    
    /// Enqueues `element`.
    ///
    /// - parameter element: Element to enqueue.
    // 这里的意思是, 这是一个环状的队列.
    mutating func enqueue(_ element: T) {
        if count == storage.count {
            resizeTo(Swift.max(storage.count, 1) * resizeFactor)
        }
        
        storage[pushNextIndex] = element
        pushNextIndex += 1
        innerCount += 1
        
        if pushNextIndex >= storage.count {
            pushNextIndex -= storage.count
        }
    }
    
    private mutating func dequeueElementOnly() -> T {
        precondition(count > 0)
        
        let index = dequeueIndex

        defer {
            storage[index] = nil
            innerCount -= 1
        }

        return storage[index]!
    }

    /// Dequeues element or throws an exception in case queue is empty.
    ///
    /// - returns: Dequeued element.
    mutating func dequeue() -> T? {
        if self.count == 0 {
            return nil
        }

        defer {
            let downsizeLimit = storage.count / (resizeFactor * resizeFactor)
            if count < downsizeLimit && downsizeLimit >= initialCapacity {
                resizeTo(storage.count / resizeFactor)
            }
        }

        return dequeueElementOnly()
    }
    
    /// - returns: Generator of contained elements.
    func makeIterator() -> AnyIterator<T> {
        var i = dequeueIndex
        var innerCount = count

        /*
         这里, 体现了使用闭包的好处.
         可以不专门的设置一个 Iterator, 而是每次使用闭包, 存储相关的值. 闭包会存储状态, 在 innerCount 为 0 的时候, 也就是遍历结束了.
         */
        return AnyIterator {
            if innerCount == 0 {
                return nil
            }

            defer {
                innerCount -= 1
                i += 1
            }

            if i >= self.storage.count {
                i -= self.storage.count
            }

            return self.storage[i]
        }
    }
}
