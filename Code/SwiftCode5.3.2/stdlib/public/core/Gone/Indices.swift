// 这里, 类型参数是 Collection
// 这个类, 存储的是, 容器的下标所组成的容器.
// 并且会存储一下, 原来的容器, 这样, 就可以利用容器的各种下标操作
public struct DefaultIndices<Elements: Collection> {
    internal var _elements: Elements
    internal var _startIndex: Elements.Index
    internal var _endIndex: Elements.Index
    
    init(_elements: Elements,
         startIndex: Elements.Index,
         endIndex: Elements.Index ) {
        self._elements = _elements
        self._startIndex = startIndex
        self._endIndex = endIndex
    }
}

extension DefaultIndices: Collection {
    public typealias Index = Elements.Index
    public typealias Element = Elements.Index
    public typealias Indices = DefaultIndices<Elements>
    public typealias SubSequence = DefaultIndices<Elements>
    public typealias Iterator = IndexingIterator<DefaultIndices<Elements>>
    
    public var startIndex: Index {
        return _startIndex
    }
    
    public var endIndex: Index {
        return _endIndex
    }
    
    // 下标容器, 传入什么, 返回什么.
    public subscript(i: Index) -> Elements.Index {
        return i
    }
    
    public subscript(bounds: Range<Index>) -> DefaultIndices<Elements> {
        return DefaultIndices(
            _elements: _elements,
            startIndex: bounds.lowerBound,
            endIndex: bounds.upperBound)
    }
    
    // 一切都是根据存储的 collection 进行操作.
    public func index(after i: Index) -> Index {
        return _elements.index(after: i)
    }
    
    public func formIndex(after i: inout Index) {
        _elements.formIndex(after: &i)
    }
    
    public var indices: Indices {
        return self
    }
}

// 如果, elements 是双向的, 那么 Indices 就是双向的.
extension DefaultIndices: BidirectionalCollection where Elements: BidirectionalCollection {
    public func index(before i: Index) -> Index {
        return _elements.index(before: i)
    }
    
    public func formIndex(before i: inout Index) {
        _elements.formIndex(before: &i)
    }
}

extension DefaultIndices: RandomAccessCollection
where Elements: RandomAccessCollection { }

extension Collection where Indices == DefaultIndices<Self> {
    public var indices: DefaultIndices<Self> {
        return DefaultIndices(
            _elements: self,
            startIndex: self.startIndex,
            endIndex: self.endIndex)
    }
}
