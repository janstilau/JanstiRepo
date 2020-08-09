public protocol RangeExpression {
    associatedtype Bound: Comparable
    /*
     这个方法, 其实可以解释 array[..<4] 为什么可以运转.
     首先, 根据这个方法, 可以得到一个 range, range 里面是各个 index.
     然后就可以直接根据 index, 从 collection 里面取值了.
     */
    func relative<C: Collection>(
        to collection: C
    ) -> Range<Bound> where C.Index == Bound
    func contains(_ element: Bound) -> Bool
}

/*
 模式匹配的时候, 实际就是调用了该函数.
 所以, 该函数的结果, 决定了模式匹配的逻辑走向.
 对于 range 来说, 就是调用 contains 判断.
 */
extension RangeExpression {
    @inlinable
    public static func ~= (pattern: Self, value: Bound) -> Bool {
        return pattern.contains(value)
    }
}

/*
 前闭后开
 对于 range 的实际类型来说, 他仅仅是存储了边界的一些信息而已.
 */
@frozen
public struct Range<Bound: Comparable> {
    public let lowerBound: Bound
    public let upperBound: Bound
    @inlinable
    public init(uncheckedBounds bounds: (lower: Bound, upper: Bound)) {
        self.lowerBound = bounds.lower
        self.upperBound = bounds.upper
    }
    
    /*
     左闭右开, 左边 <=, 右边 <
     contains 的操作, 就是比较操作.
     contains 有着很多实现方式, 如果是关联式, 直接关联查找.
     如果是线性容器, 遍历查找.
     如果是排序后的线性容器, 二分查找.
     如果是范围, 直接边界值判断.
    */
    @inlinable
    public func contains(_ element: Bound) -> Bool {
        return lowerBound <= element && element < upperBound
    }
    
    @inlinable
    public var isEmpty: Bool {
        return lowerBound == upperBound
    }
}

/*
 如果, range 的边界, 是可以算出偏移量的, 那么 range 本身就可以当做 sequence 来看待.
 */
extension Range: Sequence
where Bound: Strideable, Bound.Stride: SignedInteger {
    public typealias Element = Bound
    public typealias Iterator = IndexingIterator<Range<Bound>>
}

/*
 如果, range 的边界, 是可以计算出偏移量的, 那么 range 也可以当做容器来看待.
 */
extension Range: Collection, BidirectionalCollection, RandomAccessCollection
    where Bound: Strideable, Bound.Stride: SignedInteger
{
    /// A type that represents a position in the range.
    public typealias Index = Bound
    public typealias Indices = Range<Bound>
    public typealias SubSequence = Range<Bound>
    
    // 容器的 startIterator, 就是 lowerBound, 下边界
    @inlinable
    public var startIndex: Index { return lowerBound }
    
    // 容器的 endIterator, 就是 upperBound, 上边界
    @inlinable
    public var endIndex: Index { return upperBound }
    
    /*
     如何进行 index 的变化. 是各个容器自己进行的.
     */
    @inlinable
    public func index(after i: Index) -> Index {
        _failEarlyRangeCheck(i, bounds: startIndex..<endIndex)
        // advanced 是 Strideable 提供的方法.
        return i.advanced(by: 1)
    }
    
    @inlinable
    public func index(before i: Index) -> Index {
        /*
         每个方法, 都会有着提前的判断.
         */
        _precondition(i > lowerBound)
        _precondition(i <= upperBound)
        return i.advanced(by: -1)
    }
    
    @inlinable
    public func index(_ i: Index, offsetBy n: Int) -> Index {
        let r = i.advanced(by: numericCast(n))
        _precondition(r >= lowerBound)
        _precondition(r <= upperBound)
        return r
    }
    
    @inlinable
    public func distance(from start: Index, to end: Index) -> Int {
        // distance 是  Strideable 提供的方法.
        return numericCast(start.distance(to: end))
    }
    
    /// Accesses the subsequence bounded by the given range.
    ///
    /// - Parameter bounds: A range of the range's indices. The upper and lower
    ///   bounds of the `bounds` range must be valid indices of the collection.
    @inlinable
    public subscript(bounds: Range<Index>) -> Range<Bound> {
        return bounds
    }
    
    /// The indices that are valid for subscripting the range, in ascending
    /// order.
    @inlinable
    public var indices: Indices {
        return self
    }
    
    @inlinable
    public func _customContainsEquatableElement(_ element: Element) -> Bool? {
        return lowerBound <= element && element < upperBound
    }
    
    @inlinable
    public func _customIndexOfEquatableElement(_ element: Bound) -> Index?? {
        return lowerBound <= element && element < upperBound ? element : nil
    }
    
    @inlinable
    public func _customLastIndexOfEquatableElement(_ element: Bound) -> Index?? {
        // The first and last elements are the same because each element is unique.
        return _customIndexOfEquatableElement(element)
    }
    
    /*
     这个方法, 和每个容器的实现相关, 所以, 不会有默认的实现.
     */
    @inlinable
    public subscript(position: Index) -> Element {
        return position
    }
}

