// replaceSubrange 是 RangeReplacable 的 primitive method. 这个方法的参数, 是一个 Collection.
// EmptyCollection 主要用了 Remove 操作. 当需要 Remove 的时候, 传入到 replaceSubrange 的就是一个 zero Collection. 必须是一个 Collection, 因为 replaceSubrange 的抽象层, 还是需要时一个 Collection.
// 这也就是, 统一的 primitive 方法的问题所在, 为了适配这层抽象, 要做很多适配. 好处在于, 所有的逻辑归结到了一点.
public struct EmptyCollection<Element> {
    public init() {}
}

extension EmptyCollection {
    public struct Iterator {
        public init() {}
    }
}

extension EmptyCollection.Iterator: IteratorProtocol, Sequence {
    public mutating func next() -> Element? {
        return nil
    }
}

extension EmptyCollection: Sequence {
    public func makeIterator() -> Iterator {
        return Iterator()
    }
}

extension EmptyCollection: RandomAccessCollection, MutableCollection {
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public typealias SubSequence = EmptyCollection<Element>
    public var startIndex: Index {
        return 0
    }
    public var endIndex: Index {
        return 0
    }
    
    public func index(after i: Index) -> Index {
        _preconditionFailure("EmptyCollection can't advance indices")
    }
    
    public func index(before i: Index) -> Index {
        _preconditionFailure("EmptyCollection can't advance indices")
    }
    
    public subscript(position: Index) -> Element {
        get {
            _preconditionFailure("Index out of range")
        }
        set {
            _preconditionFailure("Index out of range")
        }
    }
    
    public subscript(bounds: Range<Index>) -> SubSequence {
        get {
            _debugPrecondition(bounds.lowerBound == 0 && bounds.upperBound == 0,
                               "Index out of range")
            return self
        }
        set {
            _debugPrecondition(bounds.lowerBound == 0 && bounds.upperBound == 0,
                               "Index out of range")
        }
    }
    
    public var count: Int {
        return 0
    }
    
    public func index(_ i: Index, offsetBy n: Int) -> Index {
        _debugPrecondition(i == startIndex && n == 0, "Index out of range")
        return i
    }
    
    public func index(
        _ i: Index, offsetBy n: Int, limitedBy limit: Index
    ) -> Index? {
        _debugPrecondition(i == startIndex && limit == startIndex,
                           "Index out of range")
        return n == 0 ? i : nil
    }
    
    public func distance(from start: Index, to end: Index) -> Int {
        return 0
    }
    
    public func _failEarlyRangeCheck(_ index: Index, bounds: Range<Index>) {
        _debugPrecondition(index == 0, "out of bounds")
        _debugPrecondition(bounds == indices, "invalid bounds for an empty collection")
    }
    
    public func _failEarlyRangeCheck(
        _ range: Range<Index>, bounds: Range<Index>
    ) {
        _debugPrecondition(range == indices, "invalid range for an empty collection")
        _debugPrecondition(bounds == indices, "invalid bounds for an empty collection")
    }
}

extension EmptyCollection: Equatable {
    @inlinable // trivial-implementation
    public static func == (
        lhs: EmptyCollection<Element>, rhs: EmptyCollection<Element>
    ) -> Bool {
        return true
    }
}
