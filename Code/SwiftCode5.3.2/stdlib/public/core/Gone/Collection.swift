// IndexingIterator 这个迭代器, 之所以通用, 是因为它本身就是建立在 Collection 的抽象接口上.
// Collection 在设计的时候, 是必须要完成这几个抽象接口的实现的, 所以, IndexingIterator 才能变得通用.

public struct IndexingIterator<Elements: Collection> {
    // 存储一下容器的数据.
    internal let _elements: Elements
    // 存储一下当前的迭代位置
    internal var _position: Elements.Index
    init(_elements: Elements) {
        self._elements = _elements
        self._position = _elements.startIndex
    }
    init(_elements: Elements, _position: Elements.Index) {
        self._elements = _elements
        self._position = _position
    }
}

extension IndexingIterator: IteratorProtocol, Sequence {
    public typealias Element = Elements.Element
    public typealias Iterator = IndexingIterator<Elements>
    public typealias SubSequence = AnySequence<Element>
    
    // 这个统一的迭代器, 是依靠 collection 的 subscript, 以及 formindex 进行的迭代.
    // 所以, 是把抽象的能力, 放到了 Collection 里面了.
    public mutating func next() -> Elements.Element? {
        if _position == _elements.endIndex { return nil }
        let element = _elements[_position]
        _elements.formIndex(after: &_position)
        return element
    }
}

// 相比较序列这个概念, 容器多了几个特性.
// 1. 可以多次迭代
// 2. 可以直接根据Index进行取值.

// 这里的 Index 是每个容器特殊的数据结构, 一般会和容器的底层存储相关联. 所以, 如果能够计算出 Index 来, 那么就可以直接能够根据 Index 获取相应位置的值了.
// C++ 里面, 迭代器 forward, bidirection, 以及 random, 其实都是对于这个 Index 的操作的分别.
// 最基本的就是 forward, 如果可以向前迭代, 也就是根据当前的 index, 计算出上一个 index, 那么就是 bidirection
// 如果, 可以根据 index, 计算出几个 distance 之后的 index, 那么就是 random 的, 这里的计算要求是 o1 时间复杂度的.
// 所以, Swift 这里, 将 Colleciton 分为了好几个协议, 这些协议的主要区别, 都是围绕着 Index 展开的.

// 容器, 必须是可多次迭代器, 必须是有限的.
// 必须能够在 O1 的事件复杂度内, 提供 start, end
// 必须提供 index 向后遍历的能力.
// 必须提供, 通过 Index 取值的能力
// 以上就是容器这个抽象的最主要的几个基本方法了.

public protocol Collection: Sequence {
    // Index 的间距.
    typealias IndexDistance = Int
    override associatedtype Element
    // Index 的唯一要求, 可以比大小
    // Random, Bidireaction, 被归到了更加特殊的协议中.
    associatedtype Index: Comparable
    
    // 必须实现, 没有默认实现
    var startIndex: Index { get }
    // 必须实现, 没有默认实现
    var endIndex: Index { get }
    
     // 对于 Sequence 有着默认的实现.
    associatedtype Iterator = IndexingIterator<Self>
    func makeIterator() -> Iterator
    
        
    // Slice 就是, 存储 Collection, 存储 startIndex, endIndex
    // 共享内存, 并且提供写时复制的功能.
    associatedtype SubSequence: Collection = Slice<Self>
    where SubSequence.Index == Index, Element == SubSequence.Element, SubSequence.SubSequence == SubSequence
    
    // 必须实现, 没有默认实现.
    // 最最重要的方法, 取值的过程.
    subscript(position: Index) -> Element { get }
    
    subscript(bounds: Range<Index>) -> SubSequence { get }
    
    associatedtype Indices: Collection = DefaultIndices<Self>
    where Indices.Element == Index, 
          Indices.Index == Index,
          Indices.SubSequence == Indices
    
    // 默认实现, 就是返回 DefaultIndices<Self>, 把自己, startIndex, endIndex 传入进去.
    var indices: Indices { get }
    
    // 默认比较, start end 是否相等.
    var isEmpty: Bool { get }
    
    // 默认计算 start, end 的距离, 使用 distance 方法.
    // 而 Distance 方法, 是使用 start, End 两个 index 进行一次遍历操作.
    // 各个实现类, 就算不是 random 的, 也可以重写, 只要容器内存, 每次数据操作的时候, 能够正确的记录 count 就可以了.
    var count: Int { get }
    
    // 一个快速的, 计算出 element 对应 Index 的方法.
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
    
    // Primitive Method, 如何进行遍历, 也就是如何根据一个 Index 求得下一个 Index
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
    
    public func index(_ i: Index, offsetBy distance: Int) -> Index {
        return self._advanceForward(i, by: distance)
    }
    
    public func index(
        _ i: Index, offsetBy distance: Int, limitedBy limit: Index
    ) -> Index? {
        return self._advanceForward(i, by: distance, limitedBy: limit)
    }
    
    public func formIndex(_ i: inout Index, offsetBy distance: Int) {
        i = index(i, offsetBy: distance)
    }
    
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
    
    public func randomElement<T: RandomNumberGenerator>(
        using generator: inout T
    ) -> Element? {
        guard !isEmpty else { return nil }
        let random = Int.random(in: 0 ..< count, using: &generator)
        let idx = index(startIndex, offsetBy: random)
        return self[idx]
    }
    
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

// 根据 Range 返回子容器, 就是返回一个切片.
extension Collection where SubSequence == Slice<Self> {
    public subscript(bounds: Range<Index>) -> Slice<Self> {
        return Slice(base: self, bounds: bounds)
    }
}

extension Collection where SubSequence == Self {
    public mutating func popFirst() -> Element? {
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
    
    // Collection 里面, 对于迭代相关的实现, 是使用了 Index, 而不是迭代器.
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
    // Colllection 是返回一个切片, 切片仅仅是一个数据对象的创建.
    public __consuming func dropFirst(_ k: Int = 1) -> SubSequence {
        let start = index(startIndex, offsetBy: k, limitedBy: endIndex) ?? endIndex
        return self[start..<endIndex]
    }
    
    // 在 sequence 里面, dropLast 返回的是 一个数组, 在实现层面, 他其实要遍历整个sequence, 才能返回数据.
    // Collection 是返回一个切片, 切片仅仅是一个数据对象的创建. 根本不需要遍历.
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
    // Collection 是返回一个切片, 切片仅仅是一个数据对象的创建. 根本不需要遍历.
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
    // Collection 是返回一个切片, 切片仅仅是一个数据对象的创建. 根本不需要遍历.
    public __consuming func prefix(_ maxLength: Int) -> SubSequence {
        _precondition(
            maxLength >= 0,
            "Can't take a prefix of negative length from a collection")
        let end = index(startIndex,
                        offsetBy: maxLength, limitedBy: endIndex) ?? endIndex
        return self[startIndex..<end]
    }
    
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