/*
 对于一个 range 来说, 它是前闭后开的, 所以, 要在 closeRange 后 + 1
 */
extension Range where Bound: Strideable, Bound.Stride: SignedInteger {
    public init(_ other: ClosedRange<Bound>) {
        let upperBound = other.upperBound.advanced(by: 1)
        self.init(uncheckedBounds: (lower: other.lowerBound, upper: upperBound))
    }
}

extension Range: RangeExpression {
    @inlinable // trivial-implementation
    public func relative<C: Collection>(to collection: C) -> Range<Bound>
        where C.Index == Bound {
            return Range(uncheckedBounds: (lower: lowerBound, upper: upperBound))
    }
}

//clamped 就是取交集的意思.
extension Range {
    @inlinable // trivial-implementation
    @inline(__always)
    public func clamped(to limits: Range) -> Range {
        let lower =
            limits.lowerBound > self.lowerBound ? limits.lowerBound
                : limits.upperBound < self.lowerBound ? limits.upperBound
                : self.lowerBound
        let upper =
            limits.upperBound < self.upperBound ? limits.upperBound
                : limits.lowerBound > self.upperBound ? limits.lowerBound
                : self.upperBound
        return Range(uncheckedBounds: (lower: lower, upper: upper))
    }
}

extension Range: CustomStringConvertible {
    /// A textual representation of the range.
    @inlinable // trivial-implementation
    public var description: String {
        return "\(lowerBound)..<\(upperBound)"
    }
}

extension Range: CustomDebugStringConvertible {
    /// A textual representation of the range, suitable for debugging.
    public var debugDescription: String {
        return "Range(\(String(reflecting: lowerBound))"
            + "..<\(String(reflecting: upperBound)))"
    }
}

extension Range: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(
            self, children: ["lowerBound": lowerBound, "upperBound": upperBound])
    }
}

extension Range: Equatable {
    @inlinable
    public static func == (lhs: Range<Bound>, rhs: Range<Bound>) -> Bool {
        return
            lhs.lowerBound == rhs.lowerBound &&
                lhs.upperBound == rhs.upperBound
    }
}

extension Range: Hashable where Bound: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(lowerBound)
        hasher.combine(upperBound)
    }
}

extension Range: Decodable where Bound: Decodable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let lowerBound = try container.decode(Bound.self)
        let upperBound = try container.decode(Bound.self)
        guard lowerBound <= upperBound else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize \(Range.self) with a lowerBound (\(lowerBound)) greater than upperBound (\(upperBound))"))
        }
        self.init(uncheckedBounds: (lower: lowerBound, upper: upperBound))
    }
}

extension Range: Encodable where Bound: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.lowerBound)
        try container.encode(self.upperBound)
    }
}

/*
 只有上边界的 Range.
 */
@frozen
public struct PartialRangeUpTo<Bound: Comparable> {
    public let upperBound: Bound
    
    @inlinable // trivial-implementation
    public init(_ upperBound: Bound) { self.upperBound = upperBound }
}

extension PartialRangeUpTo: RangeExpression {
    /*
     PartialRangeUpTo 放到 colleciton 中, 用 colleciton 的 startIndex 和自己的 upperBound
     */
    public func relative<C: Collection>(to collection: C) -> Range<Bound>
        where C.Index == Bound {
            return collection.startIndex..<self.upperBound
    }
    
    /*
     只比较一边.
     */
    @_transparent
    public func contains(_ element: Bound) -> Bool {
        return element < upperBound
    }
}

