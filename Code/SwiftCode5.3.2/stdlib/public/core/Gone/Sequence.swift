// Sequence 代表的是, 可以不断的读取数据的一种数据结构. 也就是可迭代的.
// 迭代器模式, 是一个已经老生常谈的模式了. 迭代的状态, 是保存在迭代器里面的, 这样, 一个序列, 就可以同时进行多个迭代了.
// 序列, 唯一的一个基本方法, 就是产生一个迭代器, 通过这个迭代器, 可以不断的进行取值.
// 一般来说, 迭代器里面, 会引用到序列对象. 并且应该完全了解序列对象取值, 取下一个值的逻辑. Collection 里面, 将这部分逻辑变到了 Collection 的 subscript, 以及 formIndex 里面. 在其他的语言里面, 直接是在迭代器内部, 进行容器相关数据的读取.
// For-In 可以当做是, 系统级别的语法趟, 这种语法和接口相关联的情况, 目前是越来越流行. Js 里面, 迭代也是一个接口的概念.
// 因为 Swift 里面, 写了大量的, 关于迭代这个概念的封装方法, 例如 map, foreach, reduce, 所以实际上, 迭代器很少有机会直接使用.
// 如果想要封装自己的一些逻辑, 那么应该在 Sequence 这个抽象上定义扩展进行编码.
// 可迭代这个概念, 不保证是可重复迭代的. 因为从前向后不断取值的这个行为, 太过于普遍了. 流媒体取值就是这样.
// 所以, 可不可以重复迭代, 是需要程序员按照情况分辨出来的. 如果, 不可重复迭代, 例如流的读取, 那么创建多个迭代器, 就会产生逻辑问题.
// C++ 里面, ForwardIterator, BidirectionIterator, RandomIterator.
// 但是对于迭代来说, 只是 1 能++, 2 能取值就可以了.

public protocol IteratorProtocol {
    associatedtype Element
    // Primitive Method.
    mutating func next() -> Element?
}

// 可迭代这件事, 是一个非常通用的行为. 只要提供了这个模型, 那么就可以去完成很多很多的, 固定的行为的算法.
// 这件事, 在 Swift 里面, 就是 protocol 和 extension 的组合.
// 提供一个迭代器. 这个操作, 应该是 O1 复杂度的.

public protocol Sequence {
    // Sequence 里面的泛型, Element 的实际类型, 由实现类来指定.
    associatedtype Element
    associatedtype Iterator: IteratorProtocol where Iterator.Element == Element
    // PrimitiveMethod, 返回一个迭代器.
    // Sequence 最重要的概念, 就是可迭代取值, 而这个过程是迭代器的责任. 所以, Sequence 的责任, 就是返回一个自己相关的迭代器.
    // 所以, 返回的是一个接口对象. 真正的实现类, 都是每个 Sequence 各自定义的.
    func makeIterator() -> Iterator
    
    // 预估的当前 Sequence 的长度. 实际上, 序列是没有长度的, 但是业务上, 大部分还是可以计算出来的.
    // 这个方法, 最主要的用法, 就是给容器进行初始化扩容, 算是算法上的优化.
    var underestimatedCount: Int { get }
    
    // 有没有快速的判断, Contians 的方法. 没有的话, 就要从头到尾遍历 == 判断.
    // 例如 range, 直接比较两个边界值就可以判断出 contains 了.
    // 这个方法, 是效率上的埋点.
    func _customContainsEquatableElement(
        _ element: Element
    ) -> Bool?
    
    func _copyToContiguousArray() -> ContiguousArray<Element>
    
    // 把 Sequence 里面的内容, 填充到了 UnsafeMutableBufferPointer<Element> 的内存里面.
    // 这个有默认实现
    func _copyContents(
        initializing ptr: UnsafeMutableBufferPointer<Element>
    ) -> (Iterator,UnsafeMutableBufferPointer<Element>.Index)
    
    // 这个函数, 就是为了得到序列内部的存储指针.
    // 默认是返回 nil 的. 应该只有连续存储, 例如 Array 可以实现这个方法, 就是把内部存储的地址空间暴露出来.
    // Swift 大量使用了 block, 通过 Block 进行一次封装, 可以避免传递出原始值来.
    func withContiguousStorageIfAvailable<R>(
        _ body: (UnsafeBufferPointer<Element>) throws -> R
    ) rethrows -> R?  
}

extension Sequence where Self: IteratorProtocol {
    public typealias _Default_Iterator = Self
}

extension Sequence where Self.Iterator == Self {
    public __consuming func makeIterator() -> Self {
        return self
    }
}

