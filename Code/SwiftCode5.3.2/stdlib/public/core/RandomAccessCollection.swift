// Random 的需要的限制, 就是可以快速的计算出, Index after n 的位置, 以及计算出, 连个 Index 之间的距离.

public protocol RandomAccessCollection: BidirectionalCollection
where SubSequence: RandomAccessCollection, Indices: RandomAccessCollection
{
    override associatedtype Element
    override associatedtype Index
    override associatedtype SubSequence
    override associatedtype Indices
    
    override var indices: Indices { get }
    
    override subscript(bounds: Range<Index>) -> SubSequence { get }
    
    override subscript(position: Index) -> Element { get }
    override var startIndex: Index { get }
    override var endIndex: Index { get }
    
    // random, 自然而然应该是 bidirection 的
    override func index(before i: Index) -> Index
    override func formIndex(before i: inout Index)
    
    override func index(after i: Index) -> Index
    override func formIndex(after i: inout Index)
    
    /// Returns an index that is the specified distance from the given index.
    ///
    /// The following example obtains an index advanced four positions from a
    /// string's starting index and then prints the character at that position.
    ///
    ///     let s = "Swift"
    ///     let i = s.index(s.startIndex, offsetBy: 4)
    ///     print(s[i])
    ///     // Prints "t"
    ///
    /// The value passed as `distance` must not offset `i` beyond the bounds of
    /// the collection.
    ///
    /// - Parameters:
    ///   - i: A valid index of the collection.
    ///   - distance: The distance to offset `i`. `distance` must not be negative
    ///     unless the collection conforms to the `BidirectionalCollection`
    ///     protocol.
    /// - Returns: An index offset by `distance` from the index `i`. If
    ///   `distance` is positive, this is the same value as the result of
    ///   `distance` calls to `index(after:)`. If `distance` is negative, this
    ///   is the same value as the result of `abs(distance)` calls to
    ///   `index(before:)`.
    ///
    /// - Complexity: O(1)
    @_nonoverride func index(_ i: Index, offsetBy distance: Int) -> Index
    
    /// Returns an index that is the specified distance from the given index,
    /// unless that distance is beyond a given limiting index.
    ///
    /// The following example obtains an index advanced four positions from a
    /// string's starting index and then prints the character at that position.
    /// The operation doesn't require going beyond the limiting `s.endIndex`
    /// value, so it succeeds.
    ///
    ///     let s = "Swift"
    ///     if let i = s.index(s.startIndex, offsetBy: 4, limitedBy: s.endIndex) {
    ///         print(s[i])
    ///     }
    ///     // Prints "t"
    ///
    /// The next example attempts to retrieve an index six positions from
    /// `s.startIndex` but fails, because that distance is beyond the index
    /// passed as `limit`.
    ///
    ///     let j = s.index(s.startIndex, offsetBy: 6, limitedBy: s.endIndex)
    ///     print(j)
    ///     // Prints "nil"
    ///
    /// The value passed as `distance` must not offset `i` beyond the bounds of
    /// the collection, unless the index passed as `limit` prevents offsetting
    /// beyond those bounds.
    ///
    /// - Parameters:
    ///   - i: A valid index of the collection.
    ///   - distance: The distance to offset `i`. `distance` must not be negative
    ///     unless the collection conforms to the `BidirectionalCollection`
    ///     protocol.
    ///   - limit: A valid index of the collection to use as a limit. If
    ///     `distance > 0`, a limit that is less than `i` has no effect.
    ///     Likewise, if `distance < 0`, a limit that is greater than `i` has no
    ///     effect.
    /// - Returns: An index offset by `distance` from the index `i`, unless that
    ///   index would be beyond `limit` in the direction of movement. In that
    ///   case, the method returns `nil`.
    ///
    /// - Complexity: O(1)
    @_nonoverride func index(
        _ i: Index, offsetBy distance: Int, limitedBy limit: Index
    ) -> Index?
    
    /// Returns the distance between two indices.
    ///
    /// Unless the collection conforms to the `BidirectionalCollection` protocol,
    /// `start` must be less than or equal to `end`.
    ///
    /// - Parameters:
    ///   - start: A valid index of the collection.
    ///   - end: Another valid index of the collection. If `end` is equal to
    ///     `start`, the result is zero.
    /// - Returns: The distance between `start` and `end`. The result can be
    ///   negative only if the collection conforms to the
    ///   `BidirectionalCollection` protocol.
    ///
    /// - Complexity: O(1)
    @_nonoverride func distance(from start: Index, to end: Index) -> Int
}

// TODO: swift-3-indexing-model - (By creating an ambiguity?), try to
// make sure RandomAccessCollection models implement
// index(_:offsetBy:) and distance(from:to:), or they will get the
// wrong complexity.

