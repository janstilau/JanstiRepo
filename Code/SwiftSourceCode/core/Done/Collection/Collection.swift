/*
 对于一个 Collection, 最主要的基本功能时.
 startIndex, 也就是原来的 beginIterator
 endIndex, 也就是原来的 endIterator
 subscript, 也就是取值操作. 这里, 把 Iterator 的能力, 转移到了 collection 里面
 formIndex, 也就是原来的 iterator 的++, --, 操作, 把原有的 Iterator 的能力, 转移到了 collection 里面.
 */

/*
 Collection, 要实现 Sequence, 要提供一个迭代器. 那么这个迭代器如何取值呢.
 对于容器来说, 取值过程各不一样. Array, 链表, 哈希表, map 都有着不同的取值过程.
 Colleciton 提供了几个概念, 通过 Index 取值.
 IndexingIterator 通过记录 Collection 的原始值, 通过 Index 从原始值中取值, 通过 Collection 进行 Index 的更改操作.
 IndexingIterator 提出后, 各个容器其实就不用考虑 Sequence 的事情了, 因为 IndexingIterator 的实现, 可以囊括任何类型的 Collection.
 而 Collection 提供了几个抽象方法, Subscript(Index), formIndex, 这些抽象方法, 是 Collection 的实现类必须要实现的.
 Collection 的实现类, 实现的是 Collection 提供的抽象, 他们并不用关心 Sequence 的细节, 因为 Sequence 的细节, 在 Colleciton 中, 已经实现了.
 从这个意义上来说, Collection 这个接口, 就是 Sequence 接口的具体实现类.
 */
/*
 IndexingIterator 的构造, 仅仅是记录一下原始的 Collection, 以及起始迭代的位置.
 */
@frozen
public struct IndexingIterator<Elements: Collection> {
    @usableFromInline
    internal let _elements: Elements // 存储一下, 迭代器对应的集合原始信息
    @usableFromInline
    internal var _position: Elements.Index // 存储一下,  当前的迭代位置.
    
    @inlinable
    @inline(__always)
    public
    init(_elements: Elements) {
        self._elements = _elements
        self._position = _elements.startIndex
    }
    
    @inlinable
    @inline(__always)
    public
    init(_elements: Elements, _position: Elements.Index) {
        self._elements = _elements
        self._position = _position
    }
}

/*
 IndexingIterator 通过 next, 获取值的办法.
 可以看到, IndexingIterator 是通过 Colleciton 的抽象, 完成的各个功能.
 */
extension IndexingIterator: IteratorProtocol, Sequence {
    public typealias Element = Elements.Element
    public typealias Iterator = IndexingIterator<Elements>
    public typealias SubSequence = AnySequence<Element>
    @inlinable
    @inline(__always)
    public mutating func next() -> Elements.Element? {
        if _position == _elements.endIndex { return nil }
        let element = _elements[_position]
        _elements.formIndex(after: &_position)
        return element
    }
}

/*
 一个需求, 可以多次遍历, 每次遍历不会破坏状态, 可以通过下标进行访问.
 */
/// 在 Swift 里面, 容器就是可以多次迭代的序列.
/// Collection 本身就是 Sequence, 所以它可以使用各种 Sequence 的方法.
///
/// Accessing Individual Elements
/// =============================
/// Colleciton 通过 Index 进行取值. 传入合适的 Index 是程序员自己的责任.
///
/// Accessing Slices of a Collection
/// ================================
/// 通过 Range, 获取到 Colelction 的切片.
///
/// Slices Share Indices
/// --------------------
/// 切片, 和原始的 Collection, 是共享 Index 的数值和范围的.
///
/// Slices Inherit Collection Semantics
/// -----------------------------------
/// 切片, 也是有着 Collection 的含义的, 可以在切片上, 做Collection 的操作.
///
/// Traversing a Collection
/// =======================
///  可以遍历 Collection, 这其实是 Sequence 的能力.
///
/// Conforming to the Collection Protocol
/// =====================================
///
/// If you create a custom sequence that can provide repeated access to its
/// elements, make sure that its type conforms to the `Collection` protocol in
/// order to give a more useful and more efficient interface for sequence and
/// collection operations. To add `Collection` conformance to your type, you
/// must declare at least the following requirements:
///
/// - The `startIndex` and `endIndex` properties O(1)
/// - A subscript that provides at least read-only access to your type's
///   elements O(1)
/// - The `index(after:)` method for advancing an index into your collection O(1)
///
/// Expected Performance
/// ====================


