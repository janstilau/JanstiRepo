@frozen // lazy-performance
public struct LazyPrefixWhileSequence<Base: Sequence> {
    public typealias Element = Base.Element
    
    @inlinable // lazy-performance
    internal init(_base: Base, predicate: @escaping (Element) -> Bool) {
        self._base = _base
        self._predicate = predicate
    }
    
    @usableFromInline // lazy-performance
    internal var _base: Base
    @usableFromInline // lazy-performance
    internal let _predicate: (Element) -> Bool
}


extension LazyPrefixWhileSequence {
    @frozen // lazy-performance
    public struct Iterator {
        public typealias Element = Base.Element
        
        @usableFromInline // lazy-performance
        internal var _predicateHasFailed = false
        @usableFromInline // lazy-performance
        internal var _base: Base.Iterator
        @usableFromInline // lazy-performance
        internal let _predicate: (Element) -> Bool
        
        @inlinable // lazy-performance
        internal init(_base: Base.Iterator, predicate: @escaping (Element) -> Bool) {
            self._base = _base
            self._predicate = predicate
        }
    }
}

/*
 如果, base sequence 里面取得的数据, 可以经过 _predicate 的检测, 那么就返回该数据, 如果不可以, 那么就终止条件.
 Sequence 里面的 prefix, 是有着固定的长度的, 而这里的, 则是通过闭包检测的.
 */
extension LazyPrefixWhileSequence.Iterator: IteratorProtocol, Sequence {
    @inlinable // lazy-performance
    public mutating func next() -> Element? {
        // Return elements from the base iterator until one fails the predicate.
        if !_predicateHasFailed, let nextElement = _base.next() {
            if _predicate(nextElement) {
                return nextElement
            } else {
                _predicateHasFailed = true
            }
        }
        return nil
    }
}

extension LazyPrefixWhileSequence: Sequence {
    @inlinable // lazy-performance
    public __consuming func makeIterator() -> Iterator {
        return Iterator(_base: _base.makeIterator(), predicate: _predicate)
    }
}

extension LazyPrefixWhileSequence: LazySequenceProtocol {
    public typealias Elements = LazyPrefixWhileSequence
}

/*
 暴露给外界使用的简便方法, 在方法的内部, 生成 LazyPrefixWhileSequence 对象.
 */
extension LazySequenceProtocol {
    @inlinable // lazy-performance
    public __consuming func prefix(
        while predicate: @escaping (Elements.Element) -> Bool
    ) -> LazyPrefixWhileSequence<Self.Elements> {
        return LazyPrefixWhileSequence(_base: self.elements, predicate: predicate)
    }
}

/// A lazy `${Collection}` wrapper that includes the initial consecutive
/// elements of an underlying collection that satisfy a predicate.
///
/// - Note: The performance of accessing `endIndex`, `last`, any methods that
///   depend on `endIndex`, or moving an index depends on how many elements
///   satisfy the predicate at the start of the collection, and may not offer
///   the usual performance given by the `Collection` protocol. Be aware,
///   therefore, that general operations on `${Self}` instances may not have
///   the documented complexity.
public typealias LazyPrefixWhileCollection<T: Collection> = LazyPrefixWhileSequence<T>

extension LazyPrefixWhileCollection {
    /// A position in the base collection of a `LazyPrefixWhileCollection` or the
    /// end of that collection.
    @frozen // lazy-performance
    @usableFromInline
    internal enum _IndexRepresentation {
        case index(Base.Index)
        case pastEnd
    }
    
    /// A position in a `LazyPrefixWhileCollection` or
    /// `LazyPrefixWhileBidirectionalCollection` instance.
    @frozen // lazy-performance
    public struct Index {
        /// The position corresponding to `self` in the underlying collection.
        @usableFromInline // lazy-performance
        internal let _value: _IndexRepresentation
        
        /// Creates a new index wrapper for `i`.
        @inlinable // lazy-performance
        internal init(_ i: Base.Index) {
            self._value = .index(i)
        }
        
