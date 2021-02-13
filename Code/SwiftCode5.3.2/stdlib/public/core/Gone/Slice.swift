// 对于 Slice, 他实际上, 就是记录一下 start, end, 还有原始的 collection.
// 但是, 因为记录了原始的 collection 了, 他就有了非常多的能力, 这些能力, 都是建立在 Collection 能力的基础上的.
public struct Slice<Base: Collection> {
    // 使用 Base 来命名, 底层的数据类型, 是一个非常非常通用的做法.
    public var _startIndex: Base.Index
    public var _endIndex: Base.Index
    internal var _base: Base
    
    public init(base: Base, bounds: Range<Base.Index>) {
        self._base = base
        self._startIndex = bounds.lowerBound
        self._endIndex = bounds.upperBound
    }
    
    public var base: Base {
        return _base
    }
}

extension Slice: Collection {
    public typealias Index = Base.Index
    public typealias Indices = Base.Indices
    public typealias Element = Base.Element
    public typealias SubSequence = Slice<Base>
    public typealias Iterator = IndexingIterator<Slice<Base>>
    
    // StartIndex 不在是 Base 的, 而是 Slice 所记录的
    public var startIndex: Index {
        return _startIndex
    }
    
    // EndIndex 不在是 Base 的, 而是 Slice 所记录的
    public var endIndex: Index {
        return _endIndex
    }
    
    // 获取值的函数, 是直接获取 Base 里面的值.
    // 所以, Slice 和 Collection 共用一套 index, 其实是更加方便.
    public subscript(index: Index) -> Base.Element {
        get {
            return _base[index]
        }
    }
    
    // 直接使用 base 来获取所要的数据.
    public subscript(bounds: Range<Index>) -> Slice<Base> {
        get {
            // 这里, 范围一定是要和当前 slice 记录的 Start,End 进行比较.
            _failEarlyRangeCheck(bounds, bounds: startIndex..<endIndex)
            return Slice(base: _base, bounds: bounds)
        }
    }
    
    // 直接, 截取 _base 的 indices 的一部分.
    public var indices: Indices {
        return _base.indices[_startIndex..<_endIndex]
    }
    
    // 直接使用 base 做 index 的计算
    public func index(after i: Index) -> Index {
        return _base.index(after: i)
    }
    
    // 直接使用 base 做 index 的计算
    public func formIndex(after i: inout Index) {
        // FIXME: swift-3-indexing-model: range check.
        _base.formIndex(after: &i)
    }
    
    // 直接使用 base 做 index 的计算
    public func index(_ i: Index, offsetBy n: Int) -> Index {
        // FIXME: swift-3-indexing-model: range check.
        return _base.index(i, offsetBy: n)
    }
    
    // 直接使用 base 做 index 的计算
    public func index(
        _ i: Index, offsetBy n: Int, limitedBy limit: Index
    ) -> Index? {
        return _base.index(i, offsetBy: n, limitedBy: limit)
    }
    
    // 直接使用 base 做 index 的计算
    public func distance(from start: Index, to end: Index) -> Int {
        // FIXME: swift-3-indexing-model: range check.
        return _base.distance(from: start, to: end)
    }
    
    public func _failEarlyRangeCheck(_ index: Index, bounds: Range<Index>) {
        _base._failEarlyRangeCheck(index, bounds: bounds)
    }
    
    @inlinable // generic-performance
    public func _failEarlyRangeCheck(_ range: Range<Index>, bounds: Range<Index>) {
        _base._failEarlyRangeCheck(range, bounds: bounds)
    }
    
    @_alwaysEmitIntoClient @inlinable
    public func withContiguousStorageIfAvailable<R>(
        _ body: (UnsafeBufferPointer<Element>) throws -> R
    ) rethrows -> R? {
        try _base.withContiguousStorageIfAvailable { buffer in
            let start = _base.distance(from: _base.startIndex, to: _startIndex)
            let count = _base.distance(from: _startIndex, to: _endIndex)
            let slice = UnsafeBufferPointer(rebasing: buffer[start ..< start + count])
            return try body(slice)
        }
    }
}

// 只要, Base 是双向的, 那么 Slice 就是双向的.
extension Slice: BidirectionalCollection where Base: BidirectionalCollection {
    public func index(before i: Index) -> Index {
        return _base.index(before: i)
    }
    
