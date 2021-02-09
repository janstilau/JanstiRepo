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
    
    // 这些, 都是之前 Collection 有的方法, 但是时间复杂度度上有了限制, O1
    // 时间复杂度, 其实是没有办法让编译器进行保证的. 所以, 如果没能是 O1, 代码应该还是能跑起来.
    @_nonoverride func index(_ i: Index, offsetBy distance: Int) -> Index
    @_nonoverride func index(
        _ i: Index, offsetBy distance: Int, limitedBy limit: Index
    ) -> Index?
    @_nonoverride func distance(from start: Index, to end: Index) -> Int
}

extension RandomAccessCollection {
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

// 所以, 如果自己想要实现 RandomAccessCollection, Index 又不是 Strideable 的话, 其实是要实现上面列举的各种方法的.
// 如果, Index 是 Stridable 的话, 就可以直接利用 Strideable 的各种能力了.
extension RandomAccessCollection
where Index: Strideable,
      Index.Stride == Int,
      Indices == Range<Index> {
    
    public var indices: Range<Index> {
        return startIndex..<endIndex
    }
    
    // 获取 index 后的目标 index, 直接使用的是 advanced(by: 1) 方法.
    // 这个方法, 是 stride 的方法, 也就是说, 是 stride 方法, 保证的 O(1) 时间复杂度, 获取到目标 Index
    public func index(after i: Index) -> Index {
        return i.advanced(by: 1)
    }
    
    public func index(before i: Index) -> Index {
        let result = i.advanced(by: -1)
        // FIXME: swift-3-indexing-model: tests for the trap.
        _failEarlyRangeCheck(
            result, bounds: Range(uncheckedBounds: (startIndex, endIndex)))
        return result
    }
    
    public func index(_ i: Index, offsetBy distance: Index.Stride) -> Index {
        let result = i.advanced(by: distance)
        return result
    }
    
    public func distance(from start: Index, to end: Index) -> Index.Stride {
        return start.distance(to: end)
    }
}


