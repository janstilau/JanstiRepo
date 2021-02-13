public protocol RangeReplaceableCollection: Collection
where SubSequence: RangeReplaceableCollection {
    override associatedtype SubSequence
    init()
    
    // primitive method, 提供了其他方法的实现的基础.
    // replaceSubrange 作为 primitive 的原因在于, 插入: subrange 为 length 0 就可以, 删除, newElements length 为 0,  subrange length 变化.
    mutating func replaceSubrange<C>(
        _ subrange: Range<Index>,
        with newElements: C
    ) where C: Collection, C.Element == Element
    
    // 默认实现, 什么都不做, 这是为了提升效率的, 例如防止 Array 的多次扩容.
    mutating func reserveCapacity(_ n: Int)
    
    init(repeating repeatedValue: Element, count: Int)
    // 这个也是直接使用了 append, 并且, S 是 Sequence, 所以 count 可能是 O(n) 的, 那么久没有办法提前分配内存了.
    init<S: Sequence>(_ elements: S)
    where S.Element == Element
    
    mutating func append(_ newElement: __owned Element)
    
    mutating func append<S: Sequence>(contentsOf newElements: __owned S)
    where S.Element == Element
    
    mutating func insert(_ newElement: __owned Element, at i: Index)
    
    mutating func insert<S: Collection>(contentsOf newElements: __owned S, at i: Index)
    where S.Element == Element
    
    mutating func remove(at i: Index) -> Element
    
    mutating func removeSubrange(_ bounds: Range<Index>)
    
    mutating func _customRemoveLast() -> Element?
    
    mutating func _customRemoveLast(_ n: Int) -> Bool
    
    @discardableResult
    mutating func removeFirst() -> Element
    
    mutating func removeFirst(_ k: Int)
    
    mutating func removeAll(keepingCapacity keepCapacity: Bool /*= false*/)
    
    mutating func removeAll(
        where shouldBeRemoved: (Element) throws -> Bool) rethrows
    
    override subscript(bounds: Index) -> Element { get }
    override subscript(bounds: Range<Index>) -> SubSequence { get }
}

// 用一个特殊的图案, 来标明代码块的分割.
//===----------------------------------------------------------------------===//
// Default implementations for RangeReplaceableCollection
//===----------------------------------------------------------------------===//

// 各种改变 Collection 长度的方法, 最终必然归结到 replace range 里面.
extension RangeReplaceableCollection {
    
    public init(repeating repeatedValue: Element, count: Int) {
        self.init()
        if count != 0 {
            // 之所以需要这层抽象, 主要是想复用 append(contentsOf 这个方法. 这个方法, 需要的是一个 Colleciton, 同样的数据, 所以专门有一个特殊的 Collection 用来表示.
            // 其实, 也可以使用 for 循环, 加单个 append.
            let elements = Repeated(_repeating: repeatedValue, count: count)
            append(contentsOf: elements)
        }
    }
    
    public init<S: Sequence>(_ elements: S)
    where S.Element == Element {
        self.init()
        append(contentsOf: elements)
    }
    
    // insert 是非常核心的方法, 他可以实现 append, remove, 而在这里, insert 又是通过 replace 方法实现的.
    public mutating func append(_ newElement: __owned Element) {
        insert(newElement, at: endIndex)
    }
    
    public mutating func append<S: Sequence>(contentsOf newElements: __owned S)
    where S.Element == Element {
        // underestimatedCount 的意义就在这里, 给了外界一个机会, 能够更有效率的完成算法.
        let approximateCapacity = self.count +
            numericCast(newElements.underestimatedCount)
        self.reserveCapacity(approximateCapacity)
        for element in newElements {
            append(element)
        }
    }
    
    // 插入一个, 就是 replaceSubrange 的位置为 0 length, newElements 包装为 collection
    public mutating func insert(
        _ newElement: __owned Element, at i: Index
    ) {
        replaceSubrange(i..<i, with: CollectionOfOne(newElement))
    }
    
    // 插入多个,
    public mutating func insert<C: Collection>(
        contentsOf newElements: __owned C, at i: Index
    ) where C.Element == Element {
        replaceSubrange(i..<i, with: newElements)
    }
    