    public func formIndex(before i: inout Index) {
        _base.formIndex(before: &i)
    }
}


// 只要 Base 是可变的, 那么 Slice 就是可变的.
extension Slice: MutableCollection where Base: MutableCollection {
    @inlinable // generic-performance
    public subscript(index: Index) -> Base.Element {
        get {
            return _base[index]
        }
        // 这里, 直接使用的 _Base 的 subscript set. 所以, 只要 Base 实现了写时复制, Slice 自动就能出发.
        set {
            _base[index] = newValue
        }
    }
    
    public subscript(bounds: Range<Index>) -> Slice<Base> {
        get {
            return Slice(base: _base, bounds: bounds)
        }
        set {
            _writeBackMutableSlice(&self, bounds: bounds, slice: newValue)
        }
    }
    
    public mutating func withContiguousMutableStorageIfAvailable<R>(
        _ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R
    ) rethrows -> R? {
        // We're calling `withContiguousMutableStorageIfAvailable` twice here so
        // that we don't calculate index distances unless we know we'll use them.
        // The expectation here is that the base collection will make itself
        // contiguous on the first try and the second call will be relatively cheap.
        guard _base.withContiguousMutableStorageIfAvailable({ _ in }) != nil
        else {
            return nil
        }
        
        let start = _base.distance(from: _base.startIndex, to: _startIndex)
        let count = _base.distance(from: _startIndex, to: _endIndex)
        
        return try _base.withContiguousMutableStorageIfAvailable { buffer in
            // 首先, 拿到 Base, 也就是原有 collection 的指针,
            // 然后切分为 Slice 当前的范围, 然后传递到 body.
            var slice = UnsafeMutableBufferPointer(
                rebasing: buffer[start ..< start + count])
            let copy = slice
            return try body(&slice)
        }
    }
}


extension Slice: RandomAccessCollection where Base: RandomAccessCollection { }
// Slice 里面, 所有对于 Index 的操作, 都是根据 Base Collection 进行的, 然后有着 Slice 记录的 StartIndex, EndIndex 范围的后续逻辑处理.

extension Slice: RangeReplaceableCollection
where Base: RangeReplaceableCollection {
    public init() {
        self._base = Base()
        self._startIndex = _base.startIndex
        self._endIndex = _base.endIndex
    }
    
    public init(repeating repeatedValue: Base.Element, count: Int) {
        self._base = Base(repeating: repeatedValue, count: count)
        self._startIndex = _base.startIndex
        self._endIndex = _base.endIndex
    }
    
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
        _base.replaceSubrange(subRange, with: newElements)
        
        _startIndex = _base.index(_base.startIndex, offsetBy: sliceOffset)
        _endIndex = _base.index(_startIndex, offsetBy: newSliceCount)
    }
    
    public mutating func insert(_ newElement: Base.Element, at i: Index) {
        // FIXME: swift-3-indexing-model: range check.
        let sliceOffset = _base.distance(from: _base.startIndex, to: _startIndex)
        let newSliceCount = count + 1
        _base.insert(newElement, at: i)
        _startIndex = _base.index(_base.startIndex, offsetBy: sliceOffset)
        _endIndex = _base.index(_startIndex, offsetBy: newSliceCount)
    }
    
    public mutating func insert<S>(contentsOf newElements: S, at i: Index)
    where S: Collection, S.Element == Base.Element {
        let sliceOffset = _base.distance(from: _base.startIndex, to: _startIndex)
        let newSliceCount = count + newElements.count
        _base.insert(contentsOf: newElements, at: i)
        _startIndex = _base.index(_base.startIndex, offsetBy: sliceOffset)
        _endIndex = _base.index(_startIndex, offsetBy: newSliceCount)
    }
    
    public mutating func remove(at i: Index) -> Base.Element {
        // FIXME: swift-3-indexing-model: range check.
        let sliceOffset = _base.distance(from: _base.startIndex, to: _startIndex)
        let newSliceCount = count - 1
        let result = _base.remove(at: i)
        _startIndex = _base.index(_base.startIndex, offsetBy: sliceOffset)
        _endIndex = _base.index(_startIndex, offsetBy: newSliceCount)
        return result
    }
    
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

extension Slice
where Base: RangeReplaceableCollection, Base: BidirectionalCollection {
    
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
