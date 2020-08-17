@frozen
public struct ClosedRange<Bound: Comparable> {
    public let lowerBound: Bound
    public let upperBound: Bound
    
    @inlinable
    public init(uncheckedBounds bounds: (lower: Bound, upper: Bound)) {
        self.lowerBound = bounds.lower
        self.upperBound = bounds.upper
    }
}

/*
 对于 closedRange 来说, 1...1, 也不可能是 empty 的.
 */
extension ClosedRange {
    @inlinable
    public var isEmpty: Bool {
        return false
    }
}

extension ClosedRange: RangeExpression {
    @inlinable // trivial-implementation
    public func relative<C: Collection>(to collection: C) -> Range<Bound>
        where C.Index == Bound {
            return Range(
                uncheckedBounds: (
                    lower: lowerBound, upper: collection.index(after: self.upperBound)))
    }
    
    @inlinable
    public func contains(_ element: Bound) -> Bool {
        return element >= self.lowerBound && element <= self.upperBound
    }
}

extension ClosedRange: Sequence
where Bound: Strideable, Bound.Stride: SignedInteger {
    public typealias Element = Bound
    public typealias Iterator = IndexingIterator<ClosedRange<Bound>>
}

/*
 ClosedRange 中的 Index, 就是利用了 Enum 的特殊设计.
 终点, 和过程中, 是两个不同类型.
 而过程中的状态, 才会包含 Index 的值.
 */
extension ClosedRange where Bound: Strideable, Bound.Stride: SignedInteger {
    @frozen // FIXME(resilience)
    public enum Index {
        case pastEnd
        case inRange(Bound)
    }
}

/*
 Enum 的判断, 不要 switch 中套用 switch, 多多利用元组的这个概念.
 */
extension ClosedRange.Index: Comparable {
    @inlinable
    public static func == (
        lhs: ClosedRange<Bound>.Index,
        rhs: ClosedRange<Bound>.Index
    ) -> Bool {
        switch (lhs, rhs) {
        case (.inRange(let l), .inRange(let r)):
            return l == r
        case (.pastEnd, .pastEnd):
            return true
        default:
            return false
        }
    }
    
    @inlinable
    public static func < (
        lhs: ClosedRange<Bound>.Index,
        rhs: ClosedRange<Bound>.Index
    ) -> Bool {
        switch (lhs, rhs) {
        case (.inRange(let l), .inRange(let r)):
            return l < r
        case (.inRange, .pastEnd):
            return true
        default:
            return false
        }
    }
}

extension ClosedRange.Index: Hashable
where Bound: Strideable, Bound.Stride: SignedInteger, Bound: Hashable {
    /// Hashes the essential components of this value by feeding them into the
    /// given hasher.
    ///
    /// - Parameter hasher: The hasher to use when combining the components
    ///   of this instance.
    @inlinable
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .inRange(let value):
            hasher.combine(0 as Int8)
            hasher.combine(value)
        case .pastEnd:
            hasher.combine(1 as Int8)
        }
    }
}

/*
 ClosedRange 里面, 只会存储 lowerBound, upperBound 的值, 但是他的 Index, 是一个枚举值.
 所以, 相应的接口里面, 其实要做这个枚举值的创建工作.
 */
