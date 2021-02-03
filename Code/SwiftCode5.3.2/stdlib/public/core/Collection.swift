// IndexingIterator 这个迭代器, 之所以通用, 是因为它本身就是建立在 Collection 的抽象接口上.
// Collection 在设计的时候, 是必须要完成这几个抽象接口的实现的, 所以, IndexingIterator 才能变得通用.

@frozen
public struct IndexingIterator<Elements: Collection> {
    // 在迭代器里面, 存储一下原来的 Collection, 以及当前的 index 位置.
    internal let _elements: Elements
    internal var _position: Elements.Index
    
    public /// @testable
    init(_elements: Elements) {
        self._elements = _elements
        // 只传入 elements 进来, position 默认是使用 startIndex
        self._position = _elements.startIndex
    }
    
    @inlinable
    @inline(__always)
    public /// @testable
    init(_elements: Elements, _position: Elements.Index) {
        self._elements = _elements
        self._position = _position
    }
}

extension IndexingIterator: IteratorProtocol, Sequence {
    public typealias Element = Elements.Element
    public typealias Iterator = IndexingIterator<Elements>
    public typealias SubSequence = AnySequence<Element>
        
    // 可迭代这个事情, 是 Sequence 的能力, 所以, 只要是 Collection 符合 Sequence 的要求, 它自动就变为了可迭代的.
    // 而作为一个 Collection 来说, 它的 iterator 是依靠 collection 的 formIndex 和 elemention 的 subscript[index] 来进行值的获取的.
    // 这两个函数, 是一个抽象的接口, 各种不同数据结构的容器, 根据同样的结构来编程, 比之前各个数据结构, 单独定义迭代的能力要更加的统一.
    public mutating func next() -> Elements.Element? {
        if _position == _elements.endIndex { return nil }
        let element = _elements[_position]
        _elements.formIndex(after: &_position)
        return element
    }
}

/// A sequence whose elements can be traversed multiple times,
/// nondestructively, and accessed by an indexed subscript.
/// 相比较序列这个概念, 容器多了几个特性.
/// 1. 可以多次迭代
/// 2. 可以直接根据下标进行取值.
/// 直接通过下标取值, 之前是随机存取容器的特性, 但是这里有些不一样. 就是下标如何获取.
/// 如果一个下标, 可以根据偏移量直接获取另外一个有效的下标, 这样才符合随机存储的特性. 如果, 需要遍历, 例如链表, 那么就不符合随机存储的特性.
///
/// Collection 是继承自 Sequence 的, 所以序列的各种操作, 它都可以使用. 和 Sequence 最大的不同, 就是可以按照位置取值.
/// 根据位置取值, 也创造了容器的一个很大的操作, 就是 CollectionSlice. 这样, 避免了非必要的数据搬移的工作.
///
/// 同原有的理念是一样的, endIndex 是一个标志位, 不同通过这个标志位取值. 在 C++ 里面, 这个标志位一般用于判断结束.
///
/// 传递下标到容器中, 这个过程, 下标的有效性, 是程序员来控制的. 容器必须提供, start, end 这两个位置的下标值. 这和之前的容器的概念是相符的.
/// 不管是什么容器, 从 start, 到 end 缕一遍, 也就是序列的操作, 是必须支持的, 这是容器 "可以按照下标获取数据" 的协议内容规定的.
/// 容器符合协议的默认实现, 也是根据不断的获取下标的 successor, 然后根据新的下标值获取容器里面的内容实现的.
///
/// 存储索引, 不是一个好习惯. 就和 hash 值一样, 这些值, 更多的是过程值. 索引, 会随着容器的可变性, 经常发生变化.
/// 一个容器的索引, 自然是不能够用到另外一个容器中.
///
/// Slice 是共享内存的. 具体的实现看代码细节.
///
/// 容器, 必须是有限的, 必须是可以重复访问的.
/// 这里, 之所以相同, 是因为 word.indices 返回的序列的遍历顺序, 是和 word 作为序列的遍历顺序是相同的.
///     let word = "Swift"
///     for character in word {
///         print(character)
///     }
///     // Prints "S"
///     // Prints "w"
///     // Prints "i"
///     // Prints "f"
///     // Prints "t"
///
///     for i in word.indices {
///         print(word[i])
///     }
///     // Prints "S"
///     // Prints "w"
///     // Prints "i"
///     // Prints "f"
///     // Prints "t"
///
/// If you create a custom sequence that can provide repeated access to its
/// elements, make sure that its type conforms to the `Collection` protocol in
/// order to give a more useful and more efficient interface for sequence and
/// collection operations. To add `Collection` conformance to your type, you
/// must declare at least the following requirements:
///
/// 实际上, 容器仅仅要求下面三个部分.
/// start, end. 作为迭代的两端标记. 根据下标, 取值的操作, 以及根据上一个下标, 寻找下一个下标的操作.
/// - The `startIndex` and `endIndex` properties
/// - A subscript that provides at least read-only access to your type's
///   elements
/// - The `index(after:)` method for advancing an index into your collection
///
/// Expected Performance
/// ====================
/// 性能主要有两点, 1 start, end 应该是 O1 时间复杂度的, 2 index 的不同, 影响到了 randomAccess, BidirectionAccess.