/// Default implementation for random access collections.
extension RandomAccessCollection {
    /// Returns an index that is the specified distance from the given index,
    /// unless that distance is beyond a given limiting index.
    ///
    /// The following example obtains an index advanced four positions from an
    /// array's starting index and then prints the element at that position. The
    /// operation doesn't require going beyond the limiting `numbers.endIndex`
    /// value, so it succeeds.
    ///
    ///     let numbers = [10, 20, 30, 40, 50]
    ///     let i = numbers.index(numbers.startIndex, offsetBy: 4)
    ///     print(numbers[i])
    ///     // Prints "50"
    ///
    /// The next example attempts to retrieve an index ten positions from
    /// `numbers.startIndex`, but fails, because that distance is beyond the
    /// index passed as `limit`.
    ///
    ///     let j = numbers.index(numbers.startIndex,
    ///                           offsetBy: 10,
    ///                           limitedBy: numbers.endIndex)
    ///     print(j)
    ///     // Prints "nil"
    ///
    /// The value passed as `distance` must not offset `i` beyond the bounds of
    /// the collection, unless the index passed as `limit` prevents offsetting
    /// beyond those bounds.
    ///
    /// - Parameters:
    ///   - i: A valid index of the array.
    ///   - distance: The distance to offset `i`.
    ///   - limit: A valid index of the collection to use as a limit. If
    ///     `distance > 0`, `limit` should be greater than `i` to have any
    ///     effect. Likewise, if `distance < 0`, `limit` should be less than `i`
    ///     to have any effect.
    /// - Returns: An index offset by `distance` from the index `i`, unless that
    ///   index would be beyond `limit` in the direction of movement. In that
    ///   case, the method returns `nil`.
    ///
    /// - Complexity: O(1)
    @inlinable
    public func index(
        _ i: Index, offsetBy distance: Int, limitedBy limit: Index
    ) -> Index? {
        // FIXME: swift-3-indexing-model: tests.
        let l = self.distance(from: i, to: limit)
        if distance > 0 ? l >= 0 && l < distance : l <= 0 && distance < l {
            return nil
        }
        return index(i, offsetBy: distance)
    }
}

// Provides an alternative default associated type witness for Indices
// for random access collections with strideable indices.
extension RandomAccessCollection where Index: Strideable, Index.Stride == Int {
    @_implements(Collection, Indices)
    public typealias _Default_Indices = Range<Index>
}

// 这里, Index 是 Strideable, 是关键所在.
// 上面的各种实现, 其实和 Collection 没有太大的区别, 但是只要 Index 是 Strideable, 就可以直接使用 Strideable 的特性了.
// 所以, 如果自己想要实现 RandomAccessCollection, Index 又不是 Strideable 的话, 其实是要实现上面列举的各种方法的.
extension RandomAccessCollection
where Index: Strideable,
      Index.Stride == Int,
      Indices == Range<Index> {
    
    
    @inlinable
    public var indices: Range<Index> {
        return startIndex..<endIndex
    }
    
    // 获取 index 后的目标 index, 直接使用的是 advanced(by: 1) 方法.
    // 这个方法, 是 stride 的方法, 也就是说, 是 stride 方法, 保证的 O(1) 时间复杂度, 获取到目标 Index
    @inlinable
    public func index(after i: Index) -> Index {
        return i.advanced(by: 1)
    }
    
    /// Returns the position immediately after the given index.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be greater than
    ///   `startIndex`.
    /// - Returns: The index value immediately before `i`.
    @inlinable // protocol-only
    public func index(before i: Index) -> Index {
        let result = i.advanced(by: -1)
        // FIXME: swift-3-indexing-model: tests for the trap.
        _failEarlyRangeCheck(
            result, bounds: Range(uncheckedBounds: (startIndex, endIndex)))
        return result
    }
    
    /// Returns an index that is the specified distance from the given index.
    ///
    /// The following example obtains an index advanced four positions from an
    /// array's starting index and then prints the element at that position.
    ///
    ///     let numbers = [10, 20, 30, 40, 50]
    ///     let i = numbers.index(numbers.startIndex, offsetBy: 4)
    ///     print(numbers[i])
    ///     // Prints "50"
    ///
    /// The value passed as `distance` must not offset `i` beyond the bounds of
    /// the collection.
    ///
    /// - Parameters:
    ///   - i: A valid index of the collection.
    ///   - distance: The distance to offset `i`.
    /// - Returns: An index offset by `distance` from the index `i`. If
    ///   `distance` is positive, this is the same value as the result of
    ///   `distance` calls to `index(after:)`. If `distance` is negative, this
    ///   is the same value as the result of `abs(distance)` calls to
    ///   `index(before:)`.
    ///
    /// - Complexity: O(1)
    @inlinable
    public func index(_ i: Index, offsetBy distance: Index.Stride) -> Index {
        let result = i.advanced(by: distance)
        // This range check is not precise, tighter bounds exist based on `n`.
        // Unfortunately, we would need to perform index manipulation to
        // compute those bounds, which is probably too slow in the general
        // case.
        // FIXME: swift-3-indexing-model: tests for the trap.
        _failEarlyRangeCheck(
            result, bounds: ClosedRange(uncheckedBounds: (startIndex, endIndex)))
        return result
    }
    
    // 使用 stride 的 distance 方法.
    @inlinable
    public func distance(from start: Index, to end: Index) -> Index.Stride {
        return start.distance(to: end)
    }
}


