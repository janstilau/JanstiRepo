// index(before:)
// BidirectionalCollection 最大的区别, 就是提供了 index(before:) 的实现, 这样就可以从 endIndex 向前寻找 Index
// 这种, 使得某些操作, 可以更快.

// 在 C++ 里面, bidirection 是通过 迭代器里面的 typedef 完成的, 然后根据 iterator traits 完成算法层面的分化,  而在 Swfit 里面, 则是通过协议. 这样更加的直观.

public protocol BidirectionalCollection: Collection
where SubSequence: BidirectionalCollection, Indices: BidirectionalCollection {
    override associatedtype Element
    override associatedtype Index
    override associatedtype SubSequence
    override associatedtype Indices
    
    // 最最重要的一项, 就是增加了 beform 的抽象, 使得 index 可以向前进行获取.
    // 下面的各种方法, 都会根据 正负, 来调用 index after, 还是 index before.
    func index(before i: Index) -> Index
    func formIndex(before i: inout Index)
    
    // 重写了一些方法, 主要是没有了 必须 offset > 0 的限制, 可以 < 0 了, 表示向前.
    override func index(after i: Index) -> Index
    override func formIndex(after i: inout Index)
    
    // 这个方法, 会利用 index after, beform 方法.
    func index(_ i: Index, offsetBy distance: Int) -> Index
    
    func index(
        _ i: Index, offsetBy distance: Int, limitedBy limit: Index
    ) -> Index?
    
    func distance(from start: Index, to end: Index) -> Int
    
    override var indices: Indices { get }
    override subscript(bounds: Range<Index>) -> SubSequence { get }
    
    override subscript(position: Index) -> Element { get }
    override var startIndex: Index { get }
    override var endIndex: Index { get }
}

extension BidirectionalCollection {
    public func formIndex(before i: inout Index) {
        i = index(before: i)
    }
    
    public func index(_ i: Index, offsetBy distance: Int) -> Index {
        return _index(i, offsetBy: distance)
    }
    
    // 如果, distance > 0, 就使用原来的方法, 如果是小于 0 , 就是向前, 就使用 formIndex(before) 方法.
    internal func _index(_ i: Index, offsetBy distance: Int) -> Index {
        if distance >= 0 {
            return _advanceForward(i, by: distance)
        }
        var i = i
        for _ in stride(from: 0, to: distance, by: -1) {
            formIndex(before: &i)
        }
        return i
    }
    
    public func index(
        _ i: Index, offsetBy distance: Int, limitedBy limit: Index
    ) -> Index? {
        return _index(i, offsetBy: distance, limitedBy: limit)
    }
    
    // 根据 正负, 调用不同的 index 计算方法.
    internal func _index(
        _ i: Index, offsetBy distance: Int, limitedBy limit: Index
    ) -> Index? {
        if distance >= 0 {
            return _advanceForward(i, by: distance, limitedBy: limit)
        }
        var i = i
        for _ in stride(from: 0, to: distance, by: -1) {
            if i == limit {
                return nil
            }
            formIndex(before: &i)
        }
        return i
    }
    
    public func distance(from start: Index, to end: Index) -> Int {
        return _distance(from: start, to: end)
    }
    
    internal func _distance(from start: Index, to end: Index) -> Int {
        var start = start
        var count = 0
        
        // 因为, Index 是可以比较大小的, 所以可以根据 start, end, 计算出最后的 count 来.
        if start < end {
            while start != end {
                count += 1
                formIndex(after: &start)
            }
        }
        else if start > end {
            while start != end {
                count -= 1
                formIndex(before: &start)
            }
        }
        
        return count
    }
}

// 因为, 有了向前的能力, 所以操作后面数据的操作, 就效率变得非常高了, 直接从 endIndex 进行操作.
extension BidirectionalCollection where SubSequence == Self {
    public mutating func popLast() -> Element? {
        guard !isEmpty else { return nil }
        let element = last!
        self = self[startIndex..<index(before: endIndex)]
        return element
    }
    
    public mutating func removeLast() -> Element {
        let element = last!
        self = self[startIndex..<index(before: endIndex)]
        return element
    }
    
    public mutating func removeLast(_ k: Int) {
        if k == 0 { return }
        _precondition(k >= 0, "Number of elements to remove should be non-negative")
        guard let end = index(endIndex, offsetBy: -k, limitedBy: startIndex)
        else {
            _preconditionFailure(
                "Can't remove more items from a collection than it contains")
        }
        self = self[startIndex..<end]
    }
}

extension BidirectionalCollection {
    public __consuming func dropLast(_ k: Int) -> SubSequence {
        _precondition(
            k >= 0, "Can't drop a negative number of elements from a collection")
        let end = index(
            endIndex,
            offsetBy: -k,
            limitedBy: startIndex) ?? startIndex
        return self[startIndex..<end]
    }
    
    public __consuming func suffix(_ maxLength: Int) -> SubSequence {
        _precondition(
            maxLength >= 0,
            "Can't take a suffix of negative length from a collection")
        let start = index(
            endIndex,
            offsetBy: -maxLength,
            limitedBy: startIndex) ?? startIndex
        return self[start..<endIndex]
    }
}

