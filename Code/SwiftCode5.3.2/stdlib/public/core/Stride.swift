// 一维的, 连续的, 可以评判出差距的类型.
// 一维的, 代表着有前后关系
// 可比较大小, 不一定是可以评判出差距的, 例如, 单词的字典排序.

// Strideable 可以度量出间隔来.
// 间隔有着正负之分, 并且是可以比较的.
// 比如. 姚明周琦之间, 差着 10 个易建联. 首先这个是有正负的, 就是姚明一定在周琦上面. 易建联, 也是可以比较的, 比较的标准就是战斗力.

// 可以评判差距的类型.
public protocol Strideable: Comparable {
    // 评判的标准, 可读.
    associatedtype Stride: SignedNumeric, Comparable
    
    // 判断两者之间的差距. 按理来说, 这应该是一个 - 号运算符.
    func distance(to other: Self) -> Stride
    // 通过刻度, 计算出后面的值来
    func advanced(by n: Stride) -> Self
    
    static func _step(
        after current: (index: Int?, value: Self),
        from start: Self,
        by distance: Self.Stride
    ) -> (index: Int?, value: Self)
}

extension Strideable {
    @inlinable
    public static func < (x: Self, y: Self) -> Bool {
        return x.distance(to: y) > 0
    }
    @inlinable
    public static func == (x: Self, y: Self) -> Bool {
        return x.distance(to: y) == 0
    }
}

extension Strideable {
    @inlinable
    public static func _step(
        after current: (index: Int?, value: Self),
        from start: Self, by distance: Self.Stride
    ) -> (index: Int?, value: Self) {
        // 按理说, current 用 advanced(by 就能够确定出来.
        // 这里, index 更多的是为了扩展用的.
        return (nil, current.value.advanced(by: distance))
    }
}

extension Strideable where Stride: FloatingPoint {
    @inlinable // protocol-only
    public static func _step(
        after current: (index: Int?, value: Self),
        from start: Self, by distance: Self.Stride
    ) -> (index: Int?, value: Self) {
        if let i = current.index {
            return (i + 1, start.advanced(by: Stride(i + 1) * distance))
        }
        return (nil, current.value.advanced(by: distance))
    }
}

extension Strideable where Self: FloatingPoint, Self == Stride {
    @inlinable // protocol-only
    public static func _step(
        after current: (index: Int?, value: Self),
        from start: Self, by distance: Self.Stride
    ) -> (index: Int?, value: Self) {
        if let i = current.index {
            // When both Self and Stride are the same floating-point type, we should
            // take advantage of fused multiply-add (where supported) to eliminate
            // intermediate rounding error.
            return (i + 1, start.addingProduct(Stride(i + 1), distance))
        }
        return (nil, current.value.advanced(by: distance))
    }
}

@frozen
public struct StrideToIterator<Element: Strideable> {
    @usableFromInline
    internal let _start: Element
    
    @usableFromInline
    internal let _end: Element
    
    @usableFromInline
    internal let _stride: Element.Stride
    
    // 除了, Start, end, stride 之外, 还有 _current 这样的一个值. 里面除了 currentValue, 还存储 index.
    @usableFromInline
    // index 表示, 第几个,  value 表示, 这个位置的值.
    internal var _current: (index: Int?, value: Element)
    
    @inlinable
    internal init(_start: Element, end: Element, stride: Element.Stride) {
        self._start = _start
        _end = end
        _stride = stride
        _current = (0, _start)
    }
    
    public mutating func next() -> Element? {
        let result = _current.value
        if _stride > 0 ? result >= _end : result <= _end {
            return nil
        }
        //
        _current = Element._step(after: _current, from: _start, by: _stride)
        return result
    }
}

@frozen
public struct StrideTo<Element: Strideable> {
    @usableFromInline
    internal let _start: Element
    
    @usableFromInline
    internal let _end: Element
    
    @usableFromInline
    internal let _stride: Element.Stride
    
