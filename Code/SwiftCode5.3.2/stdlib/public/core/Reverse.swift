// 这是一个 mutating 方法, 所以只能用到 var 上面.
// 实现的原理, 就是前后对调. 不过, 这里使用的是 Collection, 所以是通用的行为, 而不单单是 array.
extension MutableCollection where Self: BidirectionalCollection {
    public mutating func reverse() {
        if isEmpty { return }
        var f = startIndex
        var l = index(before: endIndex)
        while f < l {
            swapAt(f, l)
            formIndex(after: &f)
            formIndex(before: &l)
        }
    }
}

public struct ReversedCollection<Base: BidirectionalCollection> {
    public let _base: Base
    internal init(_base: Base) {
        self._base = _base
    }
}

extension ReversedCollection {
    // An iterator that can be much faster than the iterator of a reversed slice.
    @frozen
    public struct Iterator {
        @usableFromInline
        internal let _base: Base
        @usableFromInline
        internal var _position: Base.Index
        
        public /// @testable
        init(_base: Base) {
            self._base = _base
            // 上来记录一下 position 为最后的位置, 然后 next 的时候, 是向前进行迭代.
            self._position = _base.endIndex
        }
    }
}

extension ReversedCollection.Iterator: IteratorProtocol, Sequence {
    public typealias Element = Base.Element
    
    // 每次 Next 的时候, 是不断地使用 formIndex(before 去改变 _position 的值.
    public mutating func next() -> Element? {
        guard _fastPath(_position != _base.startIndex) else { return nil }
        _base.formIndex(before: &_position)
        return _base[_position]
    }
}

extension ReversedCollection: Sequence {
    public typealias Element = Base.Element
    
    @inlinable
    @inline(__always)
    public __consuming func makeIterator() -> Iterator {
        return Iterator(_base: _base)
    }
}

extension ReversedCollection {
    /// An index that traverses the same positions as an underlying index,
    /// with inverted traversal direction.
    @frozen
    public struct Index {
        /// The position after this position in the underlying collection.
        ///
        /// To find the position that corresponds with this index in the original,
        /// underlying collection, use that collection's `index(before:)` method
        /// with the `base` property.
        ///
        /// The following example declares a function that returns the index of the
        /// last even number in the passed array, if one is found. First, the
        /// function finds the position of the last even number as a `ReversedIndex`
        /// in a reversed view of the array of numbers. Next, the function calls the
        /// array's `index(before:)` method to return the correct position in the
        /// passed array.
        ///
        ///     func indexOfLastEven(_ numbers: [Int]) -> Int? {
        ///         let reversedNumbers = numbers.reversed()
        ///         guard let i = reversedNumbers.firstIndex(where: { $0 % 2 == 0 })
        ///             else { return nil }
        ///
        ///         return numbers.index(before: i.base)
        ///     }
        ///
        ///     let numbers = [10, 20, 13, 19, 30, 52, 17, 40, 51]
        ///     if let lastEven = indexOfLastEven(numbers) {
        ///         print("Last even number: \(numbers[lastEven])")
        ///     }
        ///     // Prints "Last even number: 40"
        public let base: Base.Index
        
        /// Creates a new index into a reversed collection for the position before
        /// the specified index.
        ///
        /// When you create an index into a reversed collection using `base`, an
        /// index from the underlying collection, the resulting index is the
        /// position of the element *before* the element referenced by `base`. The
        /// following example creates a new `ReversedIndex` from the index of the
        /// `"a"` character in a string's character view.
        ///
        ///     let name = "Horatio"
        ///     let aIndex = name.firstIndex(of: "a")!
        ///     // name[aIndex] == "a"
        ///
        ///     let reversedName = name.reversed()
        ///     let i = ReversedIndex<String>(aIndex)
        ///     // reversedName[i] == "r"
        ///
        /// The element at the position created using `ReversedIndex<...>(aIndex)` is
        /// `"r"`, the character before `"a"` in the `name` string.
        ///
        /// - Parameter base: The position after the element to create an index for.
        @inlinable
        public init(_ base: Base.Index) {
            self.base = base
        }
    }
}

extension ReversedCollection.Index: Comparable {
    @inlinable
    public static func == (
        lhs: ReversedCollection<Base>.Index,
        rhs: ReversedCollection<Base>.Index
    ) -> Bool {
        return lhs.base == rhs.base
    }
    
    @inlinable
    public static func < (
        lhs: ReversedCollection<Base>.Index,
        rhs: ReversedCollection<Base>.Index
    ) -> Bool {
        // Note ReversedIndex has inverted logic compared to base Base.Index
        return lhs.base > rhs.base
    }
}

extension ReversedCollection.Index: Hashable where Base.Index: Hashable {
    /// Hashes the essential components of this value by feeding them into the
    /// given hasher.
    ///
    /// - Parameter hasher: The hasher to use when combining the components
    ///   of this instance.
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(base)
    }
}

extension ReversedCollection: BidirectionalCollection {  
    @inlinable
    public var startIndex: Index {
        return Index(_base.endIndex)
    }
    
    @inlinable
    public var endIndex: Index {
        return Index(_base.startIndex)
    }
    
    @inlinable
    public func index(after i: Index) -> Index {
        return Index(_base.index(before: i.base))
    }
    
    @inlinable
    public func index(before i: Index) -> Index {
        return Index(_base.index(after: i.base))
    }
    
    @inlinable
    public func index(_ i: Index, offsetBy n: Int) -> Index {
        // FIXME: swift-3-indexing-model: `-n` can trap on Int.min.
        return Index(_base.index(i.base, offsetBy: -n))
    }
    
    @inlinable
    public func index(
        _ i: Index, offsetBy n: Int, limitedBy limit: Index
    ) -> Index? {
        // FIXME: swift-3-indexing-model: `-n` can trap on Int.min.
        return _base.index(i.base, offsetBy: -n, limitedBy: limit.base)
            .map(Index.init)
    }
    
    @inlinable
    public func distance(from start: Index, to end: Index) -> Int {
        return _base.distance(from: end.base, to: start.base)
    }
    
    @inlinable
    public subscript(position: Index) -> Element {
        return _base[_base.index(before: position.base)]
    }
}

extension ReversedCollection: RandomAccessCollection where Base: RandomAccessCollection { }

extension ReversedCollection {
    /// Reversing a reversed collection returns the original collection.
    ///
    /// - Complexity: O(1)
    @inlinable
    @available(swift, introduced: 4.2)
    public __consuming func reversed() -> Base {
        return _base
    }
}

extension BidirectionalCollection {
    /// Returns a view presenting the elements of the collection in reverse
    /// order.
    ///
    /// You can reverse a collection without allocating new space for its
    /// elements by calling this `reversed()` method. A `ReversedCollection`
    /// instance wraps an underlying collection and provides access to its
    /// elements in reverse order. This example prints the characters of a
    /// string in reverse order:
    ///
    ///     let word = "Backwards"
    ///     for char in word.reversed() {
    ///         print(char, terminator: "")
    ///     }
    ///     // Prints "sdrawkcaB"
    ///
    /// If you need a reversed collection of the same type, you may be able to
    /// use the collection's sequence-based or collection-based initializer. For
    /// example, to get the reversed version of a string, reverse its
    /// characters and initialize a new `String` instance from the result.
    ///
    ///     let reversedWord = String(word.reversed())
    ///     print(reversedWord)
    ///     // Prints "sdrawkcaB"
    ///
    /// - Complexity: O(1)
    @inlinable
    public __consuming func reversed() -> ReversedCollection<Self> {
        return ReversedCollection(_base: self)
    }
}