public protocol Collection: Sequence {
    
    typealias IndexDistance = Int
    
    override associatedtype Element
    /*
     这里, Comparable 代表着可以比较, 比如哈希表的, 通过bucket 的位置, 可以比较, 一个 bucket 上, 通过链表的前后, 可以比较.
     这里, Index 并不是 Stridable 的, 因为这是 RandomColleciton 才会有的功能.
     */
    associatedtype Index: Comparable
    /*
     同 beginIterator 相比, 没什么太大的不同.
     */
    var startIndex: Index { get }
    /*
     同 endIterator 相比, 没什么太大的不同. 都是最后一个元素的下一个位置.
     */
    var endIndex: Index { get }
    
    /*
     默认的 Colleciton 的 Iterator, 是 IndexingIterator. 这是一个非常好的类, 所有的功能实现, 都是建立在 Colection 提供的抽象上.
     只要 Collection, 实现了对应的方法, 那么自己实现的容器类, 就自动的完成了 Sequence 的适配.
     */
    associatedtype Iterator = IndexingIterator<Self>
    override __consuming func makeIterator() -> Iterator
    
    /*
     Collection 的 SubSequence 就是 Slice
     */
    associatedtype SubSequence: Collection = Slice<Self>
        where SubSequence.Index == Index,
        Element == SubSequence.Element,
        SubSequence.SubSequence == SubSequence
    
    /*
     在其他语言里面, 如何取值是放在了 Iterator 里面, 这里是放到了 Collection 里面.
     */
    @_borrowed
    subscript(position: Index) -> Element { get }
    
    /*
     通过范围, 取出一个 Slices 出来.
     */
    subscript(bounds: Range<Index>) -> SubSequence { get }
    
    /// A type that represents the indices that are valid for subscripting the
    /// collection, in ascending order.
    associatedtype Indices: Collection = DefaultIndices<Self>
        where Indices.Element == Index,
        Indices.Index == Index,
        Indices.SubSequence == Indices
    
    /*
     这是一个集合, 包含所有当前集合的索引值.
     */
    var indices: Indices { get }
    
    var isEmpty: Bool { get }
    /*
     count 是一个 primitive method
     但是有默认实现. 默认实现, 可以根据 Index 进行最终数量的确定.
     然而, 更多的容器, 是会在修改的过程中, 专门维护一个 count 值的, 所以, 在那些容器里面, 直接进行 count 值的返回就可以了.
     */
    var count: Int { get }
    
    func _customIndexOfEquatableElement(_ element: Element) -> Index??
    func _customLastIndexOfEquatableElement(_ element: Element) -> Index??
    
    func _failEarlyRangeCheck(_ index: Index, bounds: Range<Index>)
    func _failEarlyRangeCheck(_ index: Index, bounds: ClosedRange<Index>)
    func _failEarlyRangeCheck(_ range: Range<Index>, bounds: Range<Index>)
    
    /*
     最为重要的方法, 如何通过一个 Index, 得到后面的 Index
     */
    func index(after i: Index) -> Index
    /*
     传出参数形式的获取到后面的 Index.
     */
    func formIndex(after i: inout Index)
    
    func index(_ i: Index, offsetBy distance: Int) -> Index
    func index(
        _ i: Index, offsetBy distance: Int, limitedBy limit: Index
    ) -> Index?
    
    /*
     计算两个 Index 之间的距离.
     */
    func distance(from start: Index, to end: Index) -> Int
}

