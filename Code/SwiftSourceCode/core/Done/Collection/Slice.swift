/*
 Slice 真正的, 仅仅是记录三个值
 slice 的 startIndex
 slice 的 endIndex
 slice 的 originalBaseCollection
 
 切片最好还是临时使用, 不要当做存储来进行. 因为切片其实会有着原始 Collection 的强引用的, 导致原始的 Collection 不会被释放.
 就好像迭代器一样, 这些都是临时使用的概念, 都应该是临时使用的, 不应该在当前逻辑单元外进行使用.
 */

@frozen
public struct Slice<Base: Collection> {
    public var _startIndex: Base.Index
    public var _endIndex: Base.Index
    @usableFromInline
    internal var _base: Base
    
    @inlinable
    public init(base: Base, bounds: Range<Base.Index>) {
        self._base = base // 对于原始值的引用.
        self._startIndex = bounds.lowerBound
        self._endIndex = bounds.upperBound
    }
    @inlinable // generic-performance
    public var base: Base {
        return _base
    }
}

/*
 Slice 里面的 startIndex 和 endIndex, 都是自己的, 而不是 base 的.
 所以, Slice 仅仅是对于原始的 base 做了一层范围上的限制而已.
 */
extension Slice: Collection {
    public typealias Index = Base.Index
    public typealias Indices = Base.Indices
    public typealias Element = Base.Element
    public typealias SubSequence = Slice<Base>
    public typealias Iterator = IndexingIterator<Slice<Base>>
    
    /*
     startIndex 没有用 base 的 startIndex, 而是使用的自己的
     */
    @inlinable // generic-performance
    public var startIndex: Index {
        return _startIndex
    }
    /*
     endIndex 没有用 base 的 endIndex, 而是使用的自己的
     */
    @inlinable // generic-performance
    public var endIndex: Index {
        return _endIndex
    }
    /*
     最终还是使用的 base 的功能, 但是做了自己 startIndex, endIndex 的判断工作.
     */
    @inlinable // generic-performance
    public subscript(index: Index) -> Base.Element {
        get {
            _failEarlyRangeCheck(index, bounds: startIndex..<endIndex)
            return _base[index]
        }
    }
    
    @inlinable // generic-performance
    public subscript(bounds: Range<Index>) -> Slice<Base> {
        get {
            _failEarlyRangeCheck(bounds, bounds: startIndex..<endIndex)
            return Slice(base: _base, bounds: bounds)
        }
    }
    
    /*
     所有的, 关于 index 的操作, 都是交给了 base.
     Slice 仅仅是提供一个切割的概念而已.
     这里, 返回的 indices, 是 _base.indices 里面, slice 的 start, end 圈住的那一部分.
     */
    public var indices: Indices {
        return _base.indices[_startIndex..<_endIndex]
    }
    
    /*
     剩下的所有的一切, 都转交给 base 进行处理.
     因为 Slice 本身是不知道自己的 Index 是如何进行改变的. 所以, 存储 base 是一个必要的事情.
     */
    @inlinable // generic-performance
    public func index(after i: Index) -> Index {
        return _base.index(after: i)
    }
    
    @inlinable // generic-performance
    public func formIndex(after i: inout Index) {
        _base.formIndex(after: &i)
    }
    
    @inlinable // generic-performance
    public func index(_ i: Index, offsetBy n: Int) -> Index {
        return _base.index(i, offsetBy: n)
    }
    
    @inlinable // generic-performance
    public func index(
        _ i: Index, offsetBy n: Int, limitedBy limit: Index
    ) -> Index? {
        return _base.index(i, offsetBy: n, limitedBy: limit)
    }
    
    @inlinable // generic-performance
    public func distance(from start: Index, to end: Index) -> Int {
        return _base.distance(from: start, to: end)
    }
    
    @inlinable // generic-performance
    public func _failEarlyRangeCheck(_ index: Index, bounds: Range<Index>) {
        _base._failEarlyRangeCheck(index, bounds: bounds)
    }
    
    @inlinable // generic-performance
    public func _failEarlyRangeCheck(_ range: Range<Index>, bounds: Range<Index>) {
        _base._failEarlyRangeCheck(range, bounds: bounds)
    }
}

/*
 增加对于 BidirectionalCollection 的适配.
 还是交给了 base, 因为实际上并不是 Slice 可以 Bidirectional, 而是 base 可以 Bidirectional, 然后 Slice 自动就获取该功能.
 */
extension Slice: BidirectionalCollection where Base: BidirectionalCollection {
    @inlinable // generic-performance
    public func index(before i: Index) -> Index {
        // FIXME: swift-3-indexing-model: range check.
        return _base.index(before: i)
    }
    
    @inlinable // generic-performance
    public func formIndex(before i: inout Index) {
        // FIXME: swift-3-indexing-model: range check.
        _base.formIndex(before: &i)
    }
}

/*
 所有的关于 mutable 的操作, 都是交给了 base. Slice 仅仅是做了一层范围的检查而已.
 */
