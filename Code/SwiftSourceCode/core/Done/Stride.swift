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
 相对于 comparable, Strideable 非常关键的一点是, 必须是可以测算出偏移值的.
 字符串是可比较的, apple, banane 比较的话,  apple 一定大, 但是, 他们是没有办法测算出一个偏移值来的.
 
 最形象的理解就是, strideable 的对象, 就是坐标轴上的坐标. 有刻度表示, 有方向表示.
 */

/*
 对于 Strideable 要确保几个概念.
 1. 间距是什么类型. 2. 当前值可以通过间距获取到那个位置的值.
 */
public protocol Strideable: Comparable {
    /// 表示间距的类型, 必须可比较大小, 而是可以用数字测量, 有着正负的概念.
    associatedtype Stride: SignedNumeric, Comparable
    
    /// 必须可以测算出, 与另一个 Strideable 之间的距离有多少.
    func distance(to other: Self) -> Stride
    /// 必须可以根据距离, 得到另外一个 Strideable 的值.
    func advanced(by n: Stride) -> Self
    
    static func _step(
        after current: (index: Int?, value: Self),
        from start: Self, by distance: Self.Stride
    ) -> (index: Int?, value: Self)
}

extension Strideable {
    /*
     如果, A 比 B 大, 就是在刻度尺上, A 在比的后面.
     */
    public static func < (x: Self, y: Self) -> Bool {
        return x.distance(to: y) > 0
    }
    /*
     如果, AB 相等, 就是在刻度尺上, A,B 在同一个位置.
     */
    public static func == (x: Self, y: Self) -> Bool {
        return x.distance(to: y) == 0
    }
}

/*
 默认的实现, 是不会包含 index 信息的, 只计算出 striable 的值出来.
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


/// 以下是 Stride 这个函数相关的实现.
/// StrideTo 表示, 不包含结束位置. StrideThrough 会包含结束位置.
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

extension StrideToIterator: IteratorProtocol {
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

/// 这个序列里面, 仅仅是存储了一下起始位置, 终点位置, 步长的信息.
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
        self._start = _start
        self._end = end
        self._stride = stride
    }
}

/*
 StrideTo 对于 Sequence 的实现, 就是返回相应的 iterator.
 */
extension StrideTo: Sequence {
    @inlinable
    public __consuming func makeIterator() -> StrideToIterator<Element> {
        return StrideToIterator(_start: _start, end: _end, stride: _stride)
    }
    /*
     这里, underestimatedCount 也是迭代出来的. 但是因为 Stride 可以根据步长来计算, 有可能很快.
     */
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
 stride 这个函数, 就是一个简便方法, 生成对应的结构体, 而这个结构体, 再去完成迭代的具体工作.
 面向对象的好处就是, 封装具体的业务逻辑, 只提供稳定方便的接口.
 */
@inlinable
public func stride<T>(
    from start: T, to end: T, by stride: T.Stride
) -> StrideTo<T> {
    return StrideTo(_start: start, end: end, stride: stride)
}

/*
 StrideThrough 的相关实现. StrideThrough 是, 截止点也算范围的一部分.
 */
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
        self._start = _start
        self._end = end
        self._stride = stride
    }
}

extension StrideThrough: Sequence {
    @inlinable
    public __consuming func makeIterator() -> StrideThroughIterator<Element> {
        return StrideThroughIterator(_start: _start, end: _end, stride: _stride)
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
 简便方法, 返回对应的结构体, 完成实际的工作.
 */
@inlinable
public func stride<T>(
    from start: T, through end: T, by stride: T.Stride
) -> StrideThrough<T> {
    return StrideThrough(_start: start, end: end, stride: stride)
}
