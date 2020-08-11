/// A view into a subsequence of elements of another collection.
///
///
///   切片, 会存储原始的 Collection, 以及切片的起始位置, 结束为止.
/// A slice stores a base collection and the start and end indices of the view.
/// It does not copy the elements from the collection into separate storage.
/// Thus, creating a slice has O(1) complexity.
///
/// Slices Share Indices
/// --------------------
/// 切片里面, 还是使用 Collection 的 index, 但是使用者要确保, 不能超出切片的范围.
/// Indices of a slice can be used interchangeably with indices of the base
/// collection. An element of a slice is located under the same index in the
/// slice and in the base collection, as long as neither the collection nor
/// the slice has been mutated since the slice was created.
///
/// For example, suppose you have an array holding the number of absences from
/// each class during a session.
///
///     var absences = [0, 2, 0, 4, 0, 3, 1, 0]
///
/// You're tasked with finding the day with the most absences in the second
/// half of the session. To find the index of the day in question, follow
/// these setps:
///
/// 1) Create a slice of the `absences` array that holds the second half of the
///    days.
/// 2) Use the `max(by:)` method to determine the index of the day with the
///    most absences.
/// 3) Print the result using the index found in step 2 on the original
///    `absences` array.
///
/// Here's an implementation of those steps:
///
///  这里, 可以看到, 3 是原始的 sequence 的索引, 而不是 slice 的索引.
///     let secondHalf = absences.suffix(absences.count / 2)
///     if let i = secondHalf.indices.max(by: { secondHalf[$0] < secondHalf[$1] }) {
///         print("Highest second-half absences: \(absences[i])")
///     }
///     // Prints "Highest second-half absences: 3"
///
/// Slices Inherit Semantics
/// ------------------------
///
/// 切片的值语义.
/// A slice inherits the value or reference semantics of its base collection.
/// That is, if a `Slice` instance is wrapped around a mutable collection that
/// has value semantics, such as an array, mutating the original collection
/// would trigger a copy of that collection, and not affect the base
/// collection stored inside of the slice.
///
/// For example, if you update the last element of the `absences` array from
/// `0` to `2`, the `secondHalf` slice is unchanged.
///
///     absences[7] = 2
///     print(absences)
///     // Prints "[0, 2, 0, 4, 0, 3, 1, 2]"
///     print(secondHalf)
///     // Prints "[0, 3, 1, 0]"
///
/// 切片最好还是临时使用, 不要当做存储来进行.
/// Use slices only for transient computation. A slice may hold a reference to
/// the entire storage of a larger collection, not just to the portion it
/// presents, even after the base collection's lifetime ends. Long-term
/// storage of a slice may therefore prolong the lifetime of elements that are
/// no longer otherwise accessible, which can erroneously appear to be memory
/// leakage.
///
/// - Note: Using a `Slice` instance with a mutable collection requires that
///   the base collection's `subscript(_: Index)` setter does not invalidate
///   indices. If mutations need to invalidate indices in your custom
///   collection type, don't use `Slice` as its subsequence type. Instead,
///   define your own subsequence type that takes your index invalidation
///   requirements into account.


/*
 Slice 真正的, 仅仅是记录三个值
 slice 的 startIndex
 slice 的 endIndex
 slice 的 originalBaseCollection
 */
@frozen // generic-performance
public struct Slice<Base: Collection> {
    public var _startIndex: Base.Index
    public var _endIndex: Base.Index
    @usableFromInline // generic-performance
    internal var _base: Base
    
    /*
     对于 Collection 来说, 通过范围取值, 就是生成一个 Slice 对象
     */
    @inlinable
    public init(base: Base, bounds: Range<Base.Index>) {
        self._base = base
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
 */
extension Slice: Collection {
    public typealias Index = Base.Index
    public typealias Indices = Base.Indices
    public typealias Element = Base.Element
    public typealias SubSequence = Slice<Base>
    public typealias Iterator = IndexingIterator<Slice<Base>>
    
    @inlinable // generic-performance
    public var startIndex: Index {
        return _startIndex
    }
    
    @inlinable // generic-performance
    public var endIndex: Index {
        return _endIndex
    }
    /*
     这里, 判断范围的时候, 是使用的自己记录的 start, end 的范围.
     如果, 传递过来的 Index 不在 _startIndex, _endIndex 里面, 直接报错.
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
     */
    @inlinable // generic-performance
    public func index(after i: Index) -> Index {
        // FIXME: swift-3-indexing-model: range check.
        return _base.index(after: i)
    }
    
    @inlinable // generic-performance
    public func formIndex(after i: inout Index) {
        // FIXME: swift-3-indexing-model: range check.
        _base.formIndex(after: &i)
    }
    
    @inlinable // generic-performance
    public func index(_ i: Index, offsetBy n: Int) -> Index {
        // FIXME: swift-3-indexing-model: range check.
        return _base.index(i, offsetBy: n)
    }
    
    @inlinable // generic-performance
    public func index(
        _ i: Index, offsetBy n: Int, limitedBy limit: Index
    ) -> Index? {
        // FIXME: swift-3-indexing-model: range check.
        return _base.index(i, offsetBy: n, limitedBy: limit)
    }
    
    @inlinable // generic-performance
    public func distance(from start: Index, to end: Index) -> Int {
        // FIXME: swift-3-indexing-model: range check.
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
 注意, MutableCollection 指的是, 可以改变集合里面的信息, 而添加删除元素, 则是 Replaceable 的能力.
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
            // MutableSlice requires that the underlying collection's subscript
            // setter does not invalidate indices, so our `startIndex` and `endIndex`
            // continue to be valid.
        }
    }
    
    @inlinable // generic-performance
    public subscript(bounds: Range<Index>) -> Slice<Base> {
        get {
            _failEarlyRangeCheck(bounds, bounds: startIndex..<endIndex)
            return Slice(base: _base, bounds: bounds)
        }
        set {
            // 这里, 应该会有着 copyOnWrite 的操作.
            _writeBackMutableSlice(&self, bounds: bounds, slice: newValue)
        }
    }
}

// 如果, Base 可以随机访问, 那么 Slice 也可以随机访问.
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