/// Default implementation for forward collections.
extension Collection {
    /*
     传出参数版本的 indexAfter 的默认实现, 是根据 IndexAfter 进行的.
     */
    @inlinable // protocol-only
    @inline(__always)
    public func formIndex(after i: inout Index) {
        i = index(after: i)
    }
    @inlinable
    public func _failEarlyRangeCheck(_ index: Index, bounds: Range<Index>) {
        _precondition(
            bounds.lowerBound <= index,
            "Out of bounds: index < startIndex")
        _precondition(
            index < bounds.upperBound,
            "Out of bounds: index >= endIndex")
    }
    @inlinable
    public func _failEarlyRangeCheck(_ index: Index, bounds: ClosedRange<Index>) {
        _precondition(
            bounds.lowerBound <= index,
            "Out of bounds: index < startIndex")
        _precondition(
            index <= bounds.upperBound,
            "Out of bounds: index > endIndex")
    }
    
    @inlinable
    public func _failEarlyRangeCheck(_ range: Range<Index>, bounds: Range<Index>) {
        _precondition(
            bounds.lowerBound <= range.lowerBound,
            "Out of bounds: range begins before startIndex")
        _precondition(
            range.lowerBound <= bounds.upperBound,
            "Out of bounds: range ends after endIndex")
        _precondition(
            bounds.lowerBound <= range.upperBound,
            "Out of bounds: range ends before bounds.lowerBound")
        _precondition(
            range.upperBound <= bounds.upperBound,
            "Out of bounds: range begins after bounds.upperBound")
    }
    
    @inlinable
    public func index(_ i: Index, offsetBy distance: Int) -> Index {
        return self._advanceForward(i, by: distance)
    }
    
    @inlinable
    public func index(
        _ i: Index, offsetBy distance: Int, limitedBy limit: Index
    ) -> Index? {
        return self._advanceForward(i, by: distance, limitedBy: limit)
    }
    
    @inlinable
    public func formIndex(_ i: inout Index, offsetBy distance: Int) {
        i = index(i, offsetBy: distance)
    }
    
    @inlinable
    public func formIndex(
        _ i: inout Index, offsetBy distance: Int, limitedBy limit: Index
    ) -> Bool {
        if let advancedIndex = index(i, offsetBy: distance, limitedBy: limit) {
            i = advancedIndex
            return true
        }
        i = limit
        return false
    }
    
    /*
     如同 C++ 一样, Distance 的实现, 默认是线性迭代的结果.
     首先, Index 是 Comparable 的, 所以它其实可以判等的.
     不断的, 进行迭代, 记录迭代的次数, 直到相等. 最后返回迭代的次数就好了.
     在 Random 里面, 由于 Index 可以计算出 distance, 直接通过 Index 就可以得出.
     注意, 在 Random 里面, 这个方法不是 override 的, 因为这算作 Collection 的扩展方法, 而不是 primitive method
     */
    @inlinable
    public func distance(from start: Index, to end: Index) -> Int {
        _precondition(start <= end,
                      "Only BidirectionalCollections can have end come before start")
        var start = start
        var count = 0
        while start != end {
            count = count + 1
            /*
             formIndex 是一个非常重要的方法.
             */
            formIndex(after: &start)
        }
        return count
    }
    
    @inlinable
    public func randomElement<T: RandomNumberGenerator>(
        using generator: inout T
    ) -> Element? {
        guard !isEmpty else { return nil }
        let random = Int.random(in: 0 ..< count, using: &generator)
        let idx = index(startIndex, offsetBy: random)
        return self[idx]
    }
    
    @inlinable
    public func randomElement() -> Element? {
        var g = SystemRandomNumberGenerator()
        return randomElement(using: &g)
    }
    
    /*
     就是一个个的调用 formIndex.
     */
    @inlinable
    @inline(__always)
    internal func _advanceForward(_ i: Index, by n: Int) -> Index {
        /*
         _advanceForward 的方法, 必须是要 > 0 的, 因为向前进行迭代, 是 Bidirection 的功能.
         */
        _precondition(n >= 0,
                      "Only BidirectionalCollections can be advanced by a negative amount")
        
        var i = i
        /*
         这里, 只能是一个个的往后确定, 因为对于不是连续的 collection, 只能是一个个的寻找下一个合适的位置.
         */
        for _ in stride(from: 0, to: n, by: 1) {
            formIndex(after: &i)
        }
        return i
    }
    