extension Slice: MutableCollection where Base: MutableCollection {
    @inlinable // generic-performance
    public subscript(index: Index) -> Base.Element {
        get {
            _failEarlyRangeCheck(index, bounds: startIndex..<endIndex)
            return _base[index]
        }
        set {
            _failEarlyRangeCheck(index, bounds: startIndex..<endIndex)
            _base[index] = newValue
        }
    }
    
    @inlinable // generic-performance
    public subscript(bounds: Range<Index>) -> Slice<Base> {
        get {
            _failEarlyRangeCheck(bounds, bounds: startIndex..<endIndex)
            return Slice(base: _base, bounds: bounds)
        }
        set {
            _writeBackMutableSlice(&self, bounds: bounds, slice: newValue)
        }
    }
}

extension Slice: RandomAccessCollection where Base: RandomAccessCollection { }

extension Slice: RangeReplaceableCollection
where Base: RangeReplaceableCollection {
    @inlinable // generic-performance
    public init() {
        self._base = Base()
        self._startIndex = _base.startIndex
        self._endIndex = _base.endIndex
    }
    
    @inlinable // generic-performance
    public init(repeating repeatedValue: Base.Element, count: Int) {
        self._base = Base(repeating: repeatedValue, count: count)
        self._startIndex = _base.startIndex
        self._endIndex = _base.endIndex
    }
    
    @inlinable // generic-performance
    public init<S>(_ elements: S) where S: Sequence, S.Element == Base.Element {
        self._base = Base(elements)
        self._startIndex = _base.startIndex
        self._endIndex = _base.endIndex
    }
    
    @inlinable // generic-performance
    public mutating func replaceSubrange<C>(
        _ subRange: Range<Index>, with newElements: C
    ) where C: Collection, C.Element == Base.Element {
        // FIXME: swift-3-indexing-model: range check.
        let sliceOffset =
            _base.distance(from: _base.startIndex, to: _startIndex)
        let newSliceCount =
            _base.distance(from: _startIndex, to: subRange.lowerBound)
                + _base.distance(from: subRange.upperBound, to: _endIndex)
                + (numericCast(newElements.count) as Int)
        /*
         _base 的内部, 会做写时复制的操作. 所以, 在 _base.replaceSubrange 之后, _base, 以及原始值也就不一致了.
         */
        _base.replaceSubrange(subRange, with: newElements)
        _startIndex = _base.index(_base.startIndex, offsetBy: sliceOffset)
        _endIndex = _base.index(_startIndex, offsetBy: newSliceCount)
    }
    
    @inlinable // generic-performance
    public mutating func insert(_ newElement: Base.Element, at i: Index) {
        // FIXME: swift-3-indexing-model: range check.
        let sliceOffset = _base.distance(from: _base.startIndex, to: _startIndex)
        let newSliceCount = count + 1
        _base.insert(newElement, at: i)
        _startIndex = _base.index(_base.startIndex, offsetBy: sliceOffset)
        _endIndex = _base.index(_startIndex, offsetBy: newSliceCount)
    }
    
    @inlinable // generic-performance
    public mutating func insert<S>(contentsOf newElements: S, at i: Index)
        where S: Collection, S.Element == Base.Element {
            
            // FIXME: swift-3-indexing-model: range check.
            let sliceOffset = _base.distance(from: _base.startIndex, to: _startIndex)
            let newSliceCount = count + newElements.count
            _base.insert(contentsOf: newElements, at: i)
            _startIndex = _base.index(_base.startIndex, offsetBy: sliceOffset)
            _endIndex = _base.index(_startIndex, offsetBy: newSliceCount)
    }
    
    @inlinable // generic-performance
    public mutating func remove(at i: Index) -> Base.Element {
        // FIXME: swift-3-indexing-model: range check.
        let sliceOffset = _base.distance(from: _base.startIndex, to: _startIndex)
        let newSliceCount = count - 1
        let result = _base.remove(at: i)
        _startIndex = _base.index(_base.startIndex, offsetBy: sliceOffset)
        _endIndex = _base.index(_startIndex, offsetBy: newSliceCount)
        return result
    }
    
    @inlinable // generic-performance
    public mutating func removeSubrange(_ bounds: Range<Index>) {
        // FIXME: swift-3-indexing-model: range check.
        let sliceOffset = _base.distance(from: _base.startIndex, to: _startIndex)
        let newSliceCount =
            count - distance(from: bounds.lowerBound, to: bounds.upperBound)
        _base.removeSubrange(bounds)
        _startIndex = _base.index(_base.startIndex, offsetBy: sliceOffset)
        _endIndex = _base.index(_startIndex, offsetBy: newSliceCount)
    }
}

/*
 可以看到, 下面的所有的关于 rangeReplace 的方法, 都是调用的 base 的相关方法, 不过, Slice 的内部, 会及时的调整自己的 startIndex 和 endIndex
 */

