// A type that supplies the values of a sequence one at a time.
// 序列是一个概念, 这个概念, 就是线性的数据. 可以从头到尾, 不断的获取数据.
// 这里, 线性指的是可以不断的拿取数据, 不代表着, 从业务上看, 这些数据都是有序的.

// 迭代器模式, 是一个已经老生常谈的模式了. 迭代的状态, 是保存在迭代器里面的, 这样, 一个序列, 就可以同时进行多个迭代了.
// 序列, 唯一的 primitiveMethod, 就是产生一个迭代器, 通过这个迭代器, 可以不断的进行取值.

// for-in 仅仅是一个语法趟, 他要求的是, in 后面的, 是一个序列. 这样, 就可以通过这个序列, 获取到对应的迭代器, 然后这个迭代器, 就可以不断的进行取值操作了, 然后, 把这个值存到 for 后面的变量里面.
// 所以这里会有一份值的拷贝的过程, 在 for in { } 的代码段里面修改 value, 不会影响到序列里面的内容, 当然, 如果是引用值就是另外一种情况.


/// Using a sequence's iterator directly gives you access to the same elements
/// in the same order as iterating over that sequence using a `for`-`in` loop.
/// For example, you might typically use a `for`-`in` loop to print each of
/// the elements in an array.
///
///     let animals = ["Antelope", "Butterfly", "Camel", "Dolphin"]
///     for animal in animals {
///         print(animal)
///     }
///     // Prints "Antelope"
///     // Prints "Butterfly"
///     // Prints "Camel"
///     // Prints "Dolphin"
///
/// Behind the scenes, Swift uses the `animals` array's iterator to loop over
/// the contents of the array.
///
///     var animalIterator = animals.makeIterator()
///     while let animal = animalIterator.next() {
///         print(animal)
///     }
///     // Prints "Antelope"
///     // Prints "Butterfly"
///     // Prints "Camel"
///     // Prints "Dolphin"
// 以上是一个例子, 证明了, forin 仅仅是 while 的包装而已 .
// 所以, 其实 forin 也可以当做是传入闭包的函数, forin {} 代码段是真正变化的地方, 获得迭代器, 赋值, 这些都是固定的算法.


// 一般情况下, 不需要直接使用到迭代器. 但是, 就如同 forin 这个固定的算法, 使用的是迭代的这个概念.
// 如果, 想要实现自己的, 通过迭代这个概念而架构出来的算法, 那么就应该直接使用迭代器了.
///     一个特定的算法, 需要使用迭代的概念.
///     extension Sequence {
///         func reduce1(
///             _ nextPartialResult: (Element, Element) -> Element
///         ) -> Element?
///         {
///             var i = makeIterator()
///             guard var accumulated = i.next() else {
///                 return nil
///             }
///
///             while let element = i.next() {
///                 accumulated = nextPartialResult(accumulated, element)
///             }
///             return accumulated
///         }
///     }
///
/// 这个算法这样对吗, reduce 归纳. 这样算不算, 使用了 reduce 这个概念去做不符合这个概念的事情.
/// The `reduce1(_:)` method makes certain kinds of sequence operations
/// simpler. Here's how to find the longest string in a sequence, using the
/// `animals` array introduced earlier as an example:
///
///     let longestAnimal = animals.reduce1 { current, element in
///         if current.count > element.count {
///             return current
///         } else {
///             return element
///         }
///     }
///     print(longestAnimal)
///     // Prints "Butterfly"
///

// 可迭代这个概念, 不保证是可重复迭代的. 因为从前向后不断取值的这个行为, 太过于普遍了. 流媒体取值就是这样.
// 所以, 可不可以重复迭代, 是需要程序员按照情况分辨出来的. 如果, 不可重复迭代, 例如流的读取, 那么创建多个迭代器, 就会产生逻辑问题.

/// Adding IteratorProtocol Conformance to Your Type
// IteratorProtocol 的实现很简单, 就是一个 next 函数, 这应该是 java 的迭代风格的实现.