    /*
     在_advanceForward的基础上, 增加了对于边界值的判断
     */
    @inlinable
    @inline(__always)
    internal func _advanceForward(
        _ i: Index, by n: Int, limitedBy limit: Index
    ) -> Index? {
        _precondition(n >= 0,
                      "Only BidirectionalCollections can be advanced by a negative amount")
        var i = i
        for _ in stride(from: 0, to: n, by: 1) {
            /*
             如果, 到达了边界, 那么就返回 NIL
             这里使用的是 to, 因为一般来说, Collection 的 endIndex, 就是非法索引了, 仅仅是一个标识, 不能用来取值的.
             */
            if i == limit {
                return nil
            }
            formIndex(after: &i)
        }
        return i
    }
}

extension Collection where Iterator == IndexingIterator<Self> {
    @inlinable // trivial-implementation
    @inline(__always)
    public __consuming func makeIterator() -> IndexingIterator<Self> {
        return IndexingIterator(_elements: self)
    }
}

/*
 这里就是, Collection 为什么可以直接通过范围操作符, 得到一个新的值的原因.
 Slice 本身, 就是 Collection 协议的实现者. 所以, 可以直接通过 Slice 进行后续的操作.
 */
extension Collection where SubSequence == Slice<Self> {
    @inlinable
    public subscript(bounds: Range<Index>) -> Slice<Self> {
        _failEarlyRangeCheck(bounds, bounds: startIndex..<endIndex)
        return Slice(base: self, bounds: bounds)
    }
}

/*
 SubSequence == Self
 这里有点不理解.
 */
extension Collection where SubSequence == Self {
    @inlinable
    public mutating func popFirst() -> Element? {
        // TODO: swift-3-indexing-model - review the following
        guard !isEmpty else { return nil }
        let element = first!
        self = self[index(after: startIndex)..<endIndex]
        return element
    }
}

extension Collection {
    @inlinable
    public var isEmpty: Bool {
        return startIndex == endIndex
    }
    
    @inlinable
    public var first: Element? {
        let start = startIndex
        if start != endIndex { return self[start] }
        else { return nil }
    }
    
    @inlinable
    public var underestimatedCount: Int {
        return count
    }
    
    /*
     默认的实现, 就是遍历获取.
     如果自己记录了 Count, 直接返回就可以了.
     */
    @inlinable
    public var count: Int {
        return distance(from: startIndex, to: endIndex)
    }
    
    /*
     根据某个 Element, 获取它的 Index 的值.
     
     这个几个算法, 都是为了可以加快其他算法效率的 功能性方法.
     在 Set,Dict 里面, 重写了这个方法, 因为哈希原理非常快就能找到.
     在 range 里面, 重写了, range 就是连续空间.
     */
    @inlinable
    @inline(__always)
    public // dispatching
    func _customIndexOfEquatableElement(_: Element) -> Index?? {
        return nil
    }
    
    /*
     根据某个 Element, 获取它的最后一个 Index 的值.
     */
    @inlinable
    @inline(__always)
    public // dispatching
    func _customLastIndexOfEquatableElement(_ element: Element) -> Index?? {
        return nil
    }
}

/*
 同 Sequence 不同的是, Collection 的各种操作, 都是操作的 Index.
 然后根据 index 生成对应的 range, 然后通过 range, 获取对应的 Slice.
 */
