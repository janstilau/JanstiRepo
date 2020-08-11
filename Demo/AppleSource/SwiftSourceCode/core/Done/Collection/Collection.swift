/*
 对于一个 Collection, 最主要的基本功能时.
 startIndex, 也就是原来的 beginIterator
 endIndex, 也就是原来的 endIterator
 subscript, 也就是取值操作. 这里, 把 Iterator 的能力, 转移到了 collection 里面
 formIndex, 也就是原来的 iterator 的++, --, 操作, 把原有的 Iterator 的能力, 转移到了 collection 里面.
 */

/// A type that iterates over a collection using its indices.
///
/// By default, any custom collection type you create will inherit a
/// `makeIterator()` method that returns an `IndexingIterator` instance,
/// making it unnecessary to declare your own.

/// When creating a custom
/// collection type, add the minimal requirements of the `Collection`
/// protocol:
/// starting and ending indices and a subscript for accessing
/// elements.
///
/// StartIndex
/// EndIndex
/// Subscript
///

/*
 IndexingIterator 的构造, 仅仅是记录一下原始的 Collection, 以及起始迭代的位置.
 */
@frozen
public struct IndexingIterator<Elements: Collection> {
    @usableFromInline
    internal let _elements: Elements // 存储一下, 迭代器对应的集合原始信息
    @usableFromInline
    internal var _position: Elements.Index // 存储一下, 迭代器的开始信息
    
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
不同容器的迭代器, next 的方式是不一样的. 比如, 数组是 index++, Map 是 bucket 和 node 的共同作用, 链表是 nextNode 的判断.
在这个迭代器中, 通过 Colelction 提供的抽象方法, 通过 index 进行取值, 然后更新下一位置的 postion 值.
不同的 Collection, 实现不同的下标取值, formIndex 更新的操作.
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
/// 在 Swift 里面, 容器就是可以多次迭代的序列. 所以, Collection 可以使用 Sequence 里面定义的各个方法.
///
/// Accessing Individual Elements
/// =============================
/// Colleciton 通过 Index 进行取值. 传入合适的 Index 是程序员自己的责任.
///
/// Accessing Slices of a Collection
/// ================================
///
/// Slices Share Indices
/// --------------------
///
/// Slices Inherit Collection Semantics
/// -----------------------------------
///
/// Traversing a Collection
/// =======================
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
     IndexingIterator 中, next 是完全建立在 colleciton 的基础上, 进行的取值, 以及 index 更新的操作.
     */
    associatedtype Iterator = IndexingIterator<Self>
    override __consuming func makeIterator() -> Iterator
    
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
    var count: Int { get }
    
    func _customIndexOfEquatableElement(_ element: Element) -> Index??
    func _customLastIndexOfEquatableElement(_ element: Element) -> Index??
    func index(_ i: Index, offsetBy distance: Int) -> Index
    
    func index(
        _ i: Index, offsetBy distance: Int, limitedBy limit: Index
    ) -> Index?
    
    /*
     这里面的好多函数, 都有着 random 和 normal 之分. 这个概念 c++ 是建立在 iterator 的基础上的, 在这里, 变为了 colleciton 的基础上.
     */
    func distance(from start: Index, to end: Index) -> Int
    func _failEarlyRangeCheck(_ index: Index, bounds: Range<Index>)
    func _failEarlyRangeCheck(_ index: Index, bounds: ClosedRange<Index>)
    func _failEarlyRangeCheck(_ range: Range<Index>, bounds: Range<Index>)
    
    /*
     这个方法, 要交给每个 collection 自己去完成.
     */
    func index(after i: Index) -> Index
    /*
     这个就是调用上面的 index 实现的.
     就是返回值变为了传出参数表示.
     */
    func formIndex(after i: inout Index)
}

/// Default implementation for forward collections.
extension Collection {
    /*
     传出参数, 都要使用返回值版本的实现.
     */
    @inlinable // protocol-only
    @inline(__always)
    public func formIndex(after i: inout Index) {
        i = index(after: i)
    }
    /*
     里面就是简单的通过 range 的范围比较. 前开后闭.
     */
    @inlinable
    public func _failEarlyRangeCheck(_ index: Index, bounds: Range<Index>) {
        _precondition(
            bounds.lowerBound <= index,
            "Out of bounds: index < startIndex")
        _precondition(
            index < bounds.upperBound,
            "Out of bounds: index >= endIndex")
    }
    /*
     里面就是简单的通过 range 的范围比较. 前闭后闭.
     */
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
    /// - Complexity: O(1) if the collection conforms to
    ///   `RandomAccessCollection`; otherwise, O(*k*), where *k* is the
    ///   resulting distance.
    
    /*
     各个容器, 在完成自己对于 Collection 的适配的时候, 如果可以进行 randomAccess, 会重写该方法, 进行更加高效的操作.
     不然的话, 就是 O(n) 的遍历算法.
     */
    @inlinable
    public func distance(from start: Index, to end: Index) -> Int {
        _precondition(start <= end,
                      "Only BidirectionalCollections can have end come before start")
        /*
         这里, 之所以用遍历的方式, 是因为如果可以随机访问的 collection, 距离的确认, 都是一件很难得事情. 例如链表.
         */
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
         这里, 进行了检查, 但是在 BidirectionalCollections 里面, 一定要进行重写.
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
            if i == limit {
                return nil
            }
            formIndex(after: &i)
        }
        return i
    }
}