public protocol Collection: Sequence {
    // Index 的间距.
    typealias IndexDistance = Int
    override associatedtype Element
    
    // Index 的类型, 是各个 Collection 来自定义的. 它的唯一的要求, 就是可以比较.
    // Strideable 指的是, 可判断大小, 并且可以计算出两个值之间的间距来. 同样的, 可以根据间距, 来获取对应的值
    // 但是 Index 不是 Strideable 的, 只有 randomCollection 才是 Strideable 的.
    // 例如, 单向链表, 给两个链表的 Index, 也就是两个指针是无法计算出他们之间的间距的. 两个指针, 本身是无法判断大小的.
    associatedtype Index: Comparable // Comparable 的唯一的标准, 就是可以判断大小.
    
    // 必须实现, 没有默认实现
    var startIndex: Index { get }
    // 必须实现, 没有默认实现
    var endIndex: Index { get }
    associatedtype Iterator = IndexingIterator<Self>
    // 默认返回 IndexingIterator
    override __consuming func makeIterator() -> Iterator
    
    
    // SubSequence 就是 Slice<Self>, 并且 Index, Element 都有要求, 都要和 Self 的相等.
    // SubSequence 作为一个 Collection, 同样应该有 SubSequence. 也应该是 Slice<Self>
    // 这里 的 Self 指的是类型.
    associatedtype SubSequence: Collection = Slice<Self>
    where SubSequence.Index == Index, Element == SubSequence.Element, SubSequence.SubSequence == SubSequence
    
    // 必须实现, 没有默认实现.
    // 最最重要的方法, 根据合理的 Index 值, 获取链表内的数据.
    // 设想一下 哈希表的迭代器, 里面存储的是一个指针, *Iter 的时候, 是根据这个指针直接获取值.
    // 数组, Iter 直接就是 Int 下标, 现在统一到了 subscript(position: Index) 一个操作里面. Index 到底如何设计, 是直接 和 subscript(position: Index) 这个方法相关的.
    subscript(position: Index) -> Element { get }
    
    // Range 的要求, 是 lowerBound, upperBound 是 Comparable, 而 Collection, 是可以根据 FormIndex 获取到一个 Index 的下一个位置的. 所以, Range 这个数据结构, 从 Low --> Upper 的过程, 一定是获取到的连续的 Index 值.
    // 这也就是为什么 Accesses a contiguous subrange of the collection's elements 的原因.
    subscript(bounds: Range<Index>) -> SubSequence { get }
    
    associatedtype Indices: Collection = DefaultIndices<Self>
    where Indices.Element == Index, 
          Indices.Index == Index,
          Indices.SubSequence == Indices
    
    // 默认返回 DefaultIndices
    var indices: Indices { get }
    
    // 默认比较, start end 是否相等.
    var isEmpty: Bool { get }
    
    // 默认计算 start, end 的距离, 使用 distance 方法. 而 Distance 方法, 是使用 start, End 两个 index 进行一次遍历操作.
    var count: Int { get }
    
    // 一个快速的, 计算出 element 对应 Index 的方法.
    // 如果没有实现这个方法, 返回 nil. 如果实现了这个方法, 返回 Optinal(Index), 有可能返回 Optioanl(nil), 表示有特殊的判断的方法, 但是当前容器没有 element 的值.
    // 因为 Swift 的 Optinal 的特性, 使得本来一个 Bool, 一个 Index 返回的方式, 变为了一个方法.
    // 默认返回 nil, 表明没有这个一个方法.
    func _customIndexOfEquatableElement(_ element: Element) -> Index??
    