/*
 标准库里面, 定义代码段, 就是 init 方法, 和成员变量的定义
 然后在 Extension 里面, 进行其他方法的定义.
 这样感觉代码清晰不少, 应该值得学习.
 */

// 一个特殊的数据结构, 就是为了实现 Drop 这个方法.
// 装饰器模式的使用. base 是 Sequence 的, 自己是 Sequence 的. 在实现 Sequence 的时候, 是依靠 base, 但是在 Base 的前后, 进行自己逻辑的调用.
public struct DropFirstSequence<Base: Sequence> {
    internal let _base: Base
    internal let _limit: Int
    public init(_ base: Base, dropping limit: Int) {
        _base = base
        _limit = limit
    }
}

extension DropFirstSequence: Sequence {
    public typealias Element = Base.Element
    public typealias Iterator = Base.Iterator
    public typealias SubSequence = AnySequence<Element>
    
    // 到底, 如何实现 DropFirst 这个类所承担的责任, 怎么可以.
    // 这里是在 MakeIterator 的时候, 提前进行了消耗.
    public __consuming func makeIterator() -> Iterator {
        var it = _base.makeIterator()
        var dropped = 0
        while dropped < _limit, it.next() != nil { dropped &+= 1 }
        return it
    }
    
    public func dropFirst(_ k: Int) -> DropFirstSequence<Base> {
        return DropFirstSequence(_base, dropping: _limit + k)
    }
}

// PrefixSequence 特殊的 Sequence, 仅仅取前面一部分数据.
// 这个操作, 可以让无限的 Sequence 也能直接使用了, 因为可以按照业务场景规定距离.
public struct PrefixSequence<Base: Sequence> {
    internal var _base: Base
    internal let _maxLength: Int
    
    public init(_ base: Base, maxLength: Int) {
        _base = base
        _maxLength = maxLength
    }
}
extension PrefixSequence {
    public struct Iterator {
        internal var _base: Base.Iterator
        internal var _remaining: Int
        internal init(_ base: Base.Iterator, maxLength: Int) {
            _base = base
            _remaining = maxLength
        }
    }  
}
extension PrefixSequence.Iterator: IteratorProtocol {
    public typealias Element = Base.Element
    public mutating func next() -> Element? {
        if _remaining != 0 {
            _remaining &-= 1
            return _base.next()
        } else {
            return nil
        }
    }  
}
extension PrefixSequence: Sequence {
    public __consuming func makeIterator() -> Iterator {
        return Iterator(_base.makeIterator(), maxLength: _maxLength)
    }
    public __consuming func prefix(_ maxLength: Int) -> PrefixSequence<Base> {
        let length = Swift.min(maxLength, self._maxLength)
        return PrefixSequence(_base, maxLength: length)
    }
}

// DropWhile, 不断的消耗, 直到 Block 的返回值是 bool 才开始真正的迭代.
public struct DropWhileSequence<Base: Sequence> {
    public typealias Element = Base.Element
    
    internal var _iterator: Base.Iterator
    internal var _nextElement: Element?
    
    internal init(iterator: Base.Iterator, predicate: (Element) throws -> Bool) rethrows {
        _iterator = iterator
        _nextElement = _iterator.next()
        while let x = _nextElement, try predicate(x) {
            _nextElement = _iterator.next()
        }
    }
    internal init(_ base: Base, predicate: (Element) throws -> Bool) rethrows {
        self = try DropWhileSequence(iterator: base.makeIterator(), predicate: predicate)
    }
}
extension DropWhileSequence {
    public struct Iterator {
        internal var _iterator: Base.Iterator
        internal var _nextElement: Element?
        internal init(_ iterator: Base.Iterator, nextElement: Element?) {
            _iterator = iterator
            _nextElement = nextElement
        }
    }
}
extension DropWhileSequence.Iterator: IteratorProtocol {
    public typealias Element = Base.Element
    public mutating func next() -> Element? {
        guard let next = _nextElement else { return nil }
        _nextElement = _iterator.next()
        return next
    }
}
extension DropWhileSequence: Sequence {
    public func makeIterator() -> Iterator {
        return Iterator(_iterator, nextElement: _nextElement)
    }
    
    public __consuming func drop(
        while predicate: (Element) throws -> Bool
    ) rethrows -> DropWhileSequence<Base> {
        guard let x = _nextElement, try predicate(x) else { return self }
        return try DropWhileSequence(iterator: _iterator, predicate: predicate)
    }
}

