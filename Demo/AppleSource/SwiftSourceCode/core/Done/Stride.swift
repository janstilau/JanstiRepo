/*
 Swift 的通用数据类型, 是建立在各个小的概念上的. 也就是面向抽象编程.
 这种抽象组合, 会让整个系统类库很复杂.
 但是, 由于大量的 Api, 是建立在抽象类型上, 一旦你自己的类, 符合了这种抽象, 他就可以复用大量的抽象数据类型所带有的方法.
 之前的 for 循环的问题, 可以通过 stride 函数, 创造出符合自己实际情况的迭代过程.
 */
  
/*
 Strideable, 可比较的, 可以测算距离的, 可以根据距离, 进行前进后退的.
 Int, Float 都是 Strideable 的
 Stride 表示的是, 两个 Strideable 之间的距离.
 */
/// A type representing continuous, one-dimensional values that can be offset
/// and measured.
/// 相对于 comparable, Strideable 非常关键的一点是, 必须是可以测算出偏移值的.
/// 字符串是可比较的, apple, banane 比较的话,  apple 一定大, 但是, 他们是没有办法测算出一个偏移值来的.
///
/// Stride, 其实就是偏移量. 可以这样理解, 可以完成 += 操作的数据类型, 才可以算作是 Strideable.
/// The last parameter of these functions is of the associated `Stride`
/// type---the type that represents the distance between any two instances of
/// the `Strideable` type.
///
/// - Important: The `Strideable` protocol provides default implementations for
///   the equal-to (`==`) and less-than (`<`) operators that depend on the
///   `Stride` type's implementations. If a type conforming to `Strideable` is
///   its own `Stride` type, it must provide concrete implementations of the
///   two operators to avoid infinite recursion.

/*
 对于 Strideable 要确保几个概念. 1. 间距是什么类型. 2. 当前值可以通过间距获取到那个位置的值.
 */
public protocol Strideable: Comparable {
    /// A type that represents the distance between two values.
    associatedtype Stride: SignedNumeric, Comparable
    
    func distance(to other: Self) -> Stride
    func advanced(by n: Stride) -> Self
    
    /// `_step` is an implementation detail of Strideable; do not use it directly.
    static func _step(
        after current: (index: Int?, value: Self),
        from start: Self, by distance: Self.Stride
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

/*
 默认的实现, 是不会包含 index 信息的, 但是会给出相应位置的 striable 值.
 */
extension Strideable {
    @inlinable // protocol-only
    public static func _step(
        after current: (index: Int?, value: Self),
        from start: Self, by distance: Self.Stride
    ) -> (index: Int?, value: Self) {
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
            // When Stride is a floating-point type, we should avoid accumulating
            // rounding error from repeated addition.
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

/// An iterator for a `StrideTo` instance.
@frozen
public struct StrideToIterator<Element: Strideable> {
    @usableFromInline
    internal let _start: Element
    
    @usableFromInline
    internal let _end: Element
    
    @usableFromInline
    internal let _stride: Element.Stride
    
    @usableFromInline
    internal var _current: (index: Int?, value: Element)
    
    @inlinable
    internal init(_start: Element, end: Element, stride: Element.Stride) {
        self._start = _start
        _end = end
        _stride = stride
        _current = (0, _start)
    }
}

/*
 StrideToIterator 表示, 不包含目标位置.
 */
extension StrideToIterator: IteratorProtocol {
    /// Advances to the next element and returns it, or `nil` if no next element
    /// exists.
    ///
    /// Once `nil` has been returned, all subsequent calls return `nil`.
    @inlinable
    public mutating func next() -> Element? {
        let result = _current.value
        if _stride > 0 ? result >= _end : result <= _end {
            return nil
        }
        _current = Element._step(after: _current, from: _start, by: _stride)
        return result
    }
}

/// A sequence of values formed by striding over a half-open interval.
///
/// Use the `stride(from:to:by:)` function to create `StrideTo` instances.
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

/*
 一个简单的序列,  它的作用, 主要是引出 StrideToIterator.
 */
extension StrideTo: Sequence {
    @inlinable
    public __consuming func makeIterator() -> StrideToIterator<Element> {
        return StrideToIterator(_start: _start, end: _end, stride: _stride)
    }
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

/*
 StrideTo, 该函数的作用, 就是封装 StrideTo. StrideTo 是一个序列, 正是因为有它的存在, for in 的有半部分, 才可以安放, stride 函数.
 */
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

/*
 StrideThrough 和上面的唯一区别, 就是在 end 的判断上. 一个认为到达则是 nil, 一个认为越过了才是 nil.
 */
@inlinable
public func stride<T>(
    from start: T, through end: T, by stride: T.Stride
) -> StrideThrough<T> {
    return StrideThrough(_start: start, end: end, stride: stride)
}