    // 和 _customIndexOfEquatableElement 几乎相同, 只是从后向前找, 默认是返回 nil, 表明没有这么一个方法.
    func _customLastIndexOfEquatableElement(_ element: Element) -> Index??
    
    // 返回传入索引 distance 距离的索引. 默认是遍历获取到目标索引.
    func index(_ i: Index, offsetBy distance: Int) -> Index
    
    // 返回传入索引 distance 距离的索引. 如果是超过了 limit, 返回 nil. 这个函数, 有了更加安全的设计思路.
    func index(
        _ i: Index, offsetBy distance: Int, limitedBy limit: Index
    ) -> Index?
    
    // 返回两个索引之间的距离, 默认, 是遍历获取到 result.
    func distance(from start: Index, to end: Index) -> Int
    
    // 安全性校验,
    func _failEarlyRangeCheck(_ index: Index, bounds: Range<Index>)
    func _failEarlyRangeCheck(_ index: Index, bounds: ClosedRange<Index>)
    func _failEarlyRangeCheck(_ range: Range<Index>, bounds: Range<Index>)
        
    // 没有默认实现, 如何从目标 Index 获取到下一个 Index. 各个 Collection 子类单独设计.
    func index(after i: Index) -> Index
    // 默认使用 Index 的实现.
    func formIndex(after i: inout Index)
}