extension Slice
where Base: RangeReplaceableCollection, Base: BidirectionalCollection {
    
    @inlinable // generic-performance
    public mutating func replaceSubrange<C>(
        _ subRange: Range<Index>, with newElements: C
    ) where C: Collection, C.Element == Base.Element {
        // FIXME: swift-3-indexing-model: range check.
        if subRange.lowerBound == _base.startIndex {
            let newSliceCount =
                _base.distance(from: _startIndex, to: subRange.lowerBound)
                    + _base.distance(from: subRange.upperBound, to: _endIndex)
                    + (numericCast(newElements.count) as Int)
            _base.replaceSubrange(subRange, with: newElements)
            _startIndex = _base.startIndex
            _endIndex = _base.index(_startIndex, offsetBy: newSliceCount)
        } else {
            let shouldUpdateStartIndex = subRange.lowerBound == _startIndex
            let lastValidIndex = _base.index(before: subRange.lowerBound)
            let newEndIndexOffset =
                _base.distance(from: subRange.upperBound, to: _endIndex)
                    + (numericCast(newElements.count) as Int) + 1
            _base.replaceSubrange(subRange, with: newElements)
            if shouldUpdateStartIndex {
                _startIndex = _base.index(after: lastValidIndex)
            }
            _endIndex = _base.index(lastValidIndex, offsetBy: newEndIndexOffset)
        }
    }
    
    @inlinable // generic-performance
    public mutating func insert(_ newElement: Base.Element, at i: Index) {
        // FIXME: swift-3-indexing-model: range check.
        if i == _base.startIndex {
            let newSliceCount = count + 1
            _base.insert(newElement, at: i)
            _startIndex = _base.startIndex
            _endIndex = _base.index(_startIndex, offsetBy: newSliceCount)
        } else {
            let shouldUpdateStartIndex = i == _startIndex
            let lastValidIndex = _base.index(before: i)
            let newEndIndexOffset = _base.distance(from: i, to: _endIndex) + 2
            _base.insert(newElement, at: i)
            if shouldUpdateStartIndex {
                _startIndex = _base.index(after: lastValidIndex)
            }
            _endIndex = _base.index(lastValidIndex, offsetBy: newEndIndexOffset)
        }
    }
    
    @inlinable // generic-performance
    public mutating func insert<S>(contentsOf newElements: S, at i: Index)
        where S: Collection, S.Element == Base.Element {
            // FIXME: swift-3-indexing-model: range check.
            if i == _base.startIndex {
                let newSliceCount = count + numericCast(newElements.count)
                _base.insert(contentsOf: newElements, at: i)
                _startIndex = _base.startIndex
                _endIndex = _base.index(_startIndex, offsetBy: newSliceCount)
            } else {
                let shouldUpdateStartIndex = i == _startIndex
                let lastValidIndex = _base.index(before: i)
                let newEndIndexOffset =
                    _base.distance(from: i, to: _endIndex)
                        + numericCast(newElements.count) + 1
                _base.insert(contentsOf: newElements, at: i)
                if shouldUpdateStartIndex {
                    _startIndex = _base.index(after: lastValidIndex)
                }
                _endIndex = _base.index(lastValidIndex, offsetBy: newEndIndexOffset)
            }
    }
    
    @inlinable // generic-performance
    public mutating func remove(at i: Index) -> Base.Element {
        // FIXME: swift-3-indexing-model: range check.
        if i == _base.startIndex {
            let newSliceCount = count - 1
            let result = _base.remove(at: i)
            _startIndex = _base.startIndex
            _endIndex = _base.index(_startIndex, offsetBy: newSliceCount)
            return result
        } else {
            let shouldUpdateStartIndex = i == _startIndex
            let lastValidIndex = _base.index(before: i)
            let newEndIndexOffset = _base.distance(from: i, to: _endIndex)
            let result = _base.remove(at: i)
            if shouldUpdateStartIndex {
                _startIndex = _base.index(after: lastValidIndex)
            }
            _endIndex = _base.index(lastValidIndex, offsetBy: newEndIndexOffset)
            return result
        }
    }
    
    @inlinable // generic-performance
    public mutating func removeSubrange(_ bounds: Range<Index>) {
        // FIXME: swift-3-indexing-model: range check.
        if bounds.lowerBound == _base.startIndex {
            let newSliceCount =
                count - _base.distance(from: bounds.lowerBound, to: bounds.upperBound)
            _base.removeSubrange(bounds)
            _startIndex = _base.startIndex
            _endIndex = _base.index(_startIndex, offsetBy: newSliceCount)
        } else {
            let shouldUpdateStartIndex = bounds.lowerBound == _startIndex
            let lastValidIndex = _base.index(before: bounds.lowerBound)
            let newEndIndexOffset =
                _base.distance(from: bounds.lowerBound, to: _endIndex)
                    - _base.distance(from: bounds.lowerBound, to: bounds.upperBound)
                    + 1
            _base.removeSubrange(bounds)
            if shouldUpdateStartIndex {
                _startIndex = _base.index(after: lastValidIndex)
            }
            _endIndex = _base.index(lastValidIndex, offsetBy: newEndIndexOffset)
        }
    }
}
