// 通过一个函数, 来返回背后隐藏的数据类型.
// 这是一个便捷函数, 但是, 函数能够更好的进行类型推导, 显式地要求使用者去调用某个类型的构造函数代价又太大. 所以, 这个函数是很有必要的.
// C++ 里面有很多这种函数, 例如, Binder
@inlinable
public func zip<Sequence1, Sequence2>(
    _ sequence1: Sequence1, _ sequence2: Sequence2
) -> Zip2Sequence<Sequence1, Sequence2> {
    return Zip2Sequence(sequence1, sequence2)
}

public struct Zip2Sequence<Sequence1: Sequence, Sequence2: Sequence> {
    internal let _sequence1: Sequence1
    internal let _sequence2: Sequence2
    internal init(_ sequence1: Sequence1, _ sequence2: Sequence2) {
        (_sequence1, _sequence2) = (sequence1, sequence2)
    }
}

// 迭代器, 也是返回一个包裹着两个 base Sequence 的迭代器.
// 这里, 迭代器的类型定义在一个 extension 里面,  迭代器对于协议的支持, 在另外的一个 extension 里面.
extension Zip2Sequence {
    public struct Iterator {
        internal var _baseStream1: Sequence1.Iterator
        internal var _baseStream2: Sequence2.Iterator
        internal var _reachedEnd: Bool = false // 专门一个 bool 来记录是否应该结束, 计算属性也可以, 但是效率不高.
        
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
    public typealias Element = (Sequence1.Element, Sequence2.Element)
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

// 所有的, 应该说大部分的功能, 还是 Sequence 里面定义的, 而 Zip2Sequence 仅仅需要的就是, 实现一些 sequence 的 primitive 限制, 就可以自动的继承 map 这些功能. 这就是面向协议编程.
extension Zip2Sequence: Sequence {
    public typealias Element = (Sequence1.Element, Sequence2.Element)
    public __consuming func makeIterator() -> Iterator {
        return Iterator(
            _sequence1.makeIterator(),
            _sequence2.makeIterator())
    }
    
    public var underestimatedCount: Int {
        return Swift.min(
            _sequence1.underestimatedCount,
            _sequence2.underestimatedCount
        )
    }
}