///
/// For example, consider a custom `Countdown` sequence. You can initialize the
/// `Countdown` sequence with a starting integer and then iterate over the
/// count down to zero. The `Countdown` structure's definition is short: It
/// contains only the starting count and the `makeIterator()` method required
/// by the `Sequence` protocol.
///
///     struct Countdown: Sequence {
///         let start: Int
///         func makeIterator() -> CountdownIterator {
///             return CountdownIterator(self)
///         }
///     }
///     所以, 序列仅仅是一个抽象的概念, 可以迭代. 而迭代的具体实施, 就是迭代器的职责了. 一般来说, 迭代器会记录当前的迭代状态, 以及所属的序列的值. 当然, 因为值都是迭代器获取的. 所以, 序列完全可以是一个虚拟的计算出来的序列, 值的产生, 只要在迭代器的 next 方法里面获取得到就可以了.
///
///     这里, 算不算是相互依赖呢.
///     struct CountdownIterator: IteratorProtocol {
///         let countdown: Countdown
///         var times = 0
///
///         init(_ countdown: Countdown) {
///             self.countdown = countdown
///         }
///
///         mutating func next() -> Int? {
///             let nextNumber = countdown.start - times
///             guard nextNumber > 0
///                 else { return nil }
///
///             times += 1
///             return nextNumber
///         }
///     }


public protocol IteratorProtocol {
    // associatedtype, 协议里面的泛型. 由实现类型, 来去确认, associate 到底是什么类型.
    associatedtype Element
    // 迭代器的唯一限制, 就是可以取值, 可以 ++ .
    mutating func next() -> Element?
}

// 可迭代这件事, 是一个非常通用的行为. 只要提供了这个模型, 那么就可以去完成很多很多的, 固定的行为的算法.
// 这件事, 在 Swift 里面, 就是 protocol 和 extension 的组合.

///     let bugs = ["Aphid", "Bumblebee", "Cicada", "Damselfly", "Earwig"]
///     var hasMosquito = false
///     for bug in bugs {
///         if bug == "Mosquito" {
///             hasMosquito = true
///             break
///         }
///     }
///     print("'bugs' has a mosquito: \(hasMosquito)")
///     // Prints "'bugs' has a mosquito: false"
///
///     if bugs.contains("Mosquito") {
///         print("Break out the bug spray.")
///     } else {
///         print("Whew, no mosquitos!")
///     }
///
///     上面的算法, 就是 contains 的实现逻辑. 因为这个逻辑, 其实在太平常了, 所以 extension 收录了该算法.
///     Swift 的 extension, 使得使用它的程序员, 有了操作, 丰富标准库的能力.
///
///
/// Repeated Access
/// ===============
// 序列这个概念, 本身, 并不保证可以重复迭代. 这是程序员自己的责任.
///
/// Conforming to the Sequence Protocol
/// ===================================
/// 提供一个迭代器. 这个操作, 应该是 O1 复杂度的.


public protocol Sequence {
    // Sequence 里面的泛型, Element 的实际类型, 由实现类来指定.
    associatedtype Element
    associatedtype Iterator: IteratorProtocol where Iterator.Element == Element
    
    // 最重要的办法, 返回一个迭代器. 这里, __consuming 其实没有太大的作用, 应该仅仅是一个标识符.
    __consuming func makeIterator() -> Iterator
    
    
    
    // 余下的, 都是算法层面, 为了可以更加快速的实现, 引入的机制. 这些都有默认的实现.
    // 一个标识, 自己有多少个元素. 算法里面, 可以根据该值, 做出更加快速的选择.
    var underestimatedCount: Int { get }
    
    func _customContainsEquatableElement(
        _ element: Element
    ) -> Bool?
    
    /// Create a native array buffer containing the elements of `self`,
    /// in the same order.
    __consuming func _copyToContiguousArray() -> ContiguousArray<Element>
    
    /// Copy `self` into an unsafe buffer, returning a partially-consumed
    /// iterator with any elements that didn't fit remaining.
    __consuming func _copyContents(
        initializing ptr: UnsafeMutableBufferPointer<Element>
    ) -> (Iterator,UnsafeMutableBufferPointer<Element>.Index)
    
    /// Call `body(p)`, where `p` is a pointer to the collection's
    /// contiguous storage.  If no such storage exists, it is
    /// first created.  If the collection does not support an internal
    /// representation in a form of contiguous storage, `body` is not
    /// called and `nil` is returned.
    ///
    /// A `Collection` that provides its own implementation of this method
    /// must also guarantee that an equivalent buffer of its `SubSequence` 
    /// can be generated by advancing the pointer by the distance to the
    /// slice's `startIndex`.
    func withContiguousStorageIfAvailable<R>(
        _ body: (UnsafeBufferPointer<Element>) throws -> R
    ) rethrows -> R?  
}

// Provides a default associated type witness for Iterator when the
// Self type is both a Sequence and an Iterator.
extension Sequence where Self: IteratorProtocol {
    // @_implements(Sequence, Iterator)
    public typealias _Default_Iterator = Self
}