extension Collection {
    public func formIndex(after i: inout Index) {
        i = index(after: i)
    }
    public func _failEarlyRangeCheck(_ index: Index, bounds: Range<Index>) {
        _precondition(
            bounds.lowerBound <= index,
            "Out of bounds: index < startIndex")
        _precondition(
            index < bounds.upperBound,
            "Out of bounds: index >= endIndex")
    }
    public func _failEarlyRangeCheck(_ index: Index, bounds: ClosedRange<Index>) {
        _precondition(
            bounds.lowerBound <= index,
            "Out of bounds: index < startIndex")
        _precondition(
            index <= bounds.upperBound,
            "Out of bounds: index > endIndex")
    }
    public func _failEarlyRangeCheck(_ range: Range<Index>, bounds: Range<Index>) {
        // FIXME: swift-3-indexing-model: tests.
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
    
    // distance 的默认实现, 遍历获取 result
    // 在 RandomAccess 里面, 是直接使用 Index, 也就是 Stridable 的 distance 方法.
    public func distance(from start: Index, to end: Index) -> Int {
        var start = start
        var count = 0
        while start != end {
            count = count + 1
            formIndex(after: &start)
        }
        return count
    }
    
    // 实现原理就是, 随便找一个距离计算出 Index 值, 然后根据这个 Index 取值.
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
    
    // 这两个函数是在 Extension 里面的, 是没有办法复写的, 想要复写, 只有复写 index 方法, 或者 formIndex 方法.
    // 下面两个函数, 就是逐步获取目标 Index 的过程.
    // 可以看到, 都是使用了最基本的方法, formIndex.
    internal func _advanceForward(_ i: Index, by n: Int) -> Index {
        var i = i
        for _ in stride(from: 0, to: n, by: 1) {
            formIndex(after: &i)
        }
        return i
    }
    
    internal func _advanceForward(
        _ i: Index, by n: Int, limitedBy limit: Index
    ) -> Index? {
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

// MakeIterator 的默认实现, 就是生成一个 IndexingIterator,
extension Collection where Iterator == IndexingIterator<Self> {
    public __consuming func makeIterator() -> IndexingIterator<Self> {
        return IndexingIterator(_elements: self)
    }
}

extension Collection where SubSequence == Slice<Self> {
    public subscript(bounds: Range<Index>) -> Slice<Self> {
        return Slice(base: self, bounds: bounds)
    }
}

extension Collection where SubSequence == Self {
    @inlinable
    public mutating func popFirst() -> Element? {
        // isEmpty 其实感觉用方法来表示要好一点
        guard !isEmpty else { return nil }
        let element = first!
        self = self[index(after: startIndex)..<endIndex]
        return element
    }
}

extension Collection {
    // 使用 startIndex 和 endIndex 来比较. 因为 startIndex, endIndex 都是 comparable 的.
    // 之所以这样效率高, 是因为 Collection 有义务在 O1 内得到 start 和 end, 并且他们确实是可比较的.
    // 这, 都是协议层面的限制.
    public var isEmpty: Bool {
        return startIndex == endIndex
    }
    
    // 同传统的容器获取相比, 多了 isEmpty 的判断.
    public var first: Element? {
        let start = startIndex
        if start != endIndex { return self[start] }
        else { return nil }
    }
    
    @inlinable
    public var underestimatedCount: Int {
        return count
    }
    
    // 默认是遍历获取, random 有着更好的实现效率
    public var count: Int {
        return distance(from: startIndex, to: endIndex)
    }
    
    // 模板方法的策略
    public // dispatching
    func _customIndexOfEquatableElement(_: Element) -> Index?? {
        return nil
    }
    
    // 模板方法的策略
    public // dispatching
    func _customLastIndexOfEquatableElement(_ element: Element) -> Index?? {
        return nil
    }
}

extension Collection {
    // 如果是 Collection, 就走这里的 map, 相比 sequence, 这里的更加准确.
    // 在 Collection 里面, 直接使用了是[] 作为 element 的取值操作.
    // 在 Sequence 里面, 是使用的迭代器的 next 来进行的取值.
    public func map<T>(
        _ transform: (Element) throws -> T
    ) rethrows -> [T] {
        
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
        
        // Array 一定有着相对于 ContiguousArray 非常高效的实现
        return Array(result)
    }
    
    // Sequence 是返回 DropFirstSequence, DropFirstSequence 首先会消耗 base sequence 的迭代器 k 次, 这样取值的时候, 就能拿到 k + 1 位置的数据
    // Collection 是返回 Slice. 里面的逻辑, 其实是使用了 subscript(bounds: Range<Index>) -> SubSequence { get }
    // 因为, Swift 是一个强类型的语言, 所以, Collection 返回的 Slice.
    public __consuming func dropFirst(_ k: Int = 1) -> SubSequence {
        _precondition(k >= 0, "Can't drop a negative number of elements from a collection")
        let start = index(startIndex, offsetBy: k, limitedBy: endIndex) ?? endIndex
        return self[start..<endIndex]
    }
    
    // public __consuming func dropLast(_ k: Int = 1) -> [Element]
    // 在 sequence 里面, dropLast 返回的是 一个数组, 在实现层面, 他其实要遍历整个sequence, 才能返回数据.
    // Collection 里面, 返回的还是 slice, 根本没有遍历的过程.
    @inlinable
    public __consuming func dropLast(_ k: Int = 1) -> SubSequence {
        _precondition(
            k >= 0, "Can't drop a negative number of elements from a collection")
        let amount = Swift.max(0, count - k)
        let end = index(startIndex,
                        offsetBy: amount, limitedBy: endIndex) ?? endIndex
        return self[startIndex..<end]
    }
    
    // return try DropWhileSequence(self, predicate: predicate)
    // 在 Sequence 里面, 返回的是 DropWhileSequence, 该类会在创建的时候, 消耗 base 的迭代器, 直到可以返回正确的数据了
    // Collection 里面, 返回的是 Slice. 思路和 DropWhileSequence 一样, 提前消耗.
    @inlinable
    public __consuming func drop(
        while predicate: (Element) throws -> Bool
    ) rethrows -> SubSequence {
        var start = startIndex
        while try start != endIndex && predicate(self[start]) {
            formIndex(after: &start)
        }
        return self[start..<endIndex]
    }
    
    // PrefixSequence(self, maxLength: maxLength)
    // Sequence 里面, 是返回 PrefixSequence, 该类会在遍历的时候, 提前消耗前面 length 次遍历.
    // Collection 里面, 也是提前消耗, 不过是 index 的直接计算, 然后返回相应的切片.
    @inlinable
    public __consuming func prefix(_ maxLength: Int) -> SubSequence {
        _precondition(
            maxLength >= 0,
            "Can't take a prefix of negative length from a collection")
        let end = index(startIndex,
                        offsetBy: maxLength, limitedBy: endIndex) ?? endIndex
        return self[startIndex..<end]
    }
    
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
    
    // Sequence 里面, 返回的是 [Element], 需要完全遍历整个序列.
    // Collection 里面, 直接就是返回的切片.
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
    
    public __consuming func prefix(upTo end: Index) -> SubSequence {
        return self[startIndex..<end]
    }
    
    public __consuming func suffix(from start: Index) -> SubSequence {
        return self[start..<endIndex]
    }
    
    // 任何, 右闭的实现, 都可以通过 after 1 + 前闭后开来实现.
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
        guard let idx = index(startIndex, offsetBy: k, limitedBy: endIndex) else {
            _preconditionFailure(
                "Can't remove more items from a collection than it contains")
        }
        self = self[idx..<endIndex]
    }
}