    // remove, 就是用一个 EmptyCollection, 去替换某个 range 里面的内容.
    public mutating func remove(at position: Index) -> Element {
        let result: Element = self[position]
        replaceSubrange(position..<index(after: position), with: EmptyCollection())
        return result
    }
    
    public mutating func removeSubrange(_ bounds: Range<Index>) {
        replaceSubrange(bounds, with: EmptyCollection())
    }
    
    // 应该要有, 防卫式的代码.
    public mutating func removeFirst(_ k: Int) {
        if k == 0 { return }
        guard let end = index(startIndex, offsetBy: k, limitedBy: endIndex) else {
            _preconditionFailure(
                "Can't remove more items from a collection than it has")
        }
        removeSubrange(startIndex..<end)
    }
    
    public mutating func removeFirst() -> Element {
        _precondition(!isEmpty,
                      "Can't remove first element from an empty collection")
        let firstElement = first!
        removeFirst(1)
        return firstElement
    }
    
    // 如果, 不需要 keepCapacity, 直接整体替换就可以了.
    // 因为其实, struct 里面  self = Self() 这种操作, 就是将内存值进行了一次覆盖. 因为 ARC 的缘故, 之前的值, 可以自动释放.
    public mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
        if !keepCapacity {
            self = Self()
        }
        else {
            replaceSubrange(startIndex..<endIndex, with: EmptyCollection())
        }
    }
    
    // 默认这个函数没有一点作用.
    public mutating func reserveCapacity(_ n: Int) {}
}

// 之所以, SubSequence == Self 这种限制, 是因为 self = self[index(after: startIndex)..<endIndex]
// 只有 type == type 的情况下, 才能进行赋值操作. 因为 Swift 是没有赋值操作符的定义的.
extension RangeReplaceableCollection where SubSequence == Self {
    public mutating func removeFirst() -> Element {
        _precondition(!isEmpty, "Can't remove items from an empty collection")
        let element = first!
        self = self[index(after: startIndex)..<endIndex]
        return element
    }
    
    public mutating func removeFirst(_ k: Int) {
        if k == 0 { return }
        _precondition(k >= 0, "Number of elements to remove should be non-negative")
        guard let idx = index(startIndex, offsetBy: k, limitedBy: endIndex) else {
            _preconditionFailure(
                "Can't remove more items from a collection than it contains")
        }
        self = self[idx..<endIndex]
    }
}

extension RangeReplaceableCollection {
    public mutating func replaceSubrange<C: Collection, R: RangeExpression>(
        _ subrange: R,
        with newElements: __owned C
    ) where C.Element == Element, R.Bound == Index {
        // subrange.relative 就是将 range 转化为 collection 的 index 的过程.
        // 这个过程, 定义在各个 range 里面.
        self.replaceSubrange(subrange.relative(to: self), with: newElements)
    }
    
    public mutating func removeSubrange<R: RangeExpression>(
        _ bounds: R
    ) where R.Bound == Index  {
        removeSubrange(bounds.relative(to: self))
    }
}

extension RangeReplaceableCollection {
    @inlinable
    public mutating func _customRemoveLast() -> Element? {
        return nil
    }
    
    @inlinable
    public mutating func _customRemoveLast(_ n: Int) -> Bool {
        return false
    }
}

// 如果, 是双向的, 那么有着 _customRemoveLast 相关的实现.
extension RangeReplaceableCollection
where Self: BidirectionalCollection, SubSequence == Self {
    
    public mutating func _customRemoveLast() -> Element? {
        let element = last!
        self = self[startIndex..<index(before: endIndex)]
        return element
    }
    
    public mutating func _customRemoveLast(_ n: Int) -> Bool {
        guard let end = index(endIndex, offsetBy: -n, limitedBy: startIndex)
        else {
            _preconditionFailure(
                "Can't remove more items from a collection than it contains")
        }
        self = self[startIndex..<end]
        return true
    }
}

// 如果是双向的, 那么有着从后面开始操作的实现.
// 这种从后面操作, 是依赖着, 可以从后面开始计算, 组装 index 的基础上的.
extension RangeReplaceableCollection where Self: BidirectionalCollection {
    public mutating func popLast() -> Element? {
        if isEmpty { return nil }
        if let result = _customRemoveLast() { return result }
        return remove(at: index(before: endIndex))
    }
    