/*
 Collection 有着一个默认的 IndexingIterator, 可以满足所有 iterator 需要的功能.
 */
extension Collection where Iterator == IndexingIterator<Self> {
    /// Returns an iterator over the elements of the collection.
    @inlinable // trivial-implementation
    @inline(__always)
    public __consuming func makeIterator() -> IndexingIterator<Self> {
        return IndexingIterator(_elements: self)
    }
}

/// Supply the default "slicing" `subscript` for `Collection` models
/// that accept the default associated `SubSequence`, `Slice<Self>`.
extension Collection where SubSequence == Slice<Self> {
    /// Accesses a contiguous subrange of the collection's elements.
    ///
    /// The accessed  slice uses the same indices for the same elements as the
    /// original collection. Always use the slice's `startIndex` property
    /// instead of assuming that its indices start at a particular value.
    ///
    /// This example demonstrates getting a slice of an array of strings, finding
    /// the index of one of the strings in the slice, and then using that index
    /// in the original array.
    ///
    ///     let streets = ["Adams", "Bryant", "Channing", "Douglas", "Evarts"]
    ///     let streetsSlice = streets[2 ..< streets.endIndex]
    ///     print(streetsSlice)
    ///     // Prints "["Channing", "Douglas", "Evarts"]"
    ///
    ///     let index = streetsSlice.firstIndex(of: "Evarts")    // 4
    ///     print(streets[index!])
    ///     // Prints "Evarts"
    ///
    /// - Parameter bounds: A range of the collection's indices. Thebounds of
    ///   the range must be valid indices of the collection.
    ///
    /// - Complexity: O(1)
    /*
     简单的生成一个 Slice 的对象而已.
     */
    @inlinable
    public subscript(bounds: Range<Index>) -> Slice<Self> {
        _failEarlyRangeCheck(bounds, bounds: startIndex..<endIndex)
        return Slice(base: self, bounds: bounds)
    }
}

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
    
    /// A value less than or equal to the number of elements in the collection.
    ///
    /// - Complexity: O(1) if the collection conforms to
    ///   `RandomAccessCollection`; otherwise, O(*n*), where *n* is the length
    ///   of the collection.
    @inlinable
    public var underestimatedCount: Int {
        // TODO: swift-3-indexing-model - review the following
        return count
    }
    
    @inlinable
    public var count: Int {
        return distance(from: startIndex, to: endIndex)
    }
    
    // TODO: swift-3-indexing-model - rename the following to _customIndexOfEquatable(element)?
    /// Customization point for `Collection.firstIndex(of:)`.
    ///
    /// Define this method if the collection can find an element in less than
    /// O(*n*) by exploiting collection-specific knowledge.
    ///
    /// - Returns: `nil` if a linear search should be attempted instead,
    ///   `Optional(nil)` if the element was not found, or
    ///   `Optional(Optional(index))` if an element was found.
    ///
    /// - Complexity: Hopefully less than O(`count`).
    @inlinable
    @inline(__always)
    public // dispatching
    func _customIndexOfEquatableElement(_: Element) -> Index?? {
        return nil
    }
    
    /// Customization point for `Collection.lastIndex(of:)`.
    ///
    /// Define this method if the collection can find an element in less than
    /// O(*n*) by exploiting collection-specific knowledge.
    ///
    /// - Returns: `nil` if a linear search should be attempted instead,
    ///   `Optional(nil)` if the element was not found, or
    ///   `Optional(Optional(index))` if an element was found.
    ///
    /// - Complexity: Hopefully less than O(`count`).
    @inlinable
    @inline(__always)
    public // dispatching
    func _customLastIndexOfEquatableElement(_ element: Element) -> Index?? {
        return nil
    }
}

extension Collection {
    @inlinable
    /*
     Colelciton 协议, 对于 map 进行了重写, 因为 count 可以确认最终的输出数组的大小. 所以, 这里直接进行了空间的扩展.
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
     
     可以看到, Sequence 里面的 map, 是通过迭代器控制的范围, 而 Collection 中, 则是通过 count.
     map 本身不是 Sequence 里面的函数, 也不是 colleciton 里面的函数.
     在调用的时候, swift 会自动调用最符合定义的函数.
     */
    public func map<T>(
        _ transform: (Element) throws -> T
    ) rethrows -> [T] {
        // TODO: swift-3-indexing-model - review the following
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
        _expectEnd(of: self, is: i)
        return Array(result)
    }
    
    /*
     dropFirst 的 Colelction 的实现.
     这里, 直接返回了 SubSequence 里面的值.
     在 Sequence 里面, 是生成了一个 Drop 版本的适配Sequence对象, 这里则是使用了 Collection 的 subSequence.
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
        var start = startIndex
        while try start != endIndex && predicate(self[start]) {
            formIndex(after: &start)
        }
        /*
         这里, 直接是操作的 index 这个值.
         */
        return self[start..<endIndex]
    }
    
    /*
     返回 集合的前多少个的子序列.
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
     返回集合前多少个子序列, 直到某个元素不符合条件了.
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
