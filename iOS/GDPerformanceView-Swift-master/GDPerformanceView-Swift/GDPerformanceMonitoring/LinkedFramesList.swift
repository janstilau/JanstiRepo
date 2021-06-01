import Foundation

// MARK: Class Definition

/// Linked list node. Represents frame timestamp.
internal class FrameNode {
    
    // MARK: Public Properties
    
    var next: FrameNode?
    weak var previous: FrameNode?
    
    private(set) var timestamp: TimeInterval
    
    /// Initializes linked list node with parameters.
    ///
    /// - Parameter timeInterval: Frame timestamp.
    public init(timestamp: TimeInterval) {
        self.timestamp = timestamp
    }
}

// MARK: Class Definition

/// Linked list. Each node represents frame timestamp.
/// The only function is append, which will add a new frame and remove all frames older than a second from the last timestamp.
/// As a result, the number of items in the list will represent the number of frames for the last second.
internal class LinkedFramesList {
    
    // MARK: Private Properties
    
    private var head: FrameNode?
    private var tail: FrameNode?
    
    // MARK: Public Properties
    
    private(set) var count = 0
}

// MARK: Public Methods

internal extension LinkedFramesList {
    /// Appends new frame with parameters.
    ///
    /// - Parameter timestamp: New frame timestamp.
    func append(frameWithTimestamp timestamp: TimeInterval) {
        let newNode = FrameNode(timestamp: timestamp)
        if let lastNode = self.tail {
            newNode.previous = lastNode
            lastNode.next = newNode
            self.tail = newNode
        } else {
            self.head = newNode
            self.tail = newNode
        }
        
        self.count += 1
        self.removeFrameNodes(olderThanTimestampMoreThanSecond: timestamp)
    }
}

// MARK: Support Methods

private extension LinkedFramesList {
    func removeFrameNodes(olderThanTimestampMoreThanSecond timestamp: TimeInterval) {
        while let firstNode = self.head {
            guard timestamp - firstNode.timestamp > 1.0 else {
                break
            }
            
            let nextNode = firstNode.next
            nextNode?.previous = nil
            firstNode.next = nil
            self.head = nextNode
            
            self.count -= 1
        }
    }
}