// 以上的各种, 都是为了实现下面的 Sequence 的某个方法而创造出来的.
// 为了实现某个功能, 定义一个专门的数据结构来处理. 但是, 外界体会不出来, 因为新生成的对象, 有着和原有对象完全一致的抽象含义.
// 这种写法, 非常非常常见.

// 在 Sequence 的可迭代的基础上, 增加的各种算法, 可以利用一个简单的概念, 编写通用的算法, 这才是面向 protocol 编程的最核心的部分.
extension Sequence {
    // Map 就是, 返回一个数组, 数组里面的数据, 是 transform 变化过的.
    // OC id 就是泛型, Swift 里面的, 类型固定化, 是根据 block 的返回值确定出来的最终数组的类型.
    public func map<T>(
        _ transform: (Element) throws -> T
    ) rethrows -> [T] {
        // underestimatedCount 这个值, 可以大大减少由于数组扩容导致的性能损耗.
        // 最主要的就是数组, 因为数组是连续存储, 所以会经常碰到需要扩容拷贝的场景.
        let initialCapacity = underestimatedCount
        var result = ContiguousArray<T>()
        result.reserveCapacity(initialCapacity)
        
        var iterator = self.makeIterator()
        
        // 这里, 会稍微快一点点. 强制解包.
        for _ in 0..<initialCapacity {
            result.append(try transform(iterator.next()!))
        }
        while let element = iterator.next() {
            result.append(try transform(element))
        }
        return Array(result)
    }
    
    public __consuming func filter(
        _ isIncluded: (Element) throws -> Bool
    ) rethrows -> [Element] {
        return try _filter(isIncluded) // 不太明白, 这里的一层转化有什么目的, 这个函数内部, 并没有任何的其他逻辑.
    }
    
    public func _filter(
        _ isIncluded: (Element) throws -> Bool
    ) rethrows -> [Element] {
        // ContiguousArray 这个类应该好好看一下, 应该是 Swfit 比较常用的数组的实现.
        var result = ContiguousArray<Element>()
        var iterator = self.makeIterator()
        while let element = iterator.next() {
            if try isIncluded(element) {
                result.append(element)
            }
        }
        return Array(result)
    }
    
    // 默认是 0, 如果一个 protocol, 需要提供自己的一套算法. 并且在 protocol 的 primitive method 里面, 提供了一套算法可以加快效率, 那么可以在 primitive method 里面埋点, 并且提供默认实现.
    // 提供了默认的实现, 使用者就不一定非要实现这个方法了. 这种方法, 按理来说应该是 _ 开头的, 只有真正的熟悉了这套协议的人, 才应该使用这几个方法.
    public var underestimatedCount: Int {
        return 0
    }
    
    // 有没有更好的判断 contains 的方法, 如果有, 返回 Bool 值, 如果没有, 返回 nil.
    // 这里体现了 Optianl 的强大表达能力. 真实的值, 都是有效值. 而无效值, 是用 nil 这个特殊的 type 表示.
    public func _customContainsEquatableElement(
        _ element: Iterator.Element
    ) -> Bool? {
        return nil
    }
    
    // forEach, 不能 break, continue, return 也仅仅是提前退出 block 而已.
    public func forEach(
        _ body: (Element) throws -> Void
    ) rethrows {
        for element in self {
            try body(element)
        }
    }
}

extension Sequence {
    // 返回, 第一个可以满足 predicate 的 element. 这个用法很常见, 所以封装成为了方法, 本身逻辑不复杂.
    public func first(
        where predicate: (Element) throws -> Bool
    ) rethrows -> Element? {
        for element in self {
            if try predicate(element) {
                return element
            }
        }
        return nil
    }
}