        /// Creates a new index that can represent the `endIndex` of a
        /// `LazyPrefixWhileCollection<Base>`. This is not the same as a wrapper
        /// around `Base.endIndex`.
        @inlinable // lazy-performance
        internal init(endOf: Base) {
            self._value = .pastEnd
        }
    }
}

// FIXME: should work on the typealias
extension LazyPrefixWhileSequence.Index: Comparable where Base: Collection {
    @inlinable // lazy-performance
    public static func == (
        lhs: LazyPrefixWhileCollection<Base>.Index,
        rhs: LazyPrefixWhileCollection<Base>.Index
    ) -> Bool {
        switch (lhs._value, rhs._value) {
        case let (.index(l), .index(r)):
            return l == r
        case (.pastEnd, .pastEnd):
            return true
        case (.pastEnd, .index), (.index, .pastEnd):
            return false
        }
    }
    
    @inlinable // lazy-performance
    public static func < (
        lhs: LazyPrefixWhileCollection<Base>.Index,
        rhs: LazyPrefixWhileCollection<Base>.Index
    ) -> Bool {
        switch (lhs._value, rhs._value) {
        case let (.index(l), .index(r)):
            return l < r
        case (.index, .pastEnd):
            return true
        case (.pastEnd, _):
            return false
        }
    }
}

// FIXME: should work on the typealias
extension LazyPrefixWhileSequence.Index: Hashable where Base.Index: Hashable, Base: Collection {
    /// Hashes the essential components of this value by feeding them into the
    /// given hasher.
    ///
    /// - Parameter hasher: The hasher to use when combining the components
    ///   of this instance.
    @inlinable
    public func hash(into hasher: inout Hasher) {
        switch _value {
        case .index(let value):
            hasher.combine(value)
        case .pastEnd:
            hasher.combine(Int.max)
        }
    }
}

extension LazyPrefixWhileCollection: Collection {
    public typealias SubSequence = Slice<LazyPrefixWhileCollection<Base>>
    
    @inlinable // lazy-performance
    public var startIndex: Index {
        return Index(_base.startIndex)
    }
    
    @inlinable // lazy-performance
    public var endIndex: Index {
        // If the first element of `_base` satisfies the predicate, there is at
        // least one element in the lazy collection: Use the explicit `.pastEnd` index.
        if let first = _base.first, _predicate(first) {
            return Index(endOf: _base)
        }
        
        // `_base` is either empty or `_predicate(_base.first!) == false`. In either
        // case, the lazy collection is empty, so `endIndex == startIndex`.
        return startIndex
    }
    
    @inlinable // lazy-performance
    public func index(after i: Index) -> Index {
        _precondition(i != endIndex, "Can't advance past endIndex")
        guard case .index(let i) = i._value else {
            _preconditionFailure("Invalid index passed to index(after:)")
        }
        let nextIndex = _base.index(after: i)
        guard nextIndex != _base.endIndex && _predicate(_base[nextIndex]) else {
            return Index(endOf: _base)
        }
        return Index(nextIndex)
    }
    
    @inlinable // lazy-performance
    public subscript(position: Index) -> Element {
        switch position._value {
        case .index(let i):
            return _base[i]
        case .pastEnd:
            _preconditionFailure("Index out of range")
        }
    }
}

extension LazyPrefixWhileCollection: LazyCollectionProtocol { }

extension LazyPrefixWhileCollection: BidirectionalCollection
where Base: BidirectionalCollection {
    @inlinable // lazy-performance
    public func index(before i: Index) -> Index {
        switch i._value {
        case .index(let i):
            _precondition(i != _base.startIndex, "Can't move before startIndex")
            return Index(_base.index(before: i))
        case .pastEnd:
            // Look for the position of the last element in a non-empty
            // prefix(while:) collection by searching forward for a predicate
            // failure.
            
            // Safe to assume that `_base.startIndex != _base.endIndex`; if they
            // were equal, `_base.startIndex` would be used as the `endIndex` of
            // this collection.
            _internalInvariant(!_base.isEmpty)
            var result = _base.startIndex
            while true {
                let next = _base.index(after: result)
                if next == _base.endIndex || !_predicate(_base[next]) {
                    break
                }
                result = next
            }
            return Index(result)
        }
    }
}
