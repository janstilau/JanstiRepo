
public protocol RangeExpression {
    // 有一个类型, 作为边界的类型. 因为会有着 partial 的类型, 所以这里仅仅是设立了类型, 但是没有指定成员变量.
    // 能够完成表示 范围的概念, 就是两个值, 左右边界
    // partial 概念的, 就一个值, 一边的边界. 然后类型表明取值是边界的左边还是右边.
    associatedtype Bound: Comparable
    
    // 因为 Collection 是大量使用了 Subscript[Range]的操作, 所以, RangeExpression 里面, 专门有着一个对于 Collection 的操作. 其实, 就是获取 Collection 语义下的Index 的范围.
    // 正式因为有这个, 才能实现 Colleciton[1...] 这种操作, 不会无限.
    // 一般来说, 不会直接使用这个方法, 这在 Colelction 的 SubScript 方法里面, 会自动调用.
    func relative<C: Collection>(
        to collection: C
    ) -> Range<Bound> where C.Index == Bound
    
    // 可以判断, 值在没在范围里面
    // 其实可以增加几个, 判断值在范围的左右.
    func contains(_ element: Bound) -> Bool
}

// range 对于模式识别的适配, Switch 本质上, 就是不断的 if 判断. 当是 range 的时候, 可以直接调用 ~= 操作符.
extension RangeExpression {
    public static func ~= (pattern: Self, value: Bound) -> Bool {
        return pattern.contains(value)
    }
}

// Stride 是天然可以 sequence 的, 因为可以评判差距, 就代表着可以根据 stride 计算出下一个值来, 这样, next 函数就能取到下一个值来.
// CompareAble, 比如单词在字典里面, 单词的 next 是没有一个统一的算法可以计算出来的. 只能判断大小, 无法判断两个单词之间的差距.
// Range 是 Comparable 的, 就如同名字显示的那样, 它表示的抽象, 是范围. 也就是能判断一个值, 是否处于范围内, 是在范围的 left, right. 但是, 并不能判断, 范围内的值之间的范围.
public struct Range<Bound: Comparable> {
    public let lowerBound: Bound
    public let upperBound: Bound
    public init(uncheckedBounds bounds: (lower: Bound, upper: Bound)) {
        self.lowerBound = bounds.lower
        self.upperBound = bounds.upper
    }
    
    // Sequence 的 contains, 是遍历 + 相等性判断. 而 Range, 直接用上下标的 比较操作符就可以了.
    // Range 在某些情况下, 可以是 Sequence, 而 Sequence 有埋点, 是否可以快速判断是否 contains. Range 就要实现这个埋点, 用自己的高效的 contains 方法, 来做 contains 的实现
    public func contains(_ element: Bound) -> Bool {
        return lowerBound <= element && element < upperBound
    }
    public var isEmpty: Bool {
        return lowerBound == upperBound
    }
}

// 这里, Range 在 Bound: Strideable, Bound.Stride: SignedInteger 的时候, 实现 Sequence 是依靠了 Collection
// Strideable 是, 可以比较大小, 可以衡量两个值之间的差距.
// SignedInteger 是, 可以用整数表示差距.
extension Range: Sequence
where Bound: Strideable, Bound.Stride: SignedInteger {
    public typealias Element = Bound
    public typealias Iterator = IndexingIterator<Range<Bound>>
}

// Range 实现 Collection.
/*
 Collection 的主要责任, 可以 index 访问值. Index 是各个 Collection 自己进行规定.
 需要实现, startIndex, 也就是 beginIterator, endIndex, 也就是 endIterator
 formIndex, 也就是 Itertor 的++ 操作.
 [idx] get, 也就是根据 iterator 的 * 操作.
 默认的 IndexingIterator, 其实是根据 collection 的上述操作完成的. 将抽象, 从各个 Collection 的 iterator, 转移到了 Colleciton
 
 
 BidirectionalCollection 的主要责任是, 可以实现 iterator -- 的操作, 在 Collection 层面, 就是实现
 formIndex(before) 操作.
 当可以向前遍历的时候, 就可以有了从后开始的一些操作, 例如 suffix, removeLast, popLast 等等
 
 RandomAccessCollection, 主要责任是, 可以快速进行 Index 的计算, 也就是 Index 应该是 Strideable.
 这个主要是算法层面上的考虑, 因为 Collection 的设计就是, 有的 Index 一定可以取出值来, 所以, Index 如何能够快速的计算出对应位置的 Index 是关键.
 */