extension Collection {
    @inlinable
    /*
     Colelciton 协议, 对于 map 进行了重写, 因为 count 可以确认最终的输出数组的大小.
     以下, 是 Sequence 里面, 对于 map 的定义.
     @inlinable
     public func map<T>(
     _ transform: (Element) throws -> T
     ) rethrows -> [T] {
     // 这里, 及时利用了 underestimatedCount, 进行了一个效率的提升.
     let initialCapacity = underestimatedCount
     var result = ContiguousArray<T>()
     result.reserveCapacity(initialCapacity) // 扩容.
     /*
     通过 primitiveMethod, 获取数据, 然后进行业务处理.
     这里, underestimatedCount 以下的, 直接进行添加, 这里不用考虑数组扩容.
     超过了之后, 如果还没有遍历结束, 尝试进行添加.
     所以, underestimatedCount 一定要返回一个有意义的值.
     */
     var iterator = self.makeIterator()
     // Add elements up to the initial capacity without checking for regrowth.
     for _ in 0..<initialCapacity {
     result.append(try transform(iterator.next()!))
     }
     // Add remaining elements, if any.
     while let element = iterator.next() {
     result.append(try transform(element))
     }
     /*
     其实, map 的操作, 很简单, 但是主要是, 方法提供了这一层抽象, 它就能进行下一层的操作. 比如链式编程.
     在 Array 里面, 根据 ContiguousArray 进行初始化, 一定有着简化的操作. 例如, 直接拿里面的指针, 当做 Array 的数据.
     */
     return Array(result)
     }
     */
    public func map<T>(
        _ transform: (Element) throws -> T
    ) rethrows -> [T] {
        /*
         直接通过 count, 获取到最终想要生成的 Array 的大小, 提前进行扩容处理.
         */
        let n = self.count
        if n == 0 {
            return []
        }
        var result = ContiguousArray<T>()
        result.reserveCapacity(n)
        
        var i = self.startIndex
        for _ in 0..<n {
            result.append(try transform(self[i]))
            formIndex(after: &i)
        }
        return Array(result)
    }
    
    /*
     在 Sequence 里面, 是生成了一个 Drop 版本的适配Sequence对象, 这里则是使用了 Collection 的 subSequence.
     在 Collection 里面, 全部变成了通过 Index 进行操作.
     通过 Index, 生成对应的 range, 然后生成对应的 SubSequence 数据.
     */
    @inlinable
    public __consuming func dropFirst(_ k: Int = 1) -> SubSequence {
        _precondition(k >= 0, "Can't drop a negative number of elements from a collection")
        let start = index(startIndex, offsetBy: k, limitedBy: endIndex) ?? endIndex
        return self[start..<endIndex]
    }
    
    /*
     dropLast 在 Sequence 版本里面, 是一个 O(n) 的算法, 在这个版本里面, 就是直接 Collection 的操作了.
     */
    @inlinable
    public __consuming func dropLast(_ k: Int = 1) -> SubSequence {
        _precondition(
            k >= 0, "Can't drop a negative number of elements from a collection")
        let amount = Swift.max(0, count - k)
        let end = index(startIndex,
                        offsetBy: amount, limitedBy: endIndex) ?? endIndex
        return self[startIndex..<end]
    }
    
    @inlinable
    public __consuming func drop(
        while predicate: (Element) throws -> Bool
    ) rethrows -> SubSequence {
        /*
         首先, 根据 predicate, 找到对应的 startIndex, 然后将 startIndex, 和 endIndex 生成的 range, 交给 Collection.
         */
        var start = startIndex
        while try start != endIndex && predicate(self[start]) {
            formIndex(after: &start)
        }
        return self[start..<endIndex]
    }
    
    /*
     返回 集合的前多少个的子序列.
     操作的是 range.
     */
    @inlinable
    public __consuming func prefix(_ maxLength: Int) -> SubSequence {
        _precondition(
            maxLength >= 0,
            "Can't take a prefix of negative length from a collection")
        let end = index(startIndex,
                        offsetBy: maxLength, limitedBy: endIndex) ?? endIndex
        return self[startIndex..<end]
    }
    
    /*
     通过 predicate, 得到最终的 range, 交给 Collection
     */
    @inlinable
    public __consuming func prefix(
        while predicate: (Element) throws -> Bool
    ) rethrows -> SubSequence {
        var end = startIndex
        while try end != endIndex && predicate(self[end]) {
            formIndex(after: &end)
        }
        return self[startIndex..<end]
    }
    
    /*
     Sequence 里面, 有着该方法的实现.
     在 Collecton 里面, 会更加的高效.
     */
    @inlinable
    public __consuming func suffix(_ maxLength: Int) -> SubSequence {
        _precondition(
            maxLength >= 0,
            "Can't take a suffix of negative length from a collection")
        let amount = Swift.max(0, count - maxLength)
        let start = index(startIndex,
                          offsetBy: amount, limitedBy: endIndex) ?? endIndex
        return self[start..<endIndex]
    }
    
    /*
     返回集合到 end Index 的子序列.
     */
    @inlinable
    public __consuming func prefix(upTo end: Index) -> SubSequence {
        return self[startIndex..<end]
    }
    
    @inlinable
    public __consuming func suffix(from start: Index) -> SubSequence {
        return self[start..<endIndex]
    }
    
    
    @inlinable
    public __consuming func prefix(through position: Index) -> SubSequence {
        return prefix(upTo: index(after: position))
    }
    
    /// Returns the longest possible subsequences of the collection, in order,
    /// that don't contain elements satisfying the given predicate.
    ///
    /// The resulting array consists of at most `maxSplits + 1` subsequences.
    /// Elements that are used to split the sequence are not returned as part of
    /// any subsequence.
    ///
    /// The following examples show the effects of the `maxSplits` and
    /// `omittingEmptySubsequences` parameters when splitting a string using a
    /// closure that matches spaces. The first use of `split` returns each word
    /// that was originally separated by one or more spaces.
    ///
    ///     let line = "BLANCHE:   I don't want realism. I want magic!"
    ///     print(line.split(whereSeparator: { $0 == " " }))
    ///     // Prints "["BLANCHE:", "I", "don\'t", "want", "realism.", "I", "want", "magic!"]"
    ///
    /// The second example passes `1` for the `maxSplits` parameter, so the
    /// original string is split just once, into two new strings.
    ///
    ///     print(line.split(maxSplits: 1, whereSeparator: { $0 == " " }))
    ///     // Prints "["BLANCHE:", "  I don\'t want realism. I want magic!"]"
    ///
    /// The final example passes `false` for the `omittingEmptySubsequences`
    /// parameter, so the returned array contains empty strings where spaces
    /// were repeated.
    ///
    ///     print(line.split(omittingEmptySubsequences: false, whereSeparator: { $0 == " " }))
    ///     // Prints "["BLANCHE:", "", "", "I", "don\'t", "want", "realism.", "I", "want", "magic!"]"
    ///
    /// - Parameters:
    ///   - maxSplits: The maximum number of times to split the collection, or
    ///     one less than the number of subsequences to return. If
    ///     `maxSplits + 1` subsequences are returned, the last one is a suffix
    ///     of the original collection containing the remaining elements.
    ///     `maxSplits` must be greater than or equal to zero. The default value
    ///     is `Int.max`.
    ///   - omittingEmptySubsequences: If `false`, an empty subsequence is
    ///     returned in the result for each pair of consecutive elements
    ///     satisfying the `isSeparator` predicate and for each element at the
    ///     start or end of the collection satisfying the `isSeparator`
    ///     predicate. The default value is `true`.
    ///   - isSeparator: A closure that takes an element as an argument and
    ///     returns a Boolean value indicating whether the collection should be
    ///     split at that element.
    /// - Returns: An array of subsequences, split from this collection's
    ///   elements.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the collection.
    @inlinable
    public __consuming func split(
        maxSplits: Int = Int.max,
        omittingEmptySubsequences: Bool = true,
        whereSeparator isSeparator: (Element) throws -> Bool
    ) rethrows -> [SubSequence] {
        // TODO: swift-3-indexing-model - review the following
        _precondition(maxSplits >= 0, "Must take zero or more splits")
        
        var result: [SubSequence] = []
        var subSequenceStart: Index = startIndex
        
        func appendSubsequence(end: Index) -> Bool {
            if subSequenceStart == end && omittingEmptySubsequences {
                return false
            }
            result.append(self[subSequenceStart..<end])
            return true
        }
        
        if maxSplits == 0 || isEmpty {
            _ = appendSubsequence(end: endIndex)
            return result
        }
        
        var subSequenceEnd = subSequenceStart
        let cachedEndIndex = endIndex
        while subSequenceEnd != cachedEndIndex {
            if try isSeparator(self[subSequenceEnd]) {
                let didAppend = appendSubsequence(end: subSequenceEnd)
                formIndex(after: &subSequenceEnd)
                subSequenceStart = subSequenceEnd
                if didAppend && result.count == maxSplits {
                    break
                }
                continue
            }
            formIndex(after: &subSequenceEnd)
        }
        
        if subSequenceStart != cachedEndIndex || !omittingEmptySubsequences {
            result.append(self[subSequenceStart..<cachedEndIndex])
        }
        
        return result
    }
}