/// A default makeIterator() function for `IteratorProtocol` instances that
/// are declared to conform to `Sequence`
// 如果, 一个序列,
extension Sequence where Self.Iterator == Self {
    /// Returns an iterator over the elements of this sequence.
    @inlinable
    public __consuming func makeIterator() -> Self {
        return self
    }
}


// 类的定义在一个代码块里面, 对于协议的实现在另外的一个代码块里面.
// drop, 并没有提前消耗这个序列, 仅仅是在需要的时候, 越过之前的几个数据.
@frozen
public struct DropFirstSequence<Base: Sequence> {
    @usableFromInline
    internal let _base: Base
    @usableFromInline
    internal let _limit: Int
    
    @inlinable 
    public init(_ base: Base, dropping limit: Int) {
        _precondition(limit >= 0, 
                      "Can't drop a negative number of elements from a sequence")
        _base = base
        _limit = limit
    }
}

extension DropFirstSequence: Sequence {
    public typealias Element = Base.Element
    public typealias Iterator = Base.Iterator
    public typealias SubSequence = AnySequence<Element>
    
    // 在 DropFirst 进行迭代器的生成的时候, 提前把数据消耗了. 这样, 外界使用的时候, 就直接拿到目标位置的数据了.
    // 需要注意的是, _limit 是一个常量值, 只有这样, 在下面 dropFirst(_ k: Int) 的实现的时候, 才能够正确的表达
    @inlinable
    public __consuming func makeIterator() -> Iterator {
        var it = _base.makeIterator()
        var dropped = 0
        while dropped < _limit, it.next() != nil { dropped &+= 1 }
        return it
    }
    
    @inlinable
    public __consuming func dropFirst(_ k: Int) -> DropFirstSequence<Base> {
        // If this is already a _DropFirstSequence, we need to fold in
        // the current drop count and drop limit so no data is lost.
        //
        // i.e. [1,2,3,4].dropFirst(1).dropFirst(1) should be equivalent to
        // [1,2,3,4].dropFirst(2).
        return DropFirstSequence(_base, dropping: _limit + k)
    }
}

// 只消耗前面几个数据. maxLength 提供.
// 任何, 只要是不应该暴露出去的数据, 在类里面, 都应该用 _ 作为前缀进行表示.
@frozen
public struct PrefixSequence<Base: Sequence> {
    @usableFromInline
    internal var _base: Base
    @usableFromInline
    internal let _maxLength: Int
    
    @inlinable
    public init(_ base: Base, maxLength: Int) {
        _precondition(maxLength >= 0, "Can't take a prefix of negative length")
        _base = base
        _maxLength = maxLength
    }
}

// 返回一个特殊的迭代器, 迭代器内部, 自动设置最后的 limit 位置. 如果达到了, 直接返回 nil.
// 迭代器这层抽象的引入, 让各个特殊的 sequence 的实现, 变得简单了.
extension PrefixSequence {
    @frozen
    public struct Iterator {
        @usableFromInline
        internal var _base: Base.Iterator
        @usableFromInline
        internal var _remaining: Int
        
        @inlinable
        internal init(_ base: Base.Iterator, maxLength: Int) {
            _base = base
            _remaining = maxLength
        }
    }  
}

extension PrefixSequence.Iterator: IteratorProtocol {
    public typealias Element = Base.Element
    
    // 内部不用去管理 _base 的实现, 在 _base 为空之后, return _base.next() 自然会能够正常的返回值
     
    @inlinable
    public mutating func next() -> Element? {
        if _remaining != 0 {
            _remaining &-= 1
            return _base.next()
        } else {
            return nil
        }
    }  
}

// Prefix 的迭代器, 就是对于 base 迭代器的一层封装而已.
extension PrefixSequence: Sequence {
    @inlinable
    public __consuming func makeIterator() -> Iterator {
        return Iterator(_base.makeIterator(), maxLength: _maxLength)
    }
    
    @inlinable
    public __consuming func prefix(_ maxLength: Int) -> PrefixSequence<Base> {
        let length = Swift.min(maxLength, self._maxLength)
        return PrefixSequence(_base, maxLength: length)
    }
}


@frozen
public struct DropWhileSequence<Base: Sequence> {
    public typealias Element = Base.Element
    
    @usableFromInline
    internal var _iterator: Base.Iterator
    @usableFromInline
    internal var _nextElement: Element?
    
    // 在初始化的时候, 就不断的消耗, 直到 predicate 为真的时候, 才停止消耗的行为.
    @inlinable
    internal init(iterator: Base.Iterator, predicate: (Element) throws -> Bool) rethrows {
        _iterator = iterator
        _nextElement = _iterator.next()
        
        while let x = _nextElement, try predicate(x) {
            _nextElement = _iterator.next()
        }
    }
    