extension Range: Collection, BidirectionalCollection, RandomAccessCollection
where Bound: Strideable, Bound.Stride: SignedInteger
{
    public typealias Index = Bound
    public typealias Indices = Range<Bound>
    public typealias SubSequence = Range<Bound>
    
    public var startIndex: Index { return lowerBound }
    public var endIndex: Index { return upperBound }
    // advanced(by: 1), 这个能力, 是 Strideable 的能力.
    public func index(after i: Index) -> Index {
        return i.advanced(by: 1)
    }
    public func index(before i: Index) -> Index {
        return i.advanced(by: -1)
    }
    public func index(_ i: Index, offsetBy n: Int) -> Index {
        // 直接利用 Strideable 的能力.
        let r = i.advanced(by: numericCast(n))
        return r
    }
    public func distance(from start: Index, to end: Index) -> Int {
        // 直接利用 Strideable 的能力.
        return numericCast(start.distance(to: end))
    }
    
    // 索引的集合, 就是索引本身. 这个过程就好像是, 数组里面存的值就是数组的下标.
    public subscript(bounds: Range<Index>) -> Range<Bound> {
        return bounds
    }
    
    public var indices: Indices {
        return self
    }
    
    // Sequence 的埋点, 可以快速的判断是否 contains.
    public func _customContainsEquatableElement(_ element: Element) -> Bool? {
        return lowerBound <= element && element < upperBound
    }
    // Sequence 的埋点,
    public func _customIndexOfEquatableElement(_ element: Bound) -> Index?? {
        return lowerBound <= element && element < upperBound ? element : nil
    }
    // Sequence 的埋点,
    public func _customLastIndexOfEquatableElement(_ element: Bound) -> Index?? {
        // The first and last elements are the same because each element is unique.
        return _customIndexOfEquatableElement(element)
    }
    
    // Collection 通过下标取值, 取的就是自己.
    public subscript(position: Index) -> Element {
        return position
    }
}

// Range 和 closeRange 的转化. 就是 EndPosition. 因为 ClosedRange 是包含最后一个值的, 而 Range 是不会取最后一个值的.
extension Range where Bound: Strideable, Bound.Stride: SignedInteger {
    public init(_ other: ClosedRange<Bound>) {
        let upperBound = other.upperBound.advanced(by: 1)
        self.init(uncheckedBounds: (lower: other.lowerBound, upper: upperBound))
    }
}

// Range, 对于 RangeExpression 的适配.
extension Range: RangeExpression {
    public func relative<C: Collection>(to collection: C) -> Range<Bound>
    where C.Index == Bound {
        return Range(uncheckedBounds: (lower: lowerBound, upper: upperBound))
    }
}

extension Range {
    // Range 的坍塌.
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

// Range 的相等, 就是里面的两个值判等.
extension Range: Equatable {
    public static func == (lhs: Range<Bound>, rhs: Range<Bound>) -> Bool {
        return
            lhs.lowerBound == rhs.lowerBound &&
            lhs.upperBound == rhs.upperBound
    }
}

// Range 对于 hash 的实现, 就是按顺序, 把 LowerBound, Upperbound 喂进去
extension Range: Hashable where Bound: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(lowerBound)
        hasher.combine(upperBound)
    }
}

// Range 对于 Codable 的适配, 是使用了 unkeyedContainer
extension Range: Decodable where Bound: Decodable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        // 这里当 lowerBound > upperBound 会抛出错误.
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

// ..< , 只有一侧有限制的 Range
public struct PartialRangeUpTo<Bound: Comparable> {
    public let upperBound: Bound
    public init(_ upperBound: Bound) { self.upperBound = upperBound }
}