extension Collection where Element: Equatable {
    /// Returns the longest possible subsequences of the collection, in order,
    /// around elements equal to the given element.
    ///
    /// The resulting array consists of at most `maxSplits + 1` subsequences.
    /// Elements that are used to split the collection are not returned as part
    /// of any subsequence.
    ///
    /// The following examples show the effects of the `maxSplits` and
    /// `omittingEmptySubsequences` parameters when splitting a string at each
    /// space character (" "). The first use of `split` returns each word that
    /// was originally separated by one or more spaces.
    ///
    ///     let line = "BLANCHE:   I don't want realism. I want magic!"
    ///     print(line.split(separator: " "))
    ///     // Prints "["BLANCHE:", "I", "don\'t", "want", "realism.", "I", "want", "magic!"]"
    ///
    /// The second example passes `1` for the `maxSplits` parameter, so the
    /// original string is split just once, into two new strings.
    ///
    ///     print(line.split(separator: " ", maxSplits: 1))
    ///     // Prints "["BLANCHE:", "  I don\'t want realism. I want magic!"]"
    ///
    /// The final example passes `false` for the `omittingEmptySubsequences`
    /// parameter, so the returned array contains empty strings where spaces
    /// were repeated.
    ///
    ///     print(line.split(separator: " ", omittingEmptySubsequences: false))
    ///     // Prints "["BLANCHE:", "", "", "I", "don\'t", "want", "realism.", "I", "want", "magic!"]"
    ///
    /// - Parameters:
    ///   - separator: The element that should be split upon.
    ///   - maxSplits: The maximum number of times to split the collection, or
    ///     one less than the number of subsequences to return. If
    ///     `maxSplits + 1` subsequences are returned, the last one is a suffix
    ///     of the original collection containing the remaining elements.
    ///     `maxSplits` must be greater than or equal to zero. The default value
    ///     is `Int.max`.
    ///   - omittingEmptySubsequences: If `false`, an empty subsequence is
    ///     returned in the result for each consecutive pair of `separator`
    ///     elements in the collection and for each instance of `separator` at
    ///     the start or end of the collection. If `true`, only nonempty
    ///     subsequences are returned. The default value is `true`.
    /// - Returns: An array of subsequences, split from this collection's
    ///   elements.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the collection.
    @inlinable
    public __consuming func split(
        separator: Element,
        maxSplits: Int = Int.max,
        omittingEmptySubsequences: Bool = true
    ) -> [SubSequence] {
        // TODO: swift-3-indexing-model - review the following
        return split(
            maxSplits: maxSplits,
            omittingEmptySubsequences: omittingEmptySubsequences,
            whereSeparator: { $0 == separator })
    }
}

extension Collection where SubSequence == Self {
    /// Removes and returns the first element of the collection.
    ///
    /// The collection must not be empty.
    ///
    /// - Returns: The first element of the collection.
    ///
    /// - Complexity: O(1)
    @inlinable
    @discardableResult
    public mutating func removeFirst() -> Element {
        // TODO: swift-3-indexing-model - review the following
        _precondition(!isEmpty, "Can't remove items from an empty collection")
        let element = first!
        self = self[index(after: startIndex)..<endIndex]
        return element
    }
    
    /// Removes the specified number of elements from the beginning of the
    /// collection.
    ///
    /// - Parameter k: The number of elements to remove. `k` must be greater than
    ///   or equal to zero, and must be less than or equal to the number of
    ///   elements in the collection.
    ///
    /// - Complexity: O(1) if the collection conforms to
    ///   `RandomAccessCollection`; otherwise, O(*k*), where *k* is the specified
    ///   number of elements.
    @inlinable
    public mutating func removeFirst(_ k: Int) {
        if k == 0 { return }
        _precondition(k >= 0, "Number of elements to remove should be non-negative")
        _precondition(count >= k,
                      "Can't remove more items from a collection than it contains")
        self = self[index(startIndex, offsetBy: k)..<endIndex]
    }
}