    @inlinable
    internal init(_start: Element, end: Element, stride: Element.Stride) {
        _precondition(stride != 0, "Stride size must not be zero")
        // At start, striding away from end is allowed; it just makes for an
        // already-empty Sequence.
        self._start = _start
        self._end = end
        self._stride = stride
    }
}

extension StrideTo: Sequence {
    /// Returns an iterator over the elements of this sequence.
    ///
    /// - Complexity: O(1).
    @inlinable
    public __consuming func makeIterator() -> StrideToIterator<Element> {
        return StrideToIterator(_start: _start, end: _end, stride: _stride)
    }
    
    // FIXME(conditional-conformances): this is O(N) instead of O(1), leaving it
    // here until a proper Collection conformance is possible
    @inlinable
    public var underestimatedCount: Int {
        var it = self.makeIterator()
        var count = 0
        while it.next() != nil {
            count += 1
        }
        return count
    }
    
    @inlinable
    public func _customContainsEquatableElement(
        _ element: Element
    ) -> Bool? {
        if element < _start || _end <= element {
            return false
        }
        return nil
    }
}

extension StrideTo: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(self, children: ["from": _start, "to": _end, "by": _stride])
    }
}

#if false
extension StrideTo: RandomAccessCollection
where Element.Stride: BinaryInteger {
    // 如果, stride 是 int, 那么可以当做 collection 来用.
    public typealias Index = Int
    public typealias SubSequence = Slice<StrideTo<Element>>
    public typealias Indices = Range<Int>
    
    @inlinable
    public var startIndex: Index { return 0 }
    
    @inlinable
    public var endIndex: Index { return count }
    
    @inlinable
    public var count: Int {
        let distance = _start.distance(to: _end)
        guard distance != 0 && (distance < 0) == (_stride < 0) else { return 0 }
        return Int((distance - 1) / _stride) + 1
    }
    
    public subscript(position: Index) -> Element {
        _failEarlyRangeCheck(position, bounds: startIndex..<endIndex)
        return _start.advanced(by: Element.Stride(position) * _stride)
    }
    
    public subscript(bounds: Range<Index>) -> Slice<StrideTo<Element>> {
        _failEarlyRangeCheck(bounds, bounds: startIndex ..< endIndex)
        return Slice(base: self, bounds: bounds)
    }
    
    @inlinable
    public func index(before i: Index) -> Index {
        _failEarlyRangeCheck(i, bounds: startIndex + 1...endIndex)
        return i - 1
    }
    
    @inlinable
    public func index(after i: Index) -> Index {
        _failEarlyRangeCheck(i, bounds: startIndex - 1..<endIndex)
        return i + 1
    }
}
#endif

// stride 方法, 返回一个 StrideTo 的结构体来, 这个结构体, 又是 sequence. 所以, 这个可以用在 forin 里面.
@inlinable
public func stride<T>(
    from start: T, to end: T, by stride: T.Stride
) -> StrideTo<T> {
    return StrideTo(_start: start, end: end, stride: stride)
}

/// An iterator for a `StrideThrough` instance.
@frozen
public struct StrideThroughIterator<Element: Strideable> {
    @usableFromInline
    internal let _start: Element
    
    @usableFromInline
    internal let _end: Element
    
    @usableFromInline
    internal let _stride: Element.Stride
    
    @usableFromInline
    internal var _current: (index: Int?, value: Element)
    
    @usableFromInline
    internal var _didReturnEnd: Bool = false
    
    @inlinable
    internal init(_start: Element, end: Element, stride: Element.Stride) {
        self._start = _start
        _end = end
        _stride = stride
        _current = (0, _start)
    }
}

extension StrideThroughIterator: IteratorProtocol {
    /// Advances to the next element and returns it, or `nil` if no next element
    /// exists.
    ///
    /// Once `nil` has been returned, all subsequent calls return `nil`.
    @inlinable
    public mutating func next() -> Element? {
        let result = _current.value
        if _stride > 0 ? result >= _end : result <= _end {
            // This check is needed because if we just changed the above operators
            // to > and <, respectively, we might advance current past the end
            // and throw it out of bounds (e.g. above Int.max) unnecessarily.
            if result == _end && !_didReturnEnd {
                _didReturnEnd = true
                return result
            }
            return nil
        }
        _current = Element._step(after: _current, from: _start, by: _stride)
        return result
    }
}

