// A sequence of pairs built out of two underlying sequences.
// 通过一个函数, 来返回背后隐藏的数据类型.
// 这是一个便捷函数, 但是, 函数能够更好的进行类型推导, 显式地要求使用者去调用某个类型的构造函数代价又太大. 所以, 这个函数是很有必要的.
// C++ 里面有很多这种函数, 例如, Binder
@inlinable
public func zip<Sequence1, Sequence2>(
    _ sequence1: Sequence1, _ sequence2: Sequence2
) -> Zip2Sequence<Sequence1, Sequence2> {
    return Zip2Sequence(sequence1, sequence2)
}

/// A sequence of pairs built out of two underlying sequences.
///
/// In a `Zip2Sequence` instance, the elements of the *i*th pair are the *i*th
/// elements of each underlying sequence. To create a `Zip2Sequence` instance,
/// use the `zip(_:_:)` function.
///
/// The following example uses the `zip(_:_:)` function to iterate over an
/// array of strings and a countable range at the same time:
///
///     let words = ["one", "two", "three", "four"]
///     let numbers = 1...4
///
///     for (word, number) in zip(words, numbers) {
///         print("\(word): \(number)")
///     }
///     // Prints "one: 1"
///     // Prints "two: 2
///     // Prints "three: 3"
///     // Prints "four: 4"
@frozen // generic-performance
public struct Zip2Sequence<Sequence1: Sequence, Sequence2: Sequence> {
    @usableFromInline // generic-performance
    internal let _sequence1: Sequence1
    @usableFromInline // generic-performance
    internal let _sequence2: Sequence2
    
    /// Creates an instance that makes pairs of elements from `sequence1` and
    /// `sequence2`.
    @inlinable // generic-performance
    internal init(_ sequence1: Sequence1, _ sequence2: Sequence2) {
        // 实际上, 就是把传入的两个序列, 存起来了.
        (_sequence1, _sequence2) = (sequence1, sequence2)
    }
}

// 迭代器, 也是返回一个包裹着两个 base Sequence 的迭代器.
// 这里, 迭代器的类型定义在一个 extension 里面,  迭代器对于协议的支持, 在另外的一个 extension 里面.
extension Zip2Sequence {
    /// An iterator for `Zip2Sequence`.
    @frozen // generic-performance
    public struct Iterator {
        @usableFromInline // generic-performance
        internal var _baseStream1: Sequence1.Iterator
        @usableFromInline // generic-performance
        internal var _baseStream2: Sequence2.Iterator
        @usableFromInline // generic-performance
        internal var _reachedEnd: Bool = false
        
        /// Creates an instance around a pair of underlying iterators.
        @inlinable // generic-performance
        internal init(
            _ iterator1: Sequence1.Iterator,
            _ iterator2: Sequence2.Iterator
        ) {
            (_baseStream1, _baseStream2) = (iterator1, iterator2)
        }
    }
}

// 迭代器, 返回的 ele, 是 base sequence 的 ele 的组合.
extension Zip2Sequence.Iterator: IteratorProtocol {
    /// The type of element returned by `next()`.
    public typealias Element = (Sequence1.Element, Sequence2.Element)
    
    /// Advances to the next element and returns it, or `nil` if no next element
    /// exists.
    ///
    /// Once `nil` has been returned, all subsequent calls return `nil`.
    @inlinable // generic-performance
    public mutating func next() -> Element? {
        // The next() function needs to track if it has reached the end.  If we
        // didn't, and the first sequence is longer than the second, then when we
        // have already exhausted the second sequence, on every subsequent call to
        // next() we would consume and discard one additional element from the
        // first sequence, even though next() had already returned nil.
        
        if _reachedEnd {
            return nil
        }
        
        guard let element1 = _baseStream1.next(),
              let element2 = _baseStream2.next() else {
            _reachedEnd = true
            return nil
        }
        
        return (element1, element2)
    }
}

// 所有的, 应该说大部分的功能, 还是 Sequence 里面定义的, 而 Zip2Sequence 仅仅需要的就是, 实现一些 sequence 的 primitive 限制, 就可以自动的继承 map 这些功能. 这就是面向协议编程.
extension Zip2Sequence: Sequence {
    public typealias Element = (Sequence1.Element, Sequence2.Element)
    
    /// Returns an iterator over the elements of this sequence.
    @inlinable // generic-performance
    public __consuming func makeIterator() -> Iterator {
        return Iterator(
            _sequence1.makeIterator(),
            _sequence2.makeIterator())
    }
    
    @inlinable // generic-performance
    public var underestimatedCount: Int {
        return Swift.min(
            _sequence1.underestimatedCount,
            _sequence2.underestimatedCount
        )
    }
}