extension PartialRangeUpTo: Decodable where Bound: Decodable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        try self.init(container.decode(Bound.self))
    }
}

extension PartialRangeUpTo: Encodable where Bound: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.upperBound)
    }
}

/*
 只有上边界的 Range, 后闭
 */
@frozen
public struct PartialRangeThrough<Bound: Comparable> {  
    public let upperBound: Bound
    @inlinable // trivial-implementation
    public init(_ upperBound: Bound) { self.upperBound = upperBound }
}

extension PartialRangeThrough: RangeExpression {
    @_transparent
    public func relative<C: Collection>(to collection: C) -> Range<Bound>
        where C.Index == Bound {
            return collection.startIndex..<collection.index(after: self.upperBound)
    }
    @_transparent
    public func contains(_ element: Bound) -> Bool {
        return element <= upperBound
    }
}

extension PartialRangeThrough: Decodable where Bound: Decodable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        try self.init(container.decode(Bound.self))
    }
}

extension PartialRangeThrough: Encodable where Bound: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.upperBound)
    }
}
/*
 只有下边界的 range.
 */
@frozen
public struct PartialRangeFrom<Bound: Comparable> {
    public let lowerBound: Bound
    
    @inlinable // trivial-implementation
    public init(_ lowerBound: Bound) { self.lowerBound = lowerBound }
}

extension PartialRangeFrom: RangeExpression {
    @_transparent
    public func relative<C: Collection>(
        to collection: C
    ) -> Range<Bound> where C.Index == Bound {
        return self.lowerBound..<collection.endIndex
    }
    @inlinable // trivial-implementation
    public func contains(_ element: Bound) -> Bool {
        return lowerBound <= element
    }
}

extension PartialRangeFrom: Sequence
    where Bound: Strideable, Bound.Stride: SignedInteger
{
    public typealias Element = Bound
    
    /// The iterator for a `PartialRangeFrom` instance.
    @frozen
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        internal var _current: Bound
        @inlinable
        public init(_current: Bound) { self._current = _current }
        
        /*
         _current 的值, 在返回之后, 进行了更新.
         能够这样做, 是因为这是一个值对象, 本身值在函数返回的时候, 已经进行了复制.
         */
        @inlinable
        public mutating func next() -> Bound? {
            defer { _current = _current.advanced(by: 1) }
            return _current
        }
    }
    
    @inlinable
    public __consuming func makeIterator() -> Iterator {
        return Iterator(_current: lowerBound)
    }
}

extension PartialRangeFrom: Decodable where Bound: Decodable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        try self.init(container.decode(Bound.self))
    }
}

extension PartialRangeFrom: Encodable where Bound: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.lowerBound)
    }
}

/*
 这就是, 为什么 ..<, ... 能够使用的原因, 他们被操作符重载了.
 */
extension Comparable {
    // 双元运算符
    @_transparent
    public static func ..< (minimum: Self, maximum: Self) -> Range<Self> {
        return Range(uncheckedBounds: (lower: minimum, upper: maximum))
    }
    // 前缀运算符
    @_transparent
    public static prefix func ..< (maximum: Self) -> PartialRangeUpTo<Self> {
        return PartialRangeUpTo(maximum)
    }
    
    @_transparent
    public static prefix func ... (maximum: Self) -> PartialRangeThrough<Self> {
        return PartialRangeThrough(maximum)
    }
    
    @_transparent
    public static postfix func ... (minimum: Self) -> PartialRangeFrom<Self> {
        return PartialRangeFrom(minimum)
    }
}