// FIXME: should really be a Collection, as it is multipass
/// A sequence of values formed by striding over a closed interval.
///
/// Use the `stride(from:through:by:)` function to create `StrideThrough` 
/// instances.
@frozen
public struct StrideThrough<Element: Strideable> {
    @usableFromInline
    internal let _start: Element
    @usableFromInline
    internal let _end: Element
    @usableFromInline
    internal let _stride: Element.Stride
    
    @inlinable
    internal init(_start: Element, end: Element, stride: Element.Stride) {
        _precondition(stride != 0, "Stride size must not be zero")
        self._start = _start
        self._end = end
        self._stride = stride
    }
}

extension StrideThrough: Sequence {
    /// Returns an iterator over the elements of this sequence.
    ///
    /// - Complexity: O(1).
    @inlinable
    public __consuming func makeIterator() -> StrideThroughIterator<Element> {
        return StrideThroughIterator(_start: _start, end: _end, stride: _stride)
    }
    
    // FIXME(conditional-conformances): this is O(N) instead of O(1), leaving it
    // here until a proper Collection conformance is possible
    @inlinable
    public var underestimatedCount: Int {
        var it = self.makeIterator()
        var count = 0
        while it.next() != nil {
            count += 1
        }
        return count
    }
    
    @inlinable
    public func _customContainsEquatableElement(
        _ element: Element
    ) -> Bool? {
        if element < _start || _end < element {
            return false
        }
        return nil
    }
}

extension StrideThrough: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(self,
                      children: ["from": _start, "through": _end, "by": _stride])
    }
}

// FIXME(conditional-conformances): This does not yet compile (SR-6474).
#if false
extension StrideThrough: RandomAccessCollection
where Element.Stride: BinaryInteger {
    public typealias Index = ClosedRangeIndex<Int>
    public typealias SubSequence = Slice<StrideThrough<Element>>
    
    @inlinable
    public var startIndex: Index {
        let distance = _start.distance(to: _end)
        return distance == 0 || (distance < 0) == (_stride < 0)
            ? ClosedRangeIndex(0)
            : ClosedRangeIndex()
    }
    
    @inlinable
    public var endIndex: Index { return ClosedRangeIndex() }
    
    @inlinable
    public var count: Int {
        let distance = _start.distance(to: _end)
        guard distance != 0 else { return 1 }
        guard (distance < 0) == (_stride < 0) else { return 0 }
        return Int(distance / _stride) + 1
    }
    
    public subscript(position: Index) -> Element {
        let offset = Element.Stride(position._dereferenced) * _stride
        return _start.advanced(by: offset)
    }
    
    public subscript(bounds: Range<Index>) -> Slice<StrideThrough<Element>> {
        return Slice(base: self, bounds: bounds)
    }
    
    @inlinable
    public func index(before i: Index) -> Index {
        switch i._value {
        case .inRange(let n):
            _precondition(n > 0, "Incrementing past start index")
            return ClosedRangeIndex(n - 1)
        case .pastEnd:
            _precondition(_end >= _start, "Incrementing past start index")
            return ClosedRangeIndex(count - 1)
        }
    }
    
    @inlinable
    public func index(after i: Index) -> Index {
        switch i._value {
        case .inRange(let n):
            return n == (count - 1)
                ? ClosedRangeIndex()
                : ClosedRangeIndex(n + 1)
        case .pastEnd:
            _preconditionFailure("Incrementing past end index")
        }
    }
}
#endif

@inlinable
public func stride<T>(
    from start: T, through end: T, by stride: T.Stride
) -> StrideThrough<T> {
    return StrideThrough(_start: start, end: end, stride: stride)
}
