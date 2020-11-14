/// A sequence that presents the elements of a base sequence of sequences
/// concatenated using a given separator.
@frozen // lazy-performance
public struct JoinedSequence<Base: Sequence> where Base.Element: Sequence {
    
    public typealias Element = Base.Element.Element
    
    @usableFromInline // lazy-performance
    internal var _base: Base
    @usableFromInline // lazy-performance
    internal var _separator: ContiguousArray<Element>
    
    @inlinable // lazy-performance
    public init<Separator: Sequence>(base: Base, separator: Separator)
        where Separator.Element == Element {
            self._base = base
            self._separator = ContiguousArray(separator) // 在这里, 把 Separator, 主动的变换成为了数组.
    }
}

extension JoinedSequence {
    /// An iterator that presents the elements of the sequences traversed
    /// by a base iterator, concatenated using a given separator./*
    /// 类的定义, 只有类型定义, 和成员变量信息
    @frozen // lazy-performance
    public struct Iterator {
        @usableFromInline // lazy-performance
        internal var _base: Base.Iterator
        @usableFromInline // lazy-performance
        internal var _inner: Base.Element.Iterator?
        @usableFromInline // lazy-performance
        internal var _separatorData: ContiguousArray<Element>
        @usableFromInline // lazy-performance
        internal var _separator: ContiguousArray<Element>.Iterator?
        
        /*
         和自己相关的定义, 定义在结构体内, 如何使用, 在方法内.
         把状态, 交给一个特定的枚举来管理.
         */
        @frozen // lazy-performance
        @usableFromInline // lazy-performance
        internal enum _JoinIteratorState {
            case start
            case generatingElements
            case generatingSeparator
            case end
        }
        @usableFromInline // lazy-performance
        internal var _state: _JoinIteratorState = .start // 默认是 start
        
        /// Creates a sequence that presents the elements of `base` sequences
        /// concatenated using `separator`.
        ///
        /// - Complexity: O(`separator.count`).
        @inlinable // lazy-performance
        public init<Separator: Sequence>(base: Base.Iterator, separator: Separator)
            where Separator.Element == Element {
                self._base = base
                self._separatorData = ContiguousArray(separator)
        }
    }
}

extension JoinedSequence.Iterator: IteratorProtocol {
    public typealias Element = Base.Element.Element
    
    /*
     这里 之所以 设计的这么复杂, 主要是因为, elements 里面, 是一个数组, 数组里面才是数据.
     Seperator 也是个数组, 数据里面数分割符.
     这里可以看成是状态的切换.
     */
    @inlinable // lazy-performance
    public mutating func next() -> Element? {
        while true {
            switch _state {
            case .start:
                if let nextSubSequence = _base.next() {
                    _inner = nextSubSequence.makeIterator()
                    _state = .generatingElements
                    /*
                     变换成, 生产数据.
                     */
                } else {
                    _state = .end
                    return nil
                }
                
            case .generatingElements:
                let result = _inner!.next()
                if _fastPath(result != nil) {
                    return result
                }
                /*
                 一个base数组完了, 判断后续还有没有, 没有的话, 提前退出.
                 */
                _inner = _base.next()?.makeIterator()
                if _inner == nil {
                    _state = .end
                    return nil
                }
                /*
                 切换成为生产分隔符.
                 */
                if !_separatorData.isEmpty {
                    _separator = _separatorData.makeIterator()
                    _state = .generatingSeparator
                }
                
            case .generatingSeparator:
                let result = _separator!.next()
                if _fastPath(result != nil) {
                    return result
                }
                _state = .generatingElements
                
            case .end:
                return nil
            }
        }
    }
}

extension JoinedSequence: Sequence {
    /// Return an iterator over the elements of this sequence.
    ///
    /// - Complexity: O(1).
    @inlinable // lazy-performance
    public __consuming func makeIterator() -> Iterator {
        return Iterator(base: _base.makeIterator(), separator: _separator)
    }
    
    /*
     里面的逻辑其实很简单, 就是两个循环而已.
     */
    @inlinable // lazy-performance
    public __consuming func _copyToContiguousArray() -> ContiguousArray<Element> {
        
        var result = ContiguousArray<Element>()
        let separatorSize = _separator.count
        
        if separatorSize == 0 {
            for x in _base {
                result.append(contentsOf: x)
            }
            return result
        }
        
         
        var iter = _base.makeIterator()
        if let first = iter.next() {
            result.append(contentsOf: first)
            while let next = iter.next() {
                result.append(contentsOf: _separator)
                result.append(contentsOf: next)
            }
        }
        
        return result
    }
}

/*
 所以, Join 这个函数, 本身 separator 就是一个 Sequence, 所以在内部, 有了那么多考
 */
extension Sequence where Element: Sequence {
    ///     let nestedNumbers = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    ///     let joined = nestedNumbers.joined(separator: [-1, -2])
    ///     print(Array(joined))
    ///     // Prints "[1, 2, 3, -1, -2, 4, 5, 6, -1, -2, 7, 8, 9]"
    ///
    @inlinable // lazy-performance
    public __consuming func joined<Separator: Sequence>(
        separator: Separator
    ) -> JoinedSequence<Self>
        where Separator.Element == Element.Element {
            return JoinedSequence(base: self, separator: separator)
    }
}
