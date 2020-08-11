/// Conforming to the RandomAccessCollection Protocol
/// =================================================
///
/// The `RandomAccessCollection` protocol adds further constraints on the
/// associated `Indices` and `SubSequence` types, but otherwise imposes no
/// additional requirements over the `BidirectionalCollection` protocol.
/// However, in order to meet the complexity guarantees of a random-access
/// collection, either the index for your custom type must conform to the
/// `Strideable` protocol or you must implement the `index(_:offsetBy:)` and
/// `distance(from:to:)` methods with O(1) efficiency.

/*
 为了可以随机访问, index 必须是 strideable 的, 因为 Strideable 本就是可以根据 offset 进行移动的.
 或者, 你的 index(_:offsetBy:) 和 distance(from:to:) 必须是 O(1)复杂度的.
 */

public protocol RandomAccessCollection: BidirectionalCollection
    where SubSequence: RandomAccessCollection, Indices: RandomAccessCollection
{
    override associatedtype Element
    override associatedtype Index
    override associatedtype SubSequence
    override associatedtype Indices
    
    override var indices: Indices { get }
    
    override subscript(bounds: Range<Index>) -> SubSequence { get }
    
    @_borrowed
    override subscript(position: Index) -> Element { get }
    override var startIndex: Index { get }
    override var endIndex: Index { get }
    
    override func index(before i: Index) -> Index
    override func formIndex(before i: inout Index)
    override func index(after i: Index) -> Index
    override func formIndex(after i: inout Index)
    @_nonoverride func index(_ i: Index, offsetBy distance: Int) -> Index
    @_nonoverride func index(
        _ i: Index, offsetBy distance: Int, limitedBy limit: Index
    ) -> Index?
    @_nonoverride func distance(from start: Index, to end: Index) -> Int
}

extension RandomAccessCollection {
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

extension RandomAccessCollection where Index: Strideable, Index.Stride == Int {
    @_implements(Collection, Indices)
    public typealias _Default_Indices = Range<Index>
}

extension RandomAccessCollection
    where Index: Strideable,
    Index.Stride == Int,
Indices == Range<Index> {
    
    /*
     如果, Index: Strideable, 那么 indices 就可以用 range 表示.
     */
    @inlinable
    public var indices: Range<Index> {
        return startIndex..<endIndex
    }
        
    /*
     直接使用 advanced 方法, 这是 Strideable 的功能.
     */
    @inlinable
    public func index(after i: Index) -> Index {
        // FIXME: swift-3-indexing-model: tests for the trap.
        _failEarlyRangeCheck(
            i, bounds: Range(uncheckedBounds: (startIndex, endIndex)))
        return i.advanced(by: 1)
    }
    
    /*
     直接使用 advanced 方法, 这是 Strideable 的功能.
    */
    @inlinable // protocol-only
    public func index(before i: Index) -> Index {
        let result = i.advanced(by: -1)
        // FIXME: swift-3-indexing-model: tests for the trap.
        _failEarlyRangeCheck(
            result, bounds: Range(uncheckedBounds: (startIndex, endIndex)))
        return result
    }
    
    /*
     直接使用 advanced 方法, 这是 Strideable 的功能.
    */
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
    
    /*
     直接使用 advanced 方法, 这是 Strideable 的功能.
    */
    @inlinable
    public func distance(from start: Index, to end: Index) -> Index.Stride {
        // FIXME: swift-3-indexing-model: tests for traps.
        _failEarlyRangeCheck(
            start, bounds: ClosedRange(uncheckedBounds: (startIndex, endIndex)))
        _failEarlyRangeCheck(
            end, bounds: ClosedRange(uncheckedBounds: (startIndex, endIndex)))
        return start.distance(to: end)
    }
}