    @inlinable
    internal init(_ base: Base, predicate: (Element) throws -> Bool) rethrows {
        self = try DropWhileSequence(iterator: base.makeIterator(), predicate: predicate)
    }
}

// 这个类的实现思路是, 事先把数据准备好, 然后就是正常的迭代的取值操作了.
// 也可以在 next 里面, 第一次运行时候增加判断. 不过, 这种提前判断, 可以让代码更加的易懂, 因为写在 next 里面, 也势必要用一个 bool 值去记录一下当前的状态, 然后 next 里面根据这个状态, 做不同的操作.
// 这个实现的思路, 和 dropfirst 是一样的, 都是初始化的时候, 提前消耗.
extension DropWhileSequence {
    @frozen
    public struct Iterator {
        @usableFromInline
        internal var _iterator: Base.Iterator
        @usableFromInline
        internal var _nextElement: Element?
        
        @inlinable
        internal init(_ iterator: Base.Iterator, nextElement: Element?) {
            _iterator = iterator
            _nextElement = nextElement
        }
    }
}

extension DropWhileSequence.Iterator: IteratorProtocol {
    public typealias Element = Base.Element
    
    @inlinable
    // next 里面, 就是直接取值返回就可以了, 每次都更新当前值.
    public mutating func next() -> Element? {
        guard let next = _nextElement else { return nil }
        _nextElement = _iterator.next()
        return next
    }
}

extension DropWhileSequence: Sequence {
    @inlinable
    public func makeIterator() -> Iterator {
        return Iterator(_iterator, nextElement: _nextElement)
    }
    
    @inlinable
    public __consuming func drop(
        while predicate: (Element) throws -> Bool
    ) rethrows -> DropWhileSequence<Base> {
        guard let x = _nextElement, try predicate(x) else { return self }
        return try DropWhileSequence(iterator: _iterator, predicate: predicate)
    }
}

// 在 Sequence 的可迭代的基础上, 增加的各种算法, 可以利用一个简单的概念, 编写通用的算法, 这才是面向 protocol 编程的最核心的部分.
extension Sequence {
    // Map 就是, 返回一个数组, 数组里面的数据, 是 transform 变化过的.
    // OC id 就是泛型, Swift 里面的, 类型固定化, 显得根据闭包确定返回值类型很奇怪.
    @inlinable
    public func map<T>(
        _ transform: (Element) throws -> T
    ) rethrows -> [T] {
        // underestimatedCount 这个值, 可以大大减少由于数组扩容导致的性能损耗.
        let initialCapacity = underestimatedCount
        var result = ContiguousArray<T>()
        result.reserveCapacity(initialCapacity)
        
        var iterator = self.makeIterator()
        
        // 这里, iterator.next()! 是直接强制类型解包的. 这样做要快一点点, 因为 while let element = iterator.next()  这个操作, 其实还有一步判断 type 的流程.
        // 标准库就是, 能快一点是一点.
        // 如果是我们自己写的代码, 可能直接就下面的算法了, 因为, 数组的 reserveCapacity 操作, 已经能考虑的性能相关的部分了.
        // 之所以没有想到下面, 还是对于 swift 不够熟悉.
        for _ in 0..<initialCapacity {
            result.append(try transform(iterator.next()!))
        }
        while let element = iterator.next() {
            result.append(try transform(element))
        }
        return Array(result)
    }
    
    @inlinable
    public __consuming func filter(
        _ isIncluded: (Element) throws -> Bool
    ) rethrows -> [Element] {
        return try _filter(isIncluded) // 不太明白, 这里的一层转化有什么目的, 这个函数内部, 并没有任何的其他逻辑.
    }
    