extension Sequence where Element: Equatable {
    /// Returns the longest possible subsequences of the sequence, in order,
    /// around elements equal to the given element.
    ///
    /// The resulting array consists of at most `maxSplits + 1` subsequences.
    /// Elements that are used to split the sequence are not returned as part of
    /// any subsequence.
    ///
    /// The following examples show the effects of the `maxSplits` and
    /// `omittingEmptySubsequences` parameters when splitting a string at each
    /// space character (" "). The first use of `split` returns each word that
    /// was originally separated by one or more spaces.
    ///
    ///     let line = "BLANCHE:   I don't want realism. I want magic!"
    ///     print(line.split(separator: " ")
    ///               .map(String.init))
    ///     // Prints "["BLANCHE:", "I", "don\'t", "want", "realism.", "I", "want", "magic!"]"
    ///
    /// The second example passes `1` for the `maxSplits` parameter, so the
    /// original string is split just once, into two new strings.
    ///
    ///     print(line.split(separator: " ", maxSplits: 1)
    ///               .map(String.init))
    ///     // Prints "["BLANCHE:", "  I don\'t want realism. I want magic!"]"
    ///
    /// The final example passes `false` for the `omittingEmptySubsequences`
    /// parameter, so the returned array contains empty strings where spaces
    /// were repeated.
    ///
    ///     print(line.split(separator: " ", omittingEmptySubsequences: false)
    ///               .map(String.init))
    ///     // Prints "["BLANCHE:", "", "", "I", "don\'t", "want", "realism.", "I", "want", "magic!"]"
    ///
    /// - Parameters:
    ///   - separator: The element that should be split upon.
    ///   - maxSplits: The maximum number of times to split the sequence, or one
    ///     less than the number of subsequences to return. If `maxSplits + 1`
    ///     subsequences are returned, the last one is a suffix of the original
    ///     sequence containing the remaining elements. `maxSplits` must be
    ///     greater than or equal to zero. The default value is `Int.max`.
    ///   - omittingEmptySubsequences: If `false`, an empty subsequence is
    ///     returned in the result for each consecutive pair of `separator`
    ///     elements in the sequence and for each instance of `separator` at the
    ///     start or end of the sequence. If `true`, only nonempty subsequences
    ///     are returned. The default value is `true`.
    /// - Returns: An array of subsequences, split from this sequence's elements.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the sequence.
    @inlinable
    public __consuming func split(
        separator: Element,
        maxSplits: Int = Int.max,
        omittingEmptySubsequences: Bool = true
    ) -> [ArraySlice<Element>] {
        return split(
            maxSplits: maxSplits,
            omittingEmptySubsequences: omittingEmptySubsequences,
            whereSeparator: { $0 == separator })
    }
}

extension Sequence {
    
    /// Returns the longest possible subsequences of the sequence, in order, that
    /// don't contain elements satisfying the given predicate. Elements that are
    /// used to split the sequence are not returned as part of any subsequence.
    ///
    /// The following examples show the effects of the `maxSplits` and
    /// `omittingEmptySubsequences` parameters when splitting a string using a
    /// closure that matches spaces. The first use of `split` returns each word
    /// that was originally separated by one or more spaces.
    ///
    ///     let line = "BLANCHE:   I don't want realism. I want magic!"
    ///     print(line.split(whereSeparator: { $0 == " " })
    ///               .map(String.init))
    ///     // Prints "["BLANCHE:", "I", "don\'t", "want", "realism.", "I", "want", "magic!"]"
    ///
    /// The second example passes `1` for the `maxSplits` parameter, so the
    /// original string is split just once, into two new strings.
    ///
    ///     print(
    ///        line.split(maxSplits: 1, whereSeparator: { $0 == " " })
    ///                       .map(String.init))
    ///     // Prints "["BLANCHE:", "  I don\'t want realism. I want magic!"]"
    ///
    /// The final example passes `true` for the `allowEmptySlices` parameter, so
    /// the returned array contains empty strings where spaces were repeated.
    ///
    ///     print(
    ///         line.split(
    ///             omittingEmptySubsequences: false,
    ///             whereSeparator: { $0 == " " }
    ///         ).map(String.init))
    ///     // Prints "["BLANCHE:", "", "", "I", "don\'t", "want", "realism.", "I", "want", "magic!"]"
    ///
    /// - Parameters:
    ///   - maxSplits: The maximum number of times to split the sequence, or one
    ///     less than the number of subsequences to return. If `maxSplits + 1`
    ///     subsequences are returned, the last one is a suffix of the original
    ///     sequence containing the remaining elements. `maxSplits` must be
    ///     greater than or equal to zero. The default value is `Int.max`.
    ///   - omittingEmptySubsequences: If `false`, an empty subsequence is
    ///     returned in the result for each pair of consecutive elements
    ///     satisfying the `isSeparator` predicate and for each element at the
    ///     start or end of the sequence satisfying the `isSeparator` predicate.
    ///     If `true`, only nonempty subsequences are returned. The default
    ///     value is `true`.
    ///   - isSeparator: A closure that returns `true` if its argument should be
    ///     used to split the sequence; otherwise, `false`.
    /// - Returns: An array of subsequences, split from this sequence's elements.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the sequence.
    @inlinable
    public __consuming func split(
        maxSplits: Int = Int.max,
        omittingEmptySubsequences: Bool = true,
        whereSeparator isSeparator: (Element) throws -> Bool
    ) rethrows -> [ArraySlice<Element>] {
        _precondition(maxSplits >= 0, "Must take zero or more splits")
        let whole = Array(self)
        return try whole.split(
            maxSplits: maxSplits, 
            omittingEmptySubsequences: omittingEmptySubsequences, 
            whereSeparator: isSeparator)
    }
    
