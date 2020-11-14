/*
 存储了原始的 colleciton elements, startIndex, endIndex
 */
@frozen
public struct DefaultIndices<Elements: Collection> {
    @usableFromInline
    internal var _elements: Elements
    @usableFromInline
    internal var _startIndex: Elements.Index // Begin
    @usableFromInline
    internal var _endIndex: Elements.Index // End
    @inlinable
    internal init(
        _elements: Elements,
        startIndex: Elements.Index,
        endIndex: Elements.Index) {
        self._elements = _elements
        self._startIndex = startIndex
        self._endIndex = endIndex
    }
}

/*
 DefaultIndices 所代表的 Collection 里面, index 是 elements.Index, value 也是 elements.Index.
 */
extension DefaultIndices: Collection {
    
    public typealias Index = Elements.Index
    public typealias Element = Elements.Index
    public typealias Indices = DefaultIndices<Elements>
    public typealias SubSequence = DefaultIndices<Elements>
    public typealias Iterator = IndexingIterator<DefaultIndices<Elements>>
    
    @inlinable
    public var startIndex: Index {
        return _startIndex
    }
    
    @inlinable
    public var endIndex: Index {
        return _endIndex
    }
    
    /*
     Value 是 Elements.Index
     Index 是 Elements.Index
     */
    @inlinable
    public subscript(i: Index) -> Elements.Index {
        return i
    }
    
    @inlinable
    public subscript(bounds: Range<Index>) -> DefaultIndices<Elements> {
        return DefaultIndices(
            _elements: _elements,
            startIndex: bounds.lowerBound,
            endIndex: bounds.upperBound)
    }
    
    /*
     所有的操作, 都是转交给了 elements 进行操作.
     */
    @inlinable
    public func index(after i: Index) -> Index {
        return _elements.index(after: i)
    }
    
    @inlinable
    public func formIndex(after i: inout Index) {
        _elements.formIndex(after: &i)
    }
    
    @inlinable
    public var indices: Indices {
        return self
    }
}

/*
  index(before 方法的调用, 是限制在 BidirectionalCollection 这个协议的基础上的.
 */
extension DefaultIndices: BidirectionalCollection
where Elements: BidirectionalCollection {
    @inlinable
    public func index(before i: Index) -> Index {
        return _elements.index(before: i)
    }
    
    @inlinable
    public func formIndex(before i: inout Index) {
        // FIXME: swift-3-indexing-model: range check.
        _elements.formIndex(before: &i)
    }
}

extension DefaultIndices: RandomAccessCollection
where Elements: RandomAccessCollection { }

extension Collection where Indices == DefaultIndices<Self> {
    /// The indices that are valid for subscripting the collection, in ascending
    /// order.
    ///
    /// A collection's `indices` property can hold a strong reference to the
    /// collection itself, causing the collection to be non-uniquely referenced.
    /// If you mutate the collection while iterating over its indices, a strong
    /// reference can cause an unexpected copy of the collection. To avoid the
    /// unexpected copy, use the `index(after:)` method starting with
    /// `startIndex` to produce indices instead.
    ///
    ///     var c = MyFancyCollection([10, 20, 30, 40, 50])
    ///     var i = c.startIndex
    ///     while i != c.endIndex {
    ///         c[i] /= 5
    ///         i = c.index(after: i)
    ///     }
    ///     // c == MyFancyCollection([2, 4, 6, 8, 10])
    @inlinable // trivial-implementation
    public var indices: DefaultIndices<Self> {
        return DefaultIndices(
            _elements: self,
            startIndex: self.startIndex,
            endIndex: self.endIndex)
    }
}