/// A range expression that represents the entire range of a collection.
///
/// You can use the unbounded range operator (`...`) to create a slice of a
/// collection that contains all of the collection's elements. Slicing with an
/// unbounded range is essentially a conversion of a collection instance into
/// its slice type.
///
/// For example, the following code declares `countLetterChanges(_:_:)`, a
/// function that finds the number of changes required to change one
/// word or phrase into another. The function uses a recursive approach to
/// perform the same comparisons on smaller and smaller pieces of the original
/// strings. In order to use recursion without making copies of the strings at
/// each step, `countLetterChanges(_:_:)` uses `Substring`, a string's slice
/// type, for its parameters.
///
///     func countLetterChanges(_ s1: Substring, _ s2: Substring) -> Int {
///         if s1.isEmpty { return s2.count }
///         if s2.isEmpty { return s1.count }
///
///         let cost = s1.first == s2.first ? 0 : 1
///
///         return min(
///             countLetterChanges(s1.dropFirst(), s2) + 1,
///             countLetterChanges(s1, s2.dropFirst()) + 1,
///             countLetterChanges(s1.dropFirst(), s2.dropFirst()) + cost)
///     }
///
/// To call `countLetterChanges(_:_:)` with two strings, use an unbounded
/// range in each string's subscript.
///
///     let word1 = "grizzly"
///     let word2 = "grisly"
///     let changes = countLetterChanges(word1[...], word2[...])
///     // changes == 2
@frozen // namespace
public enum UnboundedRange_ {
    // FIXME: replace this with a computed var named `...` when the language makes
    // that possible.
    
    /// Creates an unbounded range expression.
    ///
    /// The unbounded range operator (`...`) is valid only within a collection's
    /// subscript.
    public static postfix func ... (_: UnboundedRange_) -> () {
        // This function is uncallable
    }
}

/// The type of an unbounded range operator.
public typealias UnboundedRange = (UnboundedRange_)->()

extension Collection {
    /// Accesses the contiguous subrange of the collection's elements specified
    /// by a range expression.
    ///
    /// The range expression is converted to a concrete subrange relative to this
    /// collection. For example, using a `PartialRangeFrom` range expression
    /// with an array accesses the subrange from the start of the range
    /// expression until the end of the array.
    ///
    ///     let streets = ["Adams", "Bryant", "Channing", "Douglas", "Evarts"]
    ///     let streetsSlice = streets[2...]
    ///     print(streetsSlice)
    ///     // ["Channing", "Douglas", "Evarts"]
    ///
    /// The accessed slice uses the same indices for the same elements as the
    /// original collection uses. This example searches `streetsSlice` for one
    /// of the strings in the slice, and then uses that index in the original
    /// array.
    ///
    ///     let index = streetsSlice.firstIndex(of: "Evarts")    // 4
    ///     print(streets[index!])
    ///     // "Evarts"
    ///
    /// Always use the slice's `startIndex` property instead of assuming that its
    /// indices start at a particular value. Attempting to access an element by
    /// using an index outside the bounds of the slice's indices may result in a
    /// runtime error, even if that index is valid for the original collection.
    ///
    ///     print(streetsSlice.startIndex)
    ///     // 2
    ///     print(streetsSlice[2])
    ///     // "Channing"
    ///
    ///     print(streetsSlice[0])
    ///     // error: Index out of bounds
    ///
    /// - Parameter bounds: A range of the collection's indices. The bounds of
    ///   the range must be valid indices of the collection.
    ///
    /// - Complexity: O(1)
    @inlinable
    public subscript<R: RangeExpression>(r: R)
        -> SubSequence where R.Bound == Index {
            return self[r.relative(to: self)]
    }
    
    @inlinable
    public subscript(x: UnboundedRange) -> SubSequence {
        return self[startIndex...]
    }
}

/*
 这就是, range 为什么可以用在 colleciton 里面的原因.
 */
extension MutableCollection {
    @inlinable
    public subscript<R: RangeExpression>(r: R) -> SubSequence
        where R.Bound == Index {
        get {
            return self[r.relative(to: self)]
        }
        set {
            self[r.relative(to: self)] = newValue
        }
    }
    
    @inlinable
    public subscript(x: UnboundedRange) -> SubSequence {
        get {
            return self[startIndex...]
        }
        set {
            self[startIndex...] = newValue
        }
    }
}

/*
 Overlap support
 */

extension Range {
    @inlinable
    public func overlaps(_ other: Range<Bound>) -> Bool {
        let isDisjoint =
            other.upperBound <= self.lowerBound
            || self.upperBound <= other.lowerBound
            || self.isEmpty || other.isEmpty
        return !isDisjoint
    }
    
    @inlinable
    public func overlaps(_ other: ClosedRange<Bound>) -> Bool {
        let isDisjoint = other.upperBound < self.lowerBound
            || self.upperBound <= other.lowerBound
            || self.isEmpty
        return !isDisjoint
    }
}