// 和 Collection 进行相交运算的时候, 取 Collection 的 start 作为起点.
extension PartialRangeUpTo: RangeExpression {
    public func relative<C: Collection>(to collection: C) -> Range<Bound>
    where C.Index == Bound {
        return collection.startIndex..<self.upperBound
    }
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


// ..., ThroughPartialRange
public struct PartialRangeThrough<Bound: Comparable> {  
    public let upperBound: Bound
    public init(_ upperBound: Bound) { self.upperBound = upperBound }
}

// 同样的, 也有着和 Collection 的相交的工作.
extension PartialRangeThrough: RangeExpression {
    public func relative<C: Collection>(to collection: C) -> Range<Bound>
    where C.Index == Bound {
        return collection.startIndex..<collection.index(after: self.upperBound)
    }
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

// 可以, 使用这些 PartialRange 作为 Sequence, 但是使用的时候, 要自己去把握 infinity.
// 只有 lowerBound 的 range.
public struct PartialRangeFrom<Bound: Comparable> {
    public let lowerBound: Bound
    public init(_ lowerBound: Bound) { self.lowerBound = lowerBound }
}

extension PartialRangeFrom: RangeExpression {
    public func relative<C: Collection>(
        to collection: C
    ) -> Range<Bound> where C.Index == Bound {
        return self.lowerBound..<collection.endIndex
    }
    public func contains(_ element: Bound) -> Bool {
        return lowerBound <= element
    }
}

// 要注意, 这都是 uninfinite 的.
extension PartialRangeFrom: Sequence
where Bound: Strideable, Bound.Stride: SignedInteger
{
    public typealias Element = Bound
    
    public struct Iterator: IteratorProtocol {
        internal var _current: Bound
        public init(_current: Bound) { self._current = _current }
        
        // 这个 Next , 是永远不会终止的.
        public mutating func next() -> Bound? {
            defer { _current = _current.advanced(by: 1) }
            return _current
        }
    }
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



// 为什么 ... 这些操作符, 可以表示 Range 的原因就在这里. 专门有着对应的操作符的定义.
// 要分清 Range 和 Sequence 的差别. ... 生成的是一个 Range, 但是 Range 只有在合适的情况下, 才能当 Sequence 来用. for in 里面, 要填充的是一个 Sequence.
extension Comparable {
    // 到底是几元操作符, 是看参数的个数的.
    public static func ..< (minimum: Self, maximum: Self) -> Range<Self> {
        return Range(uncheckedBounds: (lower: minimum, upper: maximum))
    }
    public static prefix func ..< (maximum: Self) -> PartialRangeUpTo<Self> {
        return PartialRangeUpTo(maximum)
    }
    
    public static prefix func ... (maximum: Self) -> PartialRangeThrough<Self> {
        return PartialRangeThrough(maximum)
    }
    
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
    
    // 这里, 就是为什么, Colleciton[Range] 能够成功的原因, 里面有一个 relateive 的操作, 让 range 是处在 Collection 的 Start, endIndex 的约束内的
    public subscript<R: RangeExpression>(r: R)
    -> SubSequence where R.Bound == Index {
        return self[r.relative(to: self)]
    }
    
    public subscript(x: UnboundedRange) -> SubSequence {
        return self[startIndex...]
    }
}

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

// Range 对于 overlap 的实现.
extension Range {
    public func overlaps(_ other: Range<Bound>) -> Bool {
        let isDisjoint = other.upperBound <= self.lowerBound
            || self.upperBound <= other.lowerBound
            || self.isEmpty || other.isEmpty
        return !isDisjoint
    }
    
    public func overlaps(_ other: ClosedRange<Bound>) -> Bool {
        let isDisjoint = other.upperBound < self.lowerBound
            || self.upperBound <= other.lowerBound
            || self.isEmpty
        return !isDisjoint
    }
}

// Note: this is not for compatibility only, it is considered a useful
// shorthand. TODO: Add documentation
public typealias CountableRange<Bound: Strideable> = Range<Bound>
where Bound.Stride: SignedInteger

// Note: this is not for compatibility only, it is considered a useful
// shorthand. TODO: Add documentation
public typealias CountablePartialRangeFrom<Bound: Strideable> = PartialRangeFrom<Bound>
where Bound.Stride: SignedInteger
