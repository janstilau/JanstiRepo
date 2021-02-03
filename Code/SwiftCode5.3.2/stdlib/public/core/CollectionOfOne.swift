/// A collection containing a single element.
///
/// You can use a `CollectionOfOne` instance when you need to efficiently
/// represent a single value as a collection. For example, you can add a
/// single element to an array by using a `CollectionOfOne` instance with the
/// concatenation operator (`+`):
///
///     let a = [1, 2, 3, 4]
///     let toAdd = 100
///     let b = a + CollectionOfOne(toAdd)
///     // b == [1, 2, 3, 4, 100]

// 这个类, 没有想出他的具体的作用是什么, 不过, 上面的示例倒是一个不错的使用场景.


// 因为, 这个类就是表示的是一个值, 所以, 它的数据就是这样一个值.
public struct CollectionOfOne<Element> {
    internal var _element: Element
    public init(_ element: Element) {
        self._element = element
    }
}

extension CollectionOfOne {
    /// An iterator that produces one or zero instances of an element.
    ///
    /// `IteratorOverOne` is the iterator for the `CollectionOfOne` type.
    @frozen // trivial-implementation
    public struct Iterator {
        @usableFromInline // trivial-implementation
        internal var _elements: Element?
        
        /// Construct an instance that generates `_element!`, or an empty
        /// sequence if `_element == nil`.
        @inlinable // trivial-implementation
        public // @testable
        init(_elements: Element?) {
            self._elements = _elements
        }
    }
}

// 对于 Sequence 的适配.
extension CollectionOfOne.Iterator: IteratorProtocol {
    @inlinable // trivial-implementation
    public mutating func next() -> Element? {
        let result = _elements
        _elements = nil
        return result
    }
}

// 对于 Collection 的适配.
extension CollectionOfOne: RandomAccessCollection, MutableCollection {
    
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public typealias SubSequence = Slice<CollectionOfOne<Element>>
    
    public var startIndex: Index {
        return 0
    }
    
    public var endIndex: Index {
        return 1
    }
    
    public func index(after i: Index) -> Index {
        _precondition(i == startIndex) // 参数, 必须是 0
        return 1
    }
    
    public func index(before i: Index) -> Index {
        _precondition(i == endIndex)
        return 0
    }
    
    /// Returns an iterator over the elements of this collection.
    ///
    /// - Complexity: O(1)
    @inlinable // trivial-implementation
    public __consuming func makeIterator() -> Iterator {
        return Iterator(_elements: _element)
    }
    
    /// Accesses the element at the specified position.
    ///
    /// - Parameter position: The position of the element to access. The only
    ///   valid position in a `CollectionOfOne` instance is `0`.
    @inlinable // trivial-implementation
    public subscript(position: Int) -> Element {
        _read {
            _precondition(position == 0, "Index out of range")
            yield _element
        }
        _modify {
            _precondition(position == 0, "Index out of range")
            yield &_element // ??? yield
        }
    }
    
    @inlinable // trivial-implementation
    public subscript(bounds: Range<Int>) -> SubSequence {
        get {
            _failEarlyRangeCheck(bounds, bounds: 0..<1)
            return Slice(base: self, bounds: bounds)
        }
        set {
            _failEarlyRangeCheck(bounds, bounds: 0..<1)
            let n = newValue.count
            _precondition(bounds.count == n, "CollectionOfOne can't be resized")
            if n == 1 { self = newValue.base }
        }
    }
    
    /// The number of elements in the collection, which is always one.
    @inlinable // trivial-implementation
    public var count: Int {
        return 1
    }
}

extension CollectionOfOne: CustomDebugStringConvertible {
    /// A textual representation of the collection, suitable for debugging.
    public var debugDescription: String {
        return "CollectionOfOne(\(String(reflecting: _element)))"
    }
}

extension CollectionOfOne: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(self, children: ["element": _element])
    }
}
