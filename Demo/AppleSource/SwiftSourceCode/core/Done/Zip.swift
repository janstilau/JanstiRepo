/*
 这个方法, 会产生一个新的序列, 这个序列的内部, 每一个元素, 都是由相应位置的原始序列抽取出来的数据的pair.
 在简单的方法里面, 这么命名没有做, 1, 2, 不过, 还是 lhs, rhs 更加通用一点.
 */
@inlinable // generic-performance
public func zip<Sequence1, Sequence2>(
    _ sequence1: Sequence1, _ sequence2: Sequence2
) -> Zip2Sequence<Sequence1, Sequence2> {
    return Zip2Sequence(sequence1, sequence2)
}

/*
 Zip2Sequence 中, 有着对于原始序列的存储.
 */
@frozen // generic-performance
public struct Zip2Sequence<Sequence1: Sequence, Sequence2: Sequence> {
    @usableFromInline // generic-performance
    internal let _sequence1: Sequence1
    @usableFromInline // generic-performance
    internal let _sequence2: Sequence2
    @inlinable // generic-performance
    internal init(_ sequence1: Sequence1, _ sequence2: Sequence2) {
        /*
         通过元组这种方式赋值, 在这个类基本不会有修改的时候, 是很优雅的做法.
         */
        (_sequence1, _sequence2) = (sequence1, sequence2)
    }
}

/*
 Zip 的 iterator, 存储着原始序列的 iterator.
 对于这种成块出现的元素, 用这种 tuple 方式进行赋值, 可以确保, 一改都改.
 */
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
        @inlinable // generic-performance
        internal init(
            _ iterator1: Sequence1.Iterator,
            _ iterator2: Sequence2.Iterator
        ) {
            (_baseStream1, _baseStream2) = (iterator1, iterator2)
        }
    }
}

extension Zip2Sequence.Iterator: IteratorProtocol {
    public typealias Element = (Sequence1.Element, Sequence2.Element)
    
    /*
     可以在一个迭代器上, 无限的调用 next 不出错, 只是最后的返回值是 nil.
     */
    @inlinable // generic-performance
    public mutating func next() -> Element? {
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
