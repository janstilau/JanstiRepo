public struct LazyMapSequence<Base: Sequence, Element> {
    public typealias Elements = LazyMapSequence
    internal var _base: Base
    internal let _transform: (Base.Element) -> Element
    internal init(_base: Base, transform: @escaping (Base.Element) -> Element) {
        self._base = _base
        self._transform = transform
    }
}

extension LazyMapSequence {
    @frozen
    public struct Iterator {
        internal var _base: Base.Iterator
        internal let _transform: (Base.Element) -> Element
        public var base: Base.Iterator { return _base }
        internal init(
            _base: Base.Iterator,
            _transform: @escaping (Base.Element) -> Element
        ) {
            self._base = _base
            self._transform = _transform
        }
    }
}

extension LazyMapSequence.Iterator: IteratorProtocol, Sequence {
    public mutating func next() -> Element? {
        return _base.next().map(_transform)
    }
}

extension LazyMapSequence: LazySequenceProtocol {
    public __consuming func makeIterator() -> Iterator {
        return Iterator(_base: _base.makeIterator(), _transform: _transform)
    }
    public var underestimatedCount: Int {
        return _base.underestimatedCount
    }
}

/// A `Collection` whose elements consist of those in a `Base`
/// `Collection` passed through a transform function returning `Element`.
/// These elements are computed lazily, each time they're read, by
/// calling the transform function on a base element.
public typealias LazyMapCollection<T: Collection,U> = LazyMapSequence<T,U>

extension LazyMapCollection: Collection {
    public typealias Index = Base.Index
    public typealias Indices = Base.Indices
    public typealias SubSequence = LazyMapCollection<Base.SubSequence, Element>
    
    @inlinable
    public var startIndex: Base.Index { return _base.startIndex }
    @inlinable
    public var endIndex: Base.Index { return _base.endIndex }
    
    @inlinable
    public func index(after i: Index) -> Index { return _base.index(after: i) }
    @inlinable
    public func formIndex(after i: inout Index) { _base.formIndex(after: &i) }
    
    /// Accesses the element at `position`.
    ///
    /// - Precondition: `position` is a valid position in `self` and
    ///   `position != endIndex`.
    @inlinable
    public subscript(position: Base.Index) -> Element {
        return _transform(_base[position])
    }
    
    @inlinable
    public subscript(bounds: Range<Base.Index>) -> SubSequence {
        return SubSequence(_base: _base[bounds], transform: _transform)
    }
    
    @inlinable
    public var indices: Indices {
        return _base.indices
    }
    
    /// A Boolean value indicating whether the collection is empty.
    @inlinable
    public var isEmpty: Bool { return _base.isEmpty }
    
    /// The number of elements in the collection.
    ///
    /// To check whether the collection is empty, use its `isEmpty` property
    /// instead of comparing `count` to zero. Unless the collection guarantees
    /// random-access performance, calculating `count` can be an O(*n*)
    /// operation.
    ///
    /// - Complexity: O(1) if `Index` conforms to `RandomAccessIndex`; O(*n*)
    ///   otherwise.
    @inlinable
    public var count: Int {
        return _base.count
    }
    
    @inlinable
    public func index(_ i: Index, offsetBy n: Int) -> Index {
        return _base.index(i, offsetBy: n)
    }
    
    @inlinable
    public func index(
        _ i: Index, offsetBy n: Int, limitedBy limit: Index
    ) -> Index? {
        return _base.index(i, offsetBy: n, limitedBy: limit)
    }
    
    @inlinable
    public func distance(from start: Index, to end: Index) -> Int {
        return _base.distance(from: start, to: end)
    }
}

extension LazyMapCollection: BidirectionalCollection
where Base: BidirectionalCollection {
    
    /// A value less than or equal to the number of elements in the collection.
    ///
    /// - Complexity: O(1) if the collection conforms to
    ///   `RandomAccessCollection`; otherwise, O(*n*), where *n* is the length
    ///   of the collection.
    @inlinable
    public func index(before i: Index) -> Index { return _base.index(before: i) }
    
    @inlinable
    public func formIndex(before i: inout Index) {
        _base.formIndex(before: &i)
    }
}

extension LazyMapCollection: LazyCollectionProtocol { }

extension LazyMapCollection: RandomAccessCollection
where Base: RandomAccessCollection { }

//===--- Support for s.lazy -----------------------------------------------===//

extension LazySequenceProtocol {
    @inlinable
    public func map<U>(
        _ transform: @escaping (Element) -> U
    ) -> LazyMapSequence<Elements, U> {
        return LazyMapSequence(_base: elements, transform: transform)
    }
}

extension LazyMapSequence {
    @inlinable
    @available(swift, introduced: 5)
    public func map<ElementOfResult>(
        _ transform: @escaping (Element) -> ElementOfResult
    ) -> LazyMapSequence<Base, ElementOfResult> {
        return LazyMapSequence<Base, ElementOfResult>(
            _base: _base,
            transform: { transform(self._transform($0)) })
    }
}

extension LazyMapCollection {
    @inlinable
    @available(swift, introduced: 5)
    public func map<ElementOfResult>(
        _ transform: @escaping (Element) -> ElementOfResult
    ) -> LazyMapCollection<Base, ElementOfResult> {
        return LazyMapCollection<Base, ElementOfResult>(
            _base: _base,
            transform: {transform(self._transform($0))})
    }
}
