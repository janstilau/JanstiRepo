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

/*
 可见, RANDOM 的概念, 主要是针对 Index 的, 如果 Index 可以拥有 strideable 的语义, 大部分功能, 直接通过 Index 的函数就可以实现.
 */
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
        _failEarlyRangeCheck(
            result, bounds: ClosedRange(uncheckedBounds: (startIndex, endIndex)))
        return result
    }
    
    /*
     直接使用 advanced 方法, 这是 Strideable 的功能.
    */
    @inlinable
    public func distance(from start: Index, to end: Index) -> Index.Stride {
        _failEarlyRangeCheck(
            start, bounds: ClosedRange(uncheckedBounds: (startIndex, endIndex)))
        _failEarlyRangeCheck(
            end, bounds: ClosedRange(uncheckedBounds: (startIndex, endIndex)))
        return start.distance(to: end)
    }
}