    // 对于序列来说, 想要最后几个值, 就是全局遍历的过程.
    // 这个在 Collection 里面, 有了更好的表达. 如果可 bidirection 的, 可以直接从后向前进行值的获取.
    public __consuming func suffix(_ maxLength: Int) -> [Element] {
        guard maxLength != 0 else { return [] }
        
        var ringBuffer = ContiguousArray<Element>()
        ringBuffer.reserveCapacity(Swift.min(maxLength, underestimatedCount))
        
        var i = 0
        
        for element in self {
            if ringBuffer.count < maxLength {
                ringBuffer.append(element)
            } else {
                ringBuffer[i] = element
                i = (i + 1) % maxLength
            }
        }
        
        if i != ringBuffer.startIndex {
            var rotated = ContiguousArray<Element>()
            rotated.reserveCapacity(ringBuffer.count)
            rotated += ringBuffer[i..<ringBuffer.endIndex]
            rotated += ringBuffer[0..<i]
            return Array(rotated)
        } else {
            return Array(ringBuffer)
        }
    }
    
    // 简单的函数, 包裹复杂的数据结构, 但是在使用者看来, 使用的是同样的 sequence 的逻辑.
    public __consuming func dropFirst(_ k: Int = 1) -> DropFirstSequence<Self> {
        return DropFirstSequence(self, dropping: k)
    }
    
    // 序列, 想要后面的值, 就是遍历.
    public __consuming func dropLast(_ k: Int = 1) -> [Element] {
        guard k != 0 else { return Array(self) }
        
        var result = ContiguousArray<Element>()
        var ringBuffer = ContiguousArray<Element>()
        var i = ringBuffer.startIndex
        
        // 一个简单的算法. 利用一个环状的缓存区.
        // 之所以, 要有这样一个缓存区, 是因为 sequence 本身是不能算出来区间的. 也就是说, 它并不是 randomAccess 的.
        for element in self {
            if ringBuffer.count < k {
                ringBuffer.append(element)
            } else {
                result.append(ringBuffer[i])
                ringBuffer[i] = element
                i = (i + 1) % k
            }
        }
        return Array(result)
    }
    
    // 简单的函数, 包裹复杂的数据结构, 但是在使用者看来, 使用的是同样的 sequence 的逻辑.
    public __consuming func drop(
        while predicate: (Element) throws -> Bool
    ) rethrows -> DropWhileSequence<Self> {
        return try DropWhileSequence(self, predicate: predicate)
    }
    
    // 简单的函数, 包裹复杂的数据结构, 但是在使用者看来, 使用的是同样的 sequence 的逻辑.
    public __consuming func prefix(_ maxLength: Int) -> PrefixSequence<Self> {
        return PrefixSequence(self, maxLength: maxLength)
    }
    
    
    
    public __consuming func prefix(
        while predicate: (Element) throws -> Bool
    ) rethrows -> [Element] {
        var result = ContiguousArray<Element>()
        
        for element in self {
            guard try predicate(element) else {
                break
            }
            result.append(element)
        }
        return Array(result)
    }
}

extension Sequence {
    
    // 就是迭代取值, 塞到对应的 ptr 的位置. ptr 更新指向.
    public func _copyContents(
        initializing buffer: UnsafeMutableBufferPointer<Element>
    ) -> (Iterator,UnsafeMutableBufferPointer<Element>.Index) {
        var it = self.makeIterator()
        guard var ptr = buffer.baseAddress else { return (it,buffer.startIndex) }
        
        for idx in buffer.startIndex..<buffer.count {
            guard let x = it.next() else {
                return (it, idx)
            }
            // 所以, 实际上就是根据一点点的填充值到对应的内存里面去
            // buffer 有个合适的 Count, 这个是调用者的责任.
            ptr.initialize(to: x)
            ptr += 1
        }
        return (it,buffer.endIndex)
    }
    
    // 默认不实现.
    public func withContiguousStorageIfAvailable<R>(
        _ body: (UnsafeBufferPointer<Element>) throws -> R
    ) rethrows -> R? {
        return nil
    }  
}

public struct IteratorSequence<Base: IteratorProtocol> {
    @usableFromInline
    internal var _base: Base
    
    /// Creates an instance whose iterator is a copy of `base`.
    @inlinable
    public init(_ base: Base) {
        _base = base
    }
}

extension IteratorSequence: IteratorProtocol, Sequence {
    public mutating func next() -> Base.Element? {
        return _base.next()
    }
}
