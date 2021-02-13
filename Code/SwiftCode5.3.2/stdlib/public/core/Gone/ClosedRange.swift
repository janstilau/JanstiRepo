// 前闭后开, 其实是通用的表示范围的方式. 所以 Swift 里面的 Range, 表示的就是前闭后开的概念.
// 而前闭后闭, 则专门有一个叫做 ClosedRange 这个类来表示.
// Float 作为 Bound, 是不能作为 Sequence 的, 因为 Float 的 stride 无法确定出来.
public struct ClosedRange<Bound: Comparable> {
    public let lowerBound: Bound
    public let upperBound: Bound
    
    public init(uncheckedBounds bounds: (lower: Bound, upper: Bound)) {
        self.lowerBound = bounds.lower
        self.upperBound = bounds.upper
    }
}

extension ClosedRange {
    // 前闭后闭的 range, 不可能空. 一定有一个值.
    public var isEmpty: Bool {
        return false
    }
}

extension ClosedRange: RangeExpression {
    // 和 Collection 的相交处理.
    public func relative<C: Collection>(to collection: C) -> Range<Bound>
    where C.Index == Bound {
        return Range(
            uncheckedBounds: (
                lower: lowerBound, upper: collection.index(after: self.upperBound)))
    }
    // Contains 处理的时候, 增加了相等性的判断.
    public func contains(_ element: Bound) -> Bool {
        return element >= self.lowerBound && element <= self.upperBound
    }
}

// 同样的, Close 对于 Sequence 的适配,  是建立在 Collection 的基础上的.
extension ClosedRange: Sequence
where Bound: Strideable, Bound.Stride: SignedInteger {
    public typealias Element = Bound
    public typealias Iterator = IndexingIterator<ClosedRange<Bound>>
}

extension ClosedRange where Bound: Strideable, Bound.Stride: SignedInteger {
    // public typealias Index = Bound 在 Range 里面, Index 就是 Bound.
    public enum Index {
        case pastEnd
        case inRange(Bound)
    }
}

// 这里, 其实不太明白, 直接使用 Bound 会有什么问题.
extension ClosedRange.Index: Comparable {
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

extension ClosedRange: Collection, BidirectionalCollection, RandomAccessCollection
where Bound: Strideable, Bound.Stride: SignedInteger
{
    public typealias SubSequence = Slice<ClosedRange<Bound>>
    
    public var startIndex: Index {
        return .inRange(lowerBound)
    }
    
    public var endIndex: Index {
        return .pastEnd
    }
    
    public func index(after i: Index) -> Index {
        switch i {
        case .inRange(let x):
            return x == upperBound
                ? .pastEnd
                : .inRange(x.advanced(by: 1))
        case .pastEnd:
            // 应该是这里, .pastEnd 之后, 不能再进行后移的处理了.
            // 但是 Range 里面就可以啊.
            _preconditionFailure("Incrementing past end index")
        }
    }
    
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

extension Comparable {  
    /// Returns a closed range that contains both of its bounds.
    ///
    /// Use the closed range operator (`...`) to create a closed range of any type
    /// that conforms to the `Comparable` protocol. This example creates a
    /// `ClosedRange<Character>` from "a" up to, and including, "z".
    ///
    ///     let lowercase = "a"..."z"
    ///     print(lowercase.contains("z"))
    ///     // Prints "true"
    ///
    /// - Parameters:
    ///   - minimum: The lower bound for the range.
    ///   - maximum: The upper bound for the range.
    @_transparent
    public static func ... (minimum: Self, maximum: Self) -> ClosedRange<Self> {
        _precondition(
            minimum <= maximum, "Can't form Range with upperBound < lowerBound")
        return ClosedRange(uncheckedBounds: (lower: minimum, upper: maximum))
    }
}

extension ClosedRange: Equatable {
    /// Returns a Boolean value indicating whether two ranges are equal.
    ///
    /// Two ranges are equal when they have the same lower and upper bounds.
    ///
    ///     let x = 5...15
    ///     print(x == 5...15)
    ///     // Prints "true"
    ///     print(x == 10...20)
    ///     // Prints "false"
    ///
    /// - Parameters:
    ///   - lhs: A range to compare.
    ///   - rhs: Another range to compare.
    @inlinable
    public static func == (
        lhs: ClosedRange<Bound>, rhs: ClosedRange<Bound>
    ) -> Bool {
        return lhs.lowerBound == rhs.lowerBound && lhs.upperBound == rhs.upperBound
    }
}

extension ClosedRange: Hashable where Bound: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(lowerBound)
        hasher.combine(upperBound)
    }
}

extension ClosedRange: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(
            self, children: ["lowerBound": lowerBound, "upperBound": upperBound])
    }
}

extension ClosedRange {
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
    public init(_ other: Range<Bound>) {
        let upperBound = other.upperBound.advanced(by: -1)
        self.init(uncheckedBounds: (lower: other.lowerBound, upper: upperBound))
    }
}

extension ClosedRange {
    @inlinable
    public func overlaps(_ other: ClosedRange<Bound>) -> Bool {
        let isDisjoint = other.upperBound < self.lowerBound
            || self.upperBound < other.lowerBound
        return !isDisjoint
    }
    
    @inlinable
    public func overlaps(_ other: Range<Bound>) -> Bool {
        return other.overlaps(self)
    }
}

public typealias CountableClosedRange<Bound: Strideable> = ClosedRange<Bound>
where Bound.Stride: SignedInteger

extension ClosedRange: Decodable where Bound: Decodable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let lowerBound = try container.decode(Bound.self)
        let upperBound = try container.decode(Bound.self)
        guard lowerBound <= upperBound else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize \(ClosedRange.self) with a lowerBound (\(lowerBound)) greater than upperBound (\(upperBound))"))
        }
        self.init(uncheckedBounds: (lower: lowerBound, upper: upperBound))
    }
}

extension ClosedRange: Encodable where Bound: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.lowerBound)
        try container.encode(self.upperBound)
    }
}