    public mutating func removeLast() -> Element {
        if let result = _customRemoveLast() { return result }
        return remove(at: index(before: endIndex))
    }
    
   
    public mutating func removeLast(_ k: Int) {
        if k == 0 { return }
        _precondition(k >= 0, "Number of elements to remove should be non-negative")
        if _customRemoveLast(k) {
            return
        }
        let end = endIndex
        guard let start = index(end, offsetBy: -k, limitedBy: startIndex)
        else {
            _preconditionFailure(
                "Can't remove more items from a collection than it contains")
        }
        
        removeSubrange(start..<end)
    }
}

// Pop 安全, remove 不安全, 这是 swift 的命名规则.
extension RangeReplaceableCollection
where Self: BidirectionalCollection, SubSequence == Self {
    public mutating func popLast() -> Element? {
        if isEmpty { return nil }
        if let result = _customRemoveLast() { return result }
        return remove(at: index(before: endIndex))
    }
    
    @discardableResult
    public mutating func removeLast() -> Element {
        _precondition(!isEmpty, "Can't remove last element from an empty collection")
        if let result = _customRemoveLast() { return result }
        return remove(at: index(before: endIndex))
    }
    
    public mutating func removeLast(_ k: Int) {
        if k == 0 { return }
        _precondition(k >= 0, "Number of elements to remove should be non-negative")
        if _customRemoveLast(k) {
            return
        }
        let end = endIndex
        guard let start = index(end, offsetBy: -k, limitedBy: startIndex)
        else {
            _preconditionFailure(
                "Can't remove more items from a collection than it contains")
        }
        removeSubrange(start..<end)
    }
}

extension RangeReplaceableCollection {
    public static func + <
        Other: Sequence
    >(lhs: Self, rhs: Other) -> Self
    where Element == Other.Element {
        // 可变性变化了, 变量名, 可以使用一个, 感觉不太好.
        var lhs = lhs
        lhs.append(contentsOf: rhs)
        return lhs
    }
    
    @inlinable
    public static func + <
        Other: Sequence
    >(lhs: Other, rhs: Self) -> Self
    where Element == Other.Element {
        var result = Self()
        result.reserveCapacity(rhs.count + numericCast(lhs.underestimatedCount))
        result.append(contentsOf: lhs)
        result.append(contentsOf: rhs)
        return result
    }
    
    // +=, 那么左值一定是 inout 的
    public static func += <
        Other: Sequence
    >(lhs: inout Self, rhs: Other)
    where Element == Other.Element {
        lhs.append(contentsOf: rhs)
    }
    
    public static func + <
        Other: RangeReplaceableCollection
    >(lhs: Self, rhs: Other) -> Self
    where Element == Other.Element {
        var lhs = lhs
        lhs.append(contentsOf: rhs)
        return lhs
    }
}


extension RangeReplaceableCollection {
    // 这里, 返回的是一个 lazy 的值, 不是当场出结果的.
    public __consuming func filter(
        _ isIncluded: (Element) throws -> Bool
    ) rethrows -> Self {
        return try Self(self.lazy.filter(isIncluded))
    }
}

extension RangeReplaceableCollection where Self: MutableCollection {
    /// Removes all the elements that satisfy the given predicate.
    ///
    /// Use this method to remove every element in a collection that meets
    /// particular criteria. The order of the remaining elements is preserved.
    /// This example removes all the odd values from an
    /// array of numbers:
    ///
    ///     var numbers = [5, 6, 7, 8, 9, 10, 11]
    ///     numbers.removeAll(where: { $0 % 2 != 0 })
    ///     // numbers == [6, 8, 10]
    ///
    /// - Parameter shouldBeRemoved: A closure that takes an element of the
    ///   sequence as its argument and returns a Boolean value indicating
    ///   whether the element should be removed from the collection.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the collection.
    @inlinable
    public mutating func removeAll(
        where shouldBeRemoved: (Element) throws -> Bool
    ) rethrows {
        let suffixStart = try _halfStablePartition(isSuffixElement: shouldBeRemoved)
        removeSubrange(suffixStart...)
    }
}

extension RangeReplaceableCollection {
    public mutating func removeAll(
        where shouldBeRemoved: (Element) throws -> Bool
    ) rethrows {
        self = try filter { try !shouldBeRemoved($0) }
    }
}