extension ClosedRange: Collection, BidirectionalCollection, RandomAccessCollection
    where Bound: Strideable, Bound.Stride: SignedInteger
{
    public typealias SubSequence = Slice<ClosedRange<Bound>>
    
    /*
     直接使用 lowerBound, 创建了一个 inRange 状态的枚举值.
     */
    @inlinable
    public var startIndex: Index {
        return .inRange(lowerBound)
    }
    
    /*
     直接返回了特殊状态的枚举值, 没有使用到 upperBound
     */
    @inlinable
    public var endIndex: Index {
        return .pastEnd
    }
    
    /*
     upperBound 在这个过程中, 进行了判断. 但是, .pastEnd 里面, 没有包含 upperBound 的值.
     */
    @inlinable
    public func index(after i: Index) -> Index {
        switch i {
        case .inRange(let x):
            return x == upperBound
                ? .pastEnd
                : .inRange(x.advanced(by: 1))
        case .pastEnd:
            _preconditionFailure("Incrementing past end index")
        }
    }
    
    /*
     如果是 end 的状态, 那么它的前面就是 .inRange(upperBound).
     如果是 .inRange 的状态, 那么直接进行 advance 取值就可以了. 在内部, 会有范围值的有效性的判断.
     */
    @inlinable
    public func index(before i: Index) -> Index {
        switch i {
        case .inRange(let x):
            _precondition(x > lowerBound, "Incrementing past start index")
            return .inRange(x.advanced(by: -1))
        case .pastEnd:
            _precondition(upperBound >= lowerBound, "Incrementing past start index")
            return .inRange(upperBound)
        }
    }
    
    @inlinable
    public func index(_ i: Index, offsetBy distance: Int) -> Index {
        switch i {
        case .inRange(let x):
            let d = x.distance(to: upperBound)
            if distance <= d {
                let newPosition = x.advanced(by: numericCast(distance))
                _precondition(newPosition >= lowerBound,
                              "Advancing past start index")
                return .inRange(newPosition)
            }
            if d - -1 == distance { return .pastEnd }
            _preconditionFailure("Advancing past end index")
        case .pastEnd:
            if distance == 0 {
                return i
            }
            if distance < 0 {
                return index(.inRange(upperBound), offsetBy: numericCast(distance + 1))
            }
            _preconditionFailure("Advancing past end index")
        }
    }
    
    @inlinable
    public func distance(from start: Index, to end: Index) -> Int {
        switch (start, end) {
        case let (.inRange(left), .inRange(right)):
            // in range <--> in range
            return numericCast(left.distance(to: right))
        case let (.inRange(left), .pastEnd):
            // in range --> end
            return numericCast(1 + left.distance(to: upperBound))
        case let (.pastEnd, .inRange(right)):
            // in range <-- end
            return numericCast(upperBound.distance(to: right) - 1)
        case (.pastEnd, .pastEnd):
            // end <--> end
            return 0
        }
    }
    
    /// Accesses the element at specified position.
    ///
    /// You can subscript a collection with any valid index other than the
    /// collection's end index. The end index refers to the position one past
    /// the last element of a collection, so it doesn't correspond with an
    /// element.
    ///
    /// - Parameter position: The position of the element to access. `position`
    ///   must be a valid index of the range, and must not equal the range's end
    ///   index.
    @inlinable
    public subscript(position: Index) -> Bound {
        // FIXME: swift-3-indexing-model: range checks and tests.
        switch position {
        case .inRange(let x): return x
        case .pastEnd: _preconditionFailure("Index out of range")
        }
    }
    
    @inlinable
    public subscript(bounds: Range<Index>)
        -> Slice<ClosedRange<Bound>> {
            return Slice(base: self, bounds: bounds)
    }
    
    @inlinable
    public func _customContainsEquatableElement(_ element: Bound) -> Bool? {
        return lowerBound <= element && element <= upperBound
    }
    
    @inlinable
    public func _customIndexOfEquatableElement(_ element: Bound) -> Index?? {
        return lowerBound <= element && element <= upperBound
            ? .inRange(element) : nil
    }
    
    @inlinable
    public func _customLastIndexOfEquatableElement(_ element: Bound) -> Index?? {
        // The first and last elements are the same because each element is unique.
        return _customIndexOfEquatableElement(element)
    }
}

/*
 ... 是一个特殊的操作符, 返回一个特定类型的对象.
 */
extension Comparable {  
    @_transparent
    public static func ... (minimum: Self, maximum: Self) -> ClosedRange<Self> {
        _precondition(
            minimum <= maximum, "Can't form Range with upperBound < lowerBound")
        return ClosedRange(uncheckedBounds: (lower: minimum, upper: maximum))
    }
}

/*
 还是直接的成员变量的判等操作.
 */
extension ClosedRange: Equatable {
    @inlinable
    public static func == (
        lhs: ClosedRange<Bound>, rhs: ClosedRange<Bound>
    ) -> Bool {
        return lhs.lowerBound == rhs.lowerBound && lhs.upperBound == rhs.upperBound
    }
}

extension ClosedRange: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(
            self, children: ["lowerBound": lowerBound, "upperBound": upperBound])
    }
}

/*
 这个函数有问题啊, 最终还是有值的.
 也是因为, 对于 CloseRange 这个类型, 是没有办法去表示空这个状态的.
 */
extension ClosedRange {
    @inlinable // trivial-implementation
    @inline(__always)
    public func clamped(to limits: ClosedRange) -> ClosedRange {
        let lower =
            limits.lowerBound > self.lowerBound ? limits.lowerBound
                : limits.upperBound < self.lowerBound ? limits.upperBound
                : self.lowerBound
        let upper =
            limits.upperBound < self.upperBound ? limits.upperBound
                : limits.lowerBound > self.upperBound ? limits.lowerBound
                : self.upperBound
        return ClosedRange(uncheckedBounds: (lower: lower, upper: upper))
    }
}

extension ClosedRange where Bound: Strideable, Bound.Stride: SignedInteger {
    @inlinable
    public init(_ other: Range<Bound>) {
        _precondition(!other.isEmpty, "Can't form an empty closed range")
        let upperBound = other.upperBound.advanced(by: -1)
        self.init(uncheckedBounds: (lower: other.lowerBound, upper: upperBound))
    }
}

extension ClosedRange {
    @inlinable
    public func overlaps(_ other: ClosedRange<Bound>) -> Bool {
        // Disjoint iff the other range is completely before or after our range.
        // Unlike a `Range`, a `ClosedRange` can *not* be empty, so no check for
        // that case is needed here.
        let isDisjoint = other.upperBound < self.lowerBound
            || self.upperBound < other.lowerBound
        return !isDisjoint
    }
    
    @inlinable
    public func overlaps(_ other: Range<Bound>) -> Bool {
        return other.overlaps(self)
    }
}
