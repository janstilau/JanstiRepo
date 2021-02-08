// 一维的, 连续的, 可以评判出差距的类型.
// 一维的, 代表着有前后关系, Comparable 的职责, 但是可比较大小, 不一定是可以评判出差距的, 例如, 单词的字典排序. abandon 和 zoo 可以判断出大小来, 但是之间有多少单词, 是完全没有办法确定下来的.

// Strideable 可以度量出间隔来. 可以根据一个值, 和间隔值, 快速的计算出另外一个值来.

public protocol Strideable: Comparable {
    // offsest 的单位, 有正负关系, 可以比较.
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
    public static func < (x: Self, y: Self) -> Bool {
        return x.distance(to: y) > 0
    }
    public static func == (x: Self, y: Self) -> Bool {
        return x.distance(to: y) == 0
    }
}

// _step 主要是为了特定的算法使用的.
extension Strideable {
    @inlinable
    public static func _step(
        after current: (index: Int?, value: Self),
        from start: Self, by distance: Self.Stride
    ) -> (index: Int?, value: Self) {
        return (nil, current.value.advanced(by: distance))
    }
}

extension Strideable where Stride: FloatingPoint {
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
    public static func _step(
        after current: (index: Int?, value: Self),
        from start: Self, by distance: Self.Stride
    ) -> (index: Int?, value: Self) {
        if let i = current.index {
            return (i + 1, start.addingProduct(Stride(i + 1), distance))
        }
        return (nil, current.value.advanced(by: distance))
    }
}

// StrideToIterator 是为了 StrideTo 能够实现 Sequence 而定义的迭代器, 按照标准库的习惯, 应该到 StrideTo 的命名空间里才算合理.
public struct StrideToIterator<Element: Strideable> {
    // 这三个值, 都是生成 StrideTo 对象的时候, 外界传过来的. 而生成过程, 是有 stride 函数包裹起来的.
    // 一个简单的方法, 生成特殊的对象, 而使用这个对象的时候, 是按照协议在使用这个对象. 这就是 Swift 面向协议编程的一个体现.
    internal let _start: Element
    internal let _end: Element
    internal let _stride: Element.Stride
    // Iter 里面, 真正表示状态值的就是 _current 这个元组.
    internal var _current: (index: Int?, value: Element)
    
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
        // 这里, 感觉 _step 这个函数, 反而让代码更加的混乱了.
        _current = Element._step(after: _current, from: _start, by: _stride)
        return result
    }
}

// 实际上, 这个类, 主要功能时提供了 StrideToIterator<Element>, 并且把自己的值, 传递到里面去.
// Iterator, 里面根据 sequence 里面的值进行初始化, 然后维护根据这些值, 维护一个可以改变的值, 作为迭代过程的控制.
public struct StrideTo<Element: Strideable> {
    internal let _start: Element
    internal let _end: Element
    internal let _stride: Element.Stride
    internal init(_start: Element, end: Element, stride: Element.Stride) {
        self._start = _start
        self._end = end
        self._stride = stride
    }
}

extension StrideTo: Sequence {
    public __consuming func makeIterator() -> StrideToIterator<Element> {
        return StrideToIterator(_start: _start, end: _end, stride: _stride)
    }
    // 这里是遍历生成的, 不符合 underestimatedCount 的使用的原始意图.
    public var underestimatedCount: Int {
        var it = self.makeIterator()
        var count = 0
        while it.next() != nil {
            count += 1
        }
        return count
    }
    // 特殊的, 快速的判断 contains 的方法.
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

extension StrideTo: RandomAccessCollection
where Element.Stride: BinaryInteger {
    
    public typealias Index = Int
    public typealias SubSequence = Slice<StrideTo<Element>>
    public typealias Indices = Range<Int>
    public var startIndex: Index { return 0 }
    public var endIndex: Index { return count }
    
    public var count: Int {
        let distance = _start.distance(to: _end)
        guard distance != 0 && (distance < 0) == (_stride < 0) else { return 0 }
        return Int((distance - 1) / _stride) + 1
    }
    
    public subscript(position: Index) -> Element {
        return _start.advanced(by: Element.Stride(position) * _stride)
    }
    
    public subscript(bounds: Range<Index>) -> Slice<StrideTo<Element>> {
        return Slice(base: self, bounds: bounds)
    }
    
    public func index(before i: Index) -> Index {
        return i - 1
    }
    
    public func index(after i: Index) -> Index {
        return i + 1
    }
}

// 特殊的方法, 将 StrideTo 对象创建, 而使用它的地方, 一般是在 Forin 里面, 这样, 外界根本就不知道有 StrideTo 这个东西的存在, 因为 Forin 是根据 sequence 的接口进行的逻辑控制.
public func stride<T>(
    from start: T, to end: T, by stride: T.Stride
) -> StrideTo<T> {
    return StrideTo(_start: start, end: end, stride: stride)
}



// StrideThrough 和 StrideTo 没有太大的区别, 就是最后一个值取不取的问题.
public struct StrideThroughIterator<Element: Strideable> {
    internal let _start: Element
    
    internal let _end: Element
    
    internal let _stride: Element.Stride
    
    internal var _current: (index: Int?, value: Element)
    
    internal var _didReturnEnd: Bool = false
    
    internal init(_start: Element, end: Element, stride: Element.Stride) {
        self._start = _start
        _end = end
        _stride = stride
        _current = (0, _start)
    }
}

extension StrideThroughIterator: IteratorProtocol {
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

public struct StrideThrough<Element: Strideable> {
    internal let _start: Element
    internal let _end: Element
    internal let _stride: Element.Stride
    
    internal init(_start: Element, end: Element, stride: Element.Stride) {
        self._start = _start
        self._end = end
        self._stride = stride
    }
}

extension StrideThrough: Sequence {
    public __consuming func makeIterator() -> StrideThroughIterator<Element> {
        return StrideThroughIterator(_start: _start, end: _end, stride: _stride)
    }
    
    public var underestimatedCount: Int {
        var it = self.makeIterator()
        var count = 0
        while it.next() != nil {
            count += 1
        }
        return count
    }
    
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

// 外界使用的, 简便的方法. 把实际的内部类型的创建进行了封装.
public func stride<T>(
    from start: T, through end: T, by stride: T.Stride
) -> StrideThrough<T> {
    return StrideThrough(_start: start, end: end, stride: stride)
}