    @_transparent
    public func _filter(
        _ isIncluded: (Element) throws -> Bool
    ) rethrows -> [Element] {
        
        // 这里, 就没有使用 underestimatedCount 做 result 的长度控制.
        // 因为 filter 本身会改变数组的长度
        // 算法很简单, 就是不断的调用 isIncluded 去判断 ele 是不是合法值而已.
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
    @inlinable
    public var underestimatedCount: Int {
        return 0
    }
    
    @inlinable
    @inline(__always)
    // 有没有判断是否 contains 的更好的办法, 在 indexset 里面, 这个返回的是 yes. 因为, 那里面不是一个个遍历判等的
    public func _customContainsEquatableElement(
        _ element: Iterator.Element
    ) -> Bool? {
        return nil
    }
    
    // forEach, 不能 break, continue, return 也仅仅是提前退出 block 而已.
    // 这个使用的也很广.
    @_semantics("sequence.forEach")
    @inlinable
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
    @inlinable
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
    
    /// Returns a subsequence, up to the given maximum length, containing the
    /// final elements of the sequence.
    ///
    /// The sequence must be finite. If the maximum length exceeds the number of
    /// elements in the sequence, the result contains all the elements in the
    /// sequence.
    ///
    ///     let numbers = [1, 2, 3, 4, 5]
    ///     print(numbers.suffix(2))
    ///     // Prints "[4, 5]"
    ///     print(numbers.suffix(10))
    ///     // Prints "[1, 2, 3, 4, 5]"
    ///
    /// - Parameter maxLength: The maximum number of elements to return. The
    ///   value of `maxLength` must be greater than or equal to zero.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the sequence.
    @inlinable
    public __consuming func suffix(_ maxLength: Int) -> [Element] {
        _precondition(maxLength >= 0, "Can't take a suffix of negative length from a sequence")
        guard maxLength != 0 else { return [] }
        
        // FIXME: <rdar://problem/21885650> Create reusable RingBuffer<T>
        // Put incoming elements into a ring buffer to save space. Once all
        // elements are consumed, reorder the ring buffer into a copy and return it.
        // This saves memory for sequences particularly longer than `maxLength`.
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
    
    // DropFirstSequence 是 drop 功能的实际的实现, 但是, 这个类型太复杂了, dropFirst 函数, 直接将内部的逻辑封装到了函数体的内部
    @inlinable
    public __consuming func dropFirst(_ k: Int = 1) -> DropFirstSequence<Self> {
        return DropFirstSequence(self, dropping: k)
    }
    
    //
    @inlinable
    public __consuming func dropLast(_ k: Int = 1) -> [Element] {
        _precondition(k >= 0, "Can't drop a negative number of elements from a sequence")
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
    
    // drop 函数封装了 DropWhileSequence 的实现细节.
    @inlinable
    public __consuming func drop(
        while predicate: (Element) throws -> Bool
    ) rethrows -> DropWhileSequence<Self> {
        return try DropWhileSequence(self, predicate: predicate)
    }
    
    // prefix 函数, 封装了 PrefixSequence 的实现细节.
    @inlinable
    public __consuming func prefix(_ maxLength: Int) -> PrefixSequence<Self> {
        return PrefixSequence(self, maxLength: maxLength)
    }
    
    
    // 可以看到, 如果是要前面的值, 都是直接从前面取值了, 如果是要后面的值, 一般都要一个新的数据结构.
    @inlinable
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
    
    // 把自己, 填充到 buffer 所指向的空间里面, 这是一个很 C 风格的代码, 直接操作了内存.
    @inlinable
    public __consuming func _copyContents(
        initializing buffer: UnsafeMutableBufferPointer<Element>
    ) -> (Iterator,UnsafeMutableBufferPointer<Element>.Index) {
        var it = self.makeIterator()
        guard var ptr = buffer.baseAddress else { return (it,buffer.startIndex) }
        
        for idx in buffer.startIndex..<buffer.count {
            guard let x = it.next() else {
                return (it, idx)
            }
            ptr.initialize(to: x)
            ptr += 1
        }
        return (it,buffer.endIndex)
    }
    
    @inlinable
    public func withContiguousStorageIfAvailable<R>(
        _ body: (UnsafeBufferPointer<Element>) throws -> R
    ) rethrows -> R? {
        return nil
    }  
}

// FIXME(ABI)#182
// Pending <rdar://problem/14011860> and <rdar://problem/14396120>,
// pass an IteratorProtocol through IteratorSequence to give it "Sequence-ness"
/// A sequence built around an iterator of type `Base`.
///
/// Useful mostly to recover the ability to use `for`...`in`,
/// given just an iterator `i`:
///
///     for x in IteratorSequence(i) { ... }
@frozen
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
    /// Advances to the next element and returns it, or `nil` if no next element
    /// exists.
    ///
    /// Once `nil` has been returned, all subsequent calls return `nil`.
    ///
    /// - Precondition: `next()` has not been applied to a copy of `self`
    ///   since the copy was made.
    @inlinable
    public mutating func next() -> Base.Element? {
        return _base.next()
    }
}

/* FIXME: ideally for compatability we would declare
 extension Sequence {
 @available(swift, deprecated: 5, message: "")
 public typealias SubSequence = AnySequence<Element>
 }
 */
