public protocol RangeExpression {
    associatedtype Bound: Comparable
    /*
     这个方法, 其实可以解释 array[..<4] 为什么可以运转.
     首先, 根据这个方法, 可以得到一个 range, range 是 Index 组合而成的范围.
     但是这个范围, 有可能是半开的, 有可能是和 Collection 的 indices 不匹配的.
     所以, 这个函数的作用, 就是做一次相交, 用 Collection 的范围, 做一次过滤操作.
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
 Comparable 和 Strideable 还是有着挺大的区别的.
 Comparable 是可比较, 例如, 字符串的比较. 字符串的字典比较法, 可以判断出前后顺序来. 但是, 两个相隔的元素, 到底会有多少距离, 是没有办法固定出来的.
 Strideable, 则是坐标轴的概念. 可以准确的判断出, 坐标上的两个点, 之间有多少距离.
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
     Contains 的不同的实现方式.
     1. 线性的, 逐个比较.
     2. 排序过的, 二分查找.
     3. 有着特定算法的, 算法寻找. 比如哈希, 可以快速定位元素的位置.
     4. range 这种, 可以通过简单判断得出结论. 之前编辑器的 id 生成器就是用的这个策略.
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
 Range 可以当做 Sequence, 是因为它使用了 IndexingIterator 作为自己的迭代器.
 而 IndexingIterator 之所以可以使用, 是因为 range 实现了 Colleciton
 IndexingIterator 是完全使用 Collection 的功能, 进行的迭代.
 */
extension Range: Sequence
where Bound: Strideable, Bound.Stride: SignedInteger {
    public typealias Element = Bound
    public typealias Iterator = IndexingIterator<Range<Bound>>
}

/*
 如果, Bound 是 strideable 的.
 */
extension Range: Collection, BidirectionalCollection, RandomAccessCollection
    where Bound: Strideable, Bound.Stride: SignedInteger
{
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
     index 的变化, 是利用了 Index 的 Strideable 的能力.
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
         作为一个功能类, 要自己在内部, 做数据的校验工作.
         */
        _precondition(i > lowerBound)
        _precondition(i <= upperBound)
        return i.advanced(by: -1)
    }
    
    /*
     index 的变化, 是利用了 Index 的 Strideable 的能力.
    */
    @inlinable
    public func index(_ i: Index, offsetBy n: Int) -> Index {
        let r = i.advanced(by: numericCast(n))
        _precondition(r >= lowerBound)
        _precondition(r <= upperBound)
        return r
    }
    
    /*
     index 的变化, 是利用了 Index 的 Strideable 的能力.
    */
    @inlinable
    public func distance(from start: Index, to end: Index) -> Int {
        // distance 是  Strideable 提供的方法.
        return numericCast(start.distance(to: end))
    }
    
    /*
     Colleciton, 给外界的观点就是关联式容器.
     Index 为 key, 对应的值为 value.
     对于 range 来说, Index 为 key, 对应的值也是 Index.
     */
    @inlinable
    public subscript(bounds: Range<Index>) -> Range<Bound> {
        return bounds
    }
    
    @inlinable
    public var indices: Indices {
        return self
    }
    
    /*
     这个是 sequence 的能力. 算作是 contains 这个方法里面的一个切口.
     _customContainsEquatableElement 是 primitive 方法, 所以子类如果有着更好的设计, 可以通过该方法, 快速判断是否 contains.
     例如, Dictionay 里面, 就是重新了这个方法, 进行了 哈希表的快速判断.
     如果没有实现该方法, 就是遍历操作.
     */
    @inlinable
    public func _customContainsEquatableElement(_ element: Element) -> Bool? {
        return lowerBound <= element && element < upperBound
    }
    
    /*
     这个是 Collection 的能力, 算作是 firt, lastIndex 方法里面的一个切口.
     这是一个 primitive 方法, 所以子类如果有着更好的设计, 可以通过该方法, 快速得到对应的 Index.
     例如, Dictionary 里面, 就是重新了和这个方法, 进行了 哈希表的快速判断.
     如果没有实现该方法, 就是遍历操作.
     */
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
     这个函数, 是最最重要的方法了.
     可以说, Colleciton 作为容器获取值, 就是通过这个方法.
     对于 Range 来说, key 就是 value, 所以传过来什么传出去什么.
     */
    @inlinable
    public subscript(position: Index) -> Element {
        return position
    }
}

/*
 对于一个 range 来说, 它是前闭后开的, 所以, 传过来一个 ClosedRange, 需要在 ClosedRange 后进行 +1 操作.
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

extension Range: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(
            self, children: ["lowerBound": lowerBound, "upperBound": upperBound])
    }
}

/*
 相等判断, 是各个类进行的. 一般来说, 就是重要的成员变量的相等性判断.
 */
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
 one-sided range
 2...
 ...2
 ..<2
 所以, 虽然有着各种各样的 one side range, 但是在实际的内存表示上, 还是只会有一个值, 然后将单侧区间这个事情, 用一个特殊的类表示相关的逻辑.
 */
@frozen
public struct PartialRangeUpTo<Bound: Comparable> {
    public let upperBound: Bound // 真正存储的, 也就这一个值.
    
    @inlinable
    public init(_ upperBound: Bound) { self.upperBound = upperBound }
}

extension PartialRangeUpTo: RangeExpression {
    /*
     通过, collection 的 start, 以及 end, 配合 range, 确定最终的范围大小.
     */
    public func relative<C: Collection>(to collection: C) -> Range<Bound>
        where C.Index == Bound {
            return collection.startIndex..<self.upperBound
    }
    
    /*
     判断是否包含的时候, 只通过一边进行判断.
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
 这些特殊的运算符, 结果就是生成特殊类型的数据.
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
 Collection, 首先会做自己的计算, 把范围控制在一个合理的范围.
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

