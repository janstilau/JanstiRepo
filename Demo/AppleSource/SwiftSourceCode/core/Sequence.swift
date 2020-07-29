/// A type that supplies the values of a sequence one at a time.
/// 序列, 一次拿一个.
///
/// The `IteratorProtocol` protocol is tightly linked with the `Sequence`
/// protocol. Sequences provide access to their elements by creating an
/// iterator, which keeps track of its iteration process and returns one
/// element at a time as it advances through the sequence.
///
/// Sequence 创建一个迭代器, 然后根据迭代器, 进行元素的访问.
/// 迭代器的内部, 要记录 迭代的过程, 控制迭代按照顺序进行.
/// 传统的迭代器, 会记录一下它所迭代容器, 以及当前迭代的位置.
/// 但是迭代器里面记录什么状态, 比如 Array 只记录索引,  Dict 记录 Node 值, 是不一样的, Swift 的迭代, 变成了只提供 NextObject 这个能力的抽象.
///
/// Whenever you use a `for`-`in` loop with an array, set, or any other
/// collection or sequence, you're using that type's iterator. Swift uses a
/// sequence's or collection's iterator internally to enable the `for`-`in`
/// loop language construct.
///
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
///
/// Behind the scenes, Swift uses the `animals` array's iterator to loop over
/// the contents of the array.
///
///     For in 循环, 就是 while 循环, 和迭代器的综合使用的结果.
///     next 就是 * 操作符, ++ 操作符的结合体.
///     语言就是大号的语法糖的工厂.
///     var animalIterator = animals.makeIterator()
///     while let animal = animalIterator.next() {
///         print(animal)
///     }
///     // Prints "Antelope"
///     // Prints "Butterfly"
///     // Prints "Camel"
///     // Prints "Dolphin"
///
/// The call to `animals.makeIterator()` returns an instance of the array's
/// iterator. Next, the `while` loop calls the iterator's `next()` method
/// repeatedly, binding each element that is returned to `animal` and exiting
/// when the `next()` method returns `nil`.



/// Using Iterators Directly
/// ========================
///
/// idiom 习惯用语, 成语
/// idiomatic 惯用的, 符合语言习惯的.
///
/// You rarely need to use iterators directly, because a `for`-`in` loop is the
/// more idiomatic approach to traversing a sequence in Swift. Some
/// algorithms, however, may call for direct iterator use.
///
/// for in 循环, 就是语言给你进行迭代用的.
/// 语言提供了很多语法糖, for in 循环, 减少了建立迭代器, 获取数据, 迭代器++ 的过程. 所以, 有 for in, 就不要使用迭代器了, 使用迭代器, 和之前的 for 三段式写法没有太大区别
/// 函数式编程里面, 提供了很多的特殊函数. 这些特殊函数, 就是对于迭代过程的封装. 由于 forin 里面, 直接控制了迭代过程, 所以用 forin 无法自定义迭代的控制.
/// 在这些函数里面, 是直接使用了迭代器. 这些函数起到的作用, 和 forin 是一样的, 就是控制逻辑的固化. 然后提供了一个可以自定义的业务点, 这个业务点, 是用闭包的形式, 给与了使用者一个新的扩展点.
///
/// One example is the `reduce1(_:)` method. Similar to the `reduce(_:_:)`
/// method defined in the standard library, which takes an initial value and a
/// combining closure, `reduce1(_:)` uses the first element of the sequence as
/// the initial value.
///
/// Here's an implementation of the `reduce1(_:)` method. The sequence's
/// iterator is used directly to retrieve the initial value before looping
/// over the rest of the sequence.
///
///     extension Sequence {
///         func reduce1(
///             _ nextPartialResult: (Element, Element) -> Element
///         ) -> Element?
///         {
///         // 在 Swift 里面, 多多的使用 guard 函数.
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
/// The `reduce1(_:)` method makes certain kinds of sequence operations
/// simpler. Here's how to find the longest string in a sequence, using the
/// `animals` array introduced earlier as an example:
///     let longestAnimal = animals.reduce1 { current, element in
///         if current.count > element.count {
///             return current
///         } else {
///             return element
///         }
///     }
///     print(longestAnimal)
///     // Prints "Butterfly"



/// Using Multiple Iterators
/// ========================

/// Sequence 不保证, 是可以多次迭代的. 如果你要多次使用, 自己把握.
/// 如果你知道是可以多次迭代的, 或者有把控是 Collection , 因为 Collection 协议保证了是多次可迭代的.
/// Whenever you use multiple iterators (or `for`-`in` loops) over a single
/// sequence, be sure you know that the specific sequence supports repeated
/// iteration, either because you know its concrete type or because the
/// sequence is also constrained to the `Collection` protocol.



// 不要传递迭代器, 传递迭代器本身是安全的, 但是一个迭代器的 next, 可能会改变 Sequence 的状态. 导致其他迭代器执行的时候, 得到的是另外一个值.
// 这会出现在, 佛波那契队列的 sequence 里面. 所以, 除非你特别清楚这个队列的底层实现, 不要假设, 这个队列是稳定的.
// 不过, 从以往的使用来说, 传递迭代器这件事基本没做过.
/// Obtain each separate iterator from separate calls to the sequence's
/// `makeIterator()` method rather than by copying. Copying an iterator is
/// safe, but advancing one copy of an iterator by calling its `next()` method
/// may invalidate other copies of that iterator. `for`-`in` loops are safe in
/// this regard.
///
/// Adding IteratorProtocol Conformance to Your Type
/// ================================================
///
/// Implementing an iterator that conforms to `IteratorProtocol` is simple.
/// Declare a `next()` method that advances one step in the related sequence
/// and returns the current element. When the sequence has been exhausted, the
/// `next()` method returns `nil`.
///
/// For example, consider a custom `Countdown` sequence. You can initialize the
/// `Countdown` sequence with a starting integer and then iterate over the
/// count down to zero. The `Countdown` structure's definition is short: It
/// contains only the starting count and the `makeIterator()` method required
/// by the `Sequence` protocol.
///
/// 每个  Sequence 所能够获取的 Iterator, 都是和这个 Sequence 相关的. 可以说, 就是它的内部类.
///  序列, 更多的是一个可遍历的概念, 而容器, 则是进行存储的状态的场所.
///  获取当前值, 是迭代器的功能, 这个功能可以是从容器中获取值, 也可以是迭代器算出来的.
///
///     struct Countdown: Sequence {
///         let start: Int
///
///
///         func makeIterator() -> CountdownIterator {
///             return CountdownIterator(self)
///         }
///     }
///
/// The `makeIterator()` method returns another custom type, an iterator named
/// `CountdownIterator`. The `CountdownIterator` type keeps track of both the
/// `Countdown` sequence that it's iterating and the number of times it has
/// returned a value.
///
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
///             guard nextNumber > 0 // 大量大量地去使用 guard 函数, 在 swift 中.
///                 else { return nil }
///
///             times += 1
///             return nextNumber
///         }
///     }
///
/// Each time the `next()` method is called on a `CountdownIterator` instance,
/// it calculates the new next value, checks to see whether it has reached
/// zero, and then returns either the number, or `nil` if the iterator is
/// finished returning elements of the sequence.
///
/// Creating and iterating over a `Countdown` sequence uses a
/// `CountdownIterator` to handle the iteration.
///
///     let threeTwoOne = Countdown(start: 3)
///     for count in threeTwoOne {
///         print("\(count)...")
///     }
///     // Prints "3..."
///     // Prints "2..."
///     // Prints "1..."

/*
 associatedtype, 其实就是协议里面的泛型而已.
 */
public protocol IteratorProtocol {
    /// The type of element traversed by the iterator.
    associatedtype Element
    
    /// Advances to the next element and returns it, or `nil` if no next element
    /// exists.
    ///
    /// Repeatedly calling this method returns, in order, all the elements of the
    /// underlying sequence. As soon as the sequence has run out of elements, all
    /// subsequent calls return `nil`.
    ///
    /// You must not call this method if any other copy of this iterator has been
    /// advanced with a call to its `next()` method.
    /// 这里是怕,  copied iterator 的 next, 将序列的状态进行了消耗.
    ///
    /// The following example shows how an iterator can be used explicitly to
    /// emulate a `for`-`in` loop. First, retrieve a sequence's iterator, and
    /// then call the iterator's `next()` method until it returns `nil`.
    ///
    ///     let numbers = [2, 3, 5, 7]
    ///     var numbersIterator = numbers.makeIterator()
    ///
    ///     while let num = numbersIterator.next() {
    ///         print(num)
    ///     }
    ///     // Prints "2"
    ///     // Prints "3"
    ///     // Prints "5"
    ///     // Prints "7"
    ///
    /// - Returns: The next element in the underlying sequence, if a next element
    ///   exists; otherwise, `nil`.
    ///
    /// 这里标注 mutating, 是因为, 对于大部分的迭代器来说, 还是要在内部存储一下迭代的状态的.
    mutating func next() -> Element?
}

/// A type that provides sequential, iterated access to its elements.
///
/// A sequence is a list of values that you can step through one at a time. The
/// most common way to iterate over the elements of a sequence is to use a
/// `for`-`in` loop:
///
///     let oneTwoThree = 1...3
///     for number in oneTwoThree {
///         print(number)
///     }
///     // Prints "1"
///     // Prints "2"
///     // Prints "3"
///
/// 这里说的很清楚了, 这就是一个 primitiveMethod.
/// 很多的方法, 都是建立在这个基本方法之上的.
///
/// 这些方法, 提供了通用的逻辑, 然后提供了可以变化的参数, 一般来说是一个 Block.
///  通过这个 Block, 可以做业务上的变化.
///  Protocol 这种设计的方式, 将方法, 操作的能力, 抽象到了一个类中. 其他的类, 通过实现这个类的基本方法, 自动的继承了那些高级能力. 这个过程是自适应的.
///
/// While seemingly simple, this capability gives you access to a large number
/// of operations that you can perform on any sequence. As an example, to
/// check whether a sequence includes a particular value, you can test each
/// value sequentially until you've found a match or reached the end of the
/// sequence. This example checks to see whether a particular insect is in an
/// array.
///
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
/// The `Sequence` protocol provides default implementations for many common
/// operations that depend on sequential access to a sequence's values. For
/// clearer, more concise code, the example above could use the array's
/// `contains(_:)` method, which every sequence inherits from `Sequence`,
/// instead of iterating manually:
///
///     if bugs.contains("Mosquito") {
///         print("Break out the bug spray.")
///     } else {
///         print("Whew, no mosquitos!")
///     }
///     // Prints "Whew, no mosquitos!"
///
///
///
/// Repeated Access 不保证.
/// ===============
///
/// The `Sequence` protocol makes no requirement on conforming types regarding
/// whether they will be destructively consumed by iteration. As a
/// consequence, don't assume that multiple `for`-`in` loops on a sequence
/// will either resume iteration or restart from the beginning:
///
///     for element in sequence {
///         if ... some condition { break }
///     }
///
///     for element in sequence {
///         // No defined behavior
///     }
///
/// In this case, you cannot assume either that
/// a sequence will be consumable and will resume iteration, or that
/// a sequence is a collection and will restart iteration from the first element
///  A conforming sequence that is
/// not a collection is allowed to produce an arbitrary sequence of elements
/// in the second `for`-`in` loop.
///
/// To establish that a type you've created supports nondestructive iteration,
/// add conformance to the `Collection` protocol.
///
///
///
///
/// Conforming to the Sequence Protocol
/// ===================================
///
/// Making your own custom types conform to `Sequence` enables many useful
/// operations, like `for`-`in` looping and the `contains` method, without
/// much effort. To add `Sequence` conformance to your own custom type, add a
/// `makeIterator()` method that returns an iterator.
///
/// Alternatively, if your type can act as its own iterator, implementing the
/// requirements of the `IteratorProtocol` protocol and declaring conformance
/// to both `Sequence` and `IteratorProtocol` are sufficient.
///
///
/// 只要某个类, next() 方法实现了, 那么它就可以迭代自己. 默认的 makeIterator 的实现, 就是返回自己.
///
/// Here's a definition of a `Countdown` sequence that serves as its own
/// iterator. The `makeIterator()` method is provided as a default
/// implementation.
///
///     struct Countdown: Sequence, IteratorProtocol {
///         var count: Int
///
///         mutating func next() -> Int? {
///             if count == 0 {
///                 return nil
///             } else {
///                 defer { count -= 1 } // 这里使用了 defer 这种语法, 用对象控制资源来解释.
///                 return count
///             }
///         }
///     }
///
///     let threeToGo = Countdown(count: 3)
///     for i in threeToGo {
///         print(i)
///     }
///     // Prints "3"
///     // Prints "2"
///     // Prints "1"
///
/// Expected Performance
/// ====================
///
/// A sequence should provide its iterator in O(1). The `Sequence` protocol
/// makes no other requirements about element access, so routines that
/// traverse a sequence should be considered O(*n*) unless documented
/// otherwise.
public protocol Sequence {
    /// A type representing the sequence's elements.
    associatedtype Element
    
    /// A type that provides the sequence's iteration interface and
    /// encapsulates its iteration state.
    /// encapsulates its iteration state 这个就表明了, iterator 是要进行状态的保存的.
    associatedtype Iterator: IteratorProtocol where Iterator.Element == Element
    
    /// Returns an iterator over the elements of this sequence.
    func makeIterator() -> Iterator
    
    /// A value less than or equal to the number of elements in the sequence,
    /// calculated nondestructively.
    ///
    /// The default implementation returns 0. If you provide your own
    /// implementation, make sure to compute the value nondestructively.
    ///
    /// - Complexity: O(1), except if the sequence also conforms to `Collection`.
    ///   In this case, see the documentation of `Collection.underestimatedCount`.
    ///
    /// 这个值, 做了一个提升效率的值, 来进行容器的初始化操作.
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
/// 在泛型函数的书写时, 任何限制, 都是建立在类型的基础上, 而不是对象保存的值的基础上.
extension Sequence where Self.Iterator == Self {
    /// Returns an iterator over the elements of this sequence.
    @inlinable
    public __consuming func makeIterator() -> Self {
        return self
    }
}

/// A sequence that lazily consumes and drops `n` elements from an underlying
/// `Base` iterator before possibly returning the first available element.
///
/// The underlying iterator's sequence may be infinite.
/*
 一个 sequence 的适配器.
 */
@frozen
public struct DropFirstSequence<Base: Sequence> {
    @usableFromInline
    internal let _base: Base // 适配器, 保存原始的对象.
    @usableFromInline
    internal let _limit: Int // 适配器中, 自己业务逻辑需要存储的值.
    
    @inlinable
    public init(_ base: Base, dropping limit: Int) {
        _precondition(limit >= 0,
                      "Can't drop a negative number of elements from a sequence")
        _base = base
        _limit = limit
    }
}

/*
 并不是, 这些包装类进行了延迟计算的功能, 本身迭代就是一个延迟计算的东西.
 就算是容器取值, 他也是在需要时才进行取值, 而不是生成迭代器, 就把所有的值都取了出来.
 如果, base 是一个数组, 当然可以直接 +n. 但是, 作为 sequence 来说, 他并不能确认自己能够 randomAccess, 所以这里就是循环进行.
 */
extension DropFirstSequence: Sequence {
    public typealias Element = Base.Element
    public typealias Iterator = Base.Iterator
    public typealias SubSequence = AnySequence<Element>
    
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

/// A sequence that only consumes up to `n` elements from an underlying
/// `Base` iterator.
///
/// The underlying iterator's sequence may be infinite.
/*
 这里, 只是这个类的定义. 它实现的功能, 要在 extension 里面.
 */
@frozen
public struct PrefixSequence<Base: Sequence> {
    @usableFromInline
    internal var _base: Base
    @usableFromInline
    internal let _maxLength: Int
    
    @inlinable
    public init(_ base: Base, maxLength: Int) {
        _base = base
        _maxLength = maxLength
    }
}

/*
 它的 Iterator, 也仅仅是做值的拷贝工作.
 这应该算是 baseIterator 的代理类.
 和他相关的类型的定义, 也没有方法最原始的定义区域里面, 而是放到了 extension 里面.
 _maxLength 的值, 是存在 prefixSequence 里面的, 但是过程值, 是存在各个 Iterator 的 _remaining 里面的.
 */
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
/*
 PrefixSequence.Iterator 的定义, 和他实现 IteratorProtocol 的方法实现, 分开了.
 这里, 只要是类型, 符合一个协议, 在 Swift 里面, 都是用的扩展的方式完成的.
 虽然 Iterator 仅仅有一个协议, 这个协议只有一个方法, 但是还是进行了分离.
 */
extension PrefixSequence.Iterator: IteratorProtocol {
    public typealias Element = Base.Element
    
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

extension PrefixSequence: Sequence {
    @inlinable
    
    public __consuming func makeIterator() -> Iterator {
        return Iterator(_base.makeIterator(), maxLength: _maxLength)
    }
    
    /*
     这里, 在自己的基础上, 返回了个 PrefixSequence, 就是将 base 和 新生成的 length 传入进入.
    */
    @inlinable
    public __consuming func prefix(_ maxLength: Int) -> PrefixSequence<Base> {
        let length = Swift.min(maxLength, self._maxLength)
        return PrefixSequence(_base, maxLength: length)
    }
}

/*
 既然, 知道了实现原理, 就可以通过对于这些原理的利用, 做出自己想要的东西. 所以, 知其所以然来说, 还是很重要的.
 */

/// A sequence that lazily consumes and drops `n` elements from an underlying
/// `Base` iterator before possibly returning the first available element.
///
/// The underlying iterator's sequence may be infinite.
@frozen
public struct DropWhileSequence<Base: Sequence> {
    public typealias Element = Base.Element
    
    @usableFromInline
    internal var _iterator: Base.Iterator
    @usableFromInline
    internal var _nextElement: Element?
    
    /*
     在初始化方法里面, 就对 Sequence 里面的值, 进行一次过滤的操作, 直到最终到达一个符合 predicate 的点.
     */
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
    public func drop(
        while predicate: (Element) throws -> Bool
    ) rethrows -> DropWhileSequence<Base> {
        guard let x = _nextElement, try predicate(x) else { return self }
        return try DropWhileSequence(iterator: _iterator, predicate: predicate)
    }
}

//===----------------------------------------------------------------------===//
// Default implementations for Sequence
//===----------------------------------------------------------------------===//

/*
 下面, 所有的 Sequence 的 extension, 都是根据 Sequence 提供的可迭代的能力, 封装了相关功能的通用逻辑, 提出了业务变化点.
 使用这些方法的时候, 一定要是在这些方法对应的场景下.
 
 比如, 使用 map, 其实也能够达到 forEach 的功能. 但是, map 的实际效果, 是返回一个包含所有变化闭包结果的数组, 而不是仅仅是做某些操作.
 熟知每个方法的内部实现, 使用对应名称的方法, 能够使得代码更加的觉有自解释性.
 尽量使用, 符合业务功能含义的方法. 而不是能够实现功能, 使用了错误的方法.
 */
extension Sequence {
    /// Returns an array containing the results of mapping the given closure
    /// over the sequence's elements.
    ///
    /// In this example, `map` is used first to convert the names in the array
    /// to lowercase strings and then to count their characters.
    ///
    ///     let cast = ["Vivien", "Marlon", "Kim", "Karl"]
    ///     let lowercaseNames = cast.map { $0.lowercased() }
    ///     // 'lowercaseNames' == ["vivien", "marlon", "kim", "karl"]
    ///     let letterCounts = cast.map { $0.count }
    ///     // 'letterCounts' == [6, 6, 3, 4]
    ///
    /// - Parameter transform: A mapping closure. `transform` accepts an
    ///   element of this sequence as its parameter and returns a transformed
    ///   value of the same or of a different type.
    /// - Returns: An array containing the transformed elements of this
    ///   sequence.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the sequence.
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
         */
        return Array(result)
    }
    
    /// Returns an array containing, in order, the elements of the sequence
    /// that satisfy the given predicate.
    ///
    /// In this example, `filter(_:)` is used to include only names shorter than
    /// five characters.
    ///
    ///     let cast = ["Vivien", "Marlon", "Kim", "Karl"]
    ///     let shortNames = cast.filter { $0.count < 5 }
    ///     print(shortNames)
    ///     // Prints "["Kim", "Karl"]"
    ///
    /// - Parameter isIncluded: A closure that takes an element of the
    ///   sequence as its argument and returns a Boolean value indicating
    ///   whether the element should be included in the returned array.
    /// - Returns: An array of the elements that `isIncluded` allowed.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the sequence.
    @inlinable
    public __consuming func filter(
        _ isIncluded: (Element) throws -> Bool
    ) rethrows -> [Element] {
        return try _filter(isIncluded)
    }
    
    @_transparent
    public func _filter(
        _ isIncluded: (Element) throws -> Bool
    ) rethrows -> [Element] {
        
        var result = ContiguousArray<Element>()
        
        var iterator = self.makeIterator()
        
        while let element = iterator.next() {
            if try isIncluded(element) {
                result.append(element)
            }
        }
        
        return Array(result)
    }
    
    /// A value less than or equal to the number of elements in the sequence,
    /// calculated nondestructively.
    /// 这里写的很明确了, 必须是等于或者小于自己的个数, 所以上面直接 transform(iterator.next()!) 使用了. 如果返回值超过了自己的个数, 那是实现者的责任. 没有按照接口定义的含义来实现.
    /// The default implementation returns 0. If you provide your own
    /// implementation, make sure to compute the value nondestructively.
    ///
    ///  这是一个帮助提升效率的值, 所以, 应该是 O1
    /// - Complexity: O(1), except if the sequence also conforms to `Collection`.
    ///   In this case, see the documentation of `Collection.underestimatedCount`.
    @inlinable
    public var underestimatedCount: Int {
        return 0
    }
    
    @inlinable
    @inline(__always)
    public func _customContainsEquatableElement(
        _ element: Iterator.Element
    ) -> Bool? {
        return nil
    }
    
    /// Calls the given closure on each element in the sequence in the same order
    /// as a `for`-`in` loop.
    ///
    /// The two loops in the following example produce the same output:
    ///
    ///     let numberWords = ["one", "two", "three"]
    ///     for word in numberWords {
    ///         print(word)
    ///     }
    ///     // Prints "one"
    ///     // Prints "two"
    ///     // Prints "three"
    ///
    ///     numberWords.forEach { word in
    ///         print(word)
    ///     }
    ///     // Same as above
    ///
    /// Using the `forEach` method is distinct from a `for`-`in` loop in two
    /// important ways:
    ///
    /// 1. You cannot use a `break` or `continue` statement to exit the current
    ///    call of the `body` closure or skip subsequent calls.
    /// 2. Using the `return` statement in the `body` closure will exit only from
    ///    the current call to `body`, not from any outer scope, and won't skip
    ///    subsequent calls.
    ///
    /// - Parameter body: A closure that takes an element of the sequence as a
    ///   parameter.
    /// for Each 使用的很少, 相比 forin, 他没有停止的刹车机制.
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
    /// Returns the first element of the sequence that satisfies the given
    /// predicate.
    ///
    /// The following example uses the `first(where:)` method to find the first
    /// negative number in an array of integers:
    ///
    ///     let numbers = [3, 7, 4, -2, 9, -6, 10, 1]
    ///     if let firstNegative = numbers.first(where: { $0 < 0 }) {
    ///         print("The first negative number is \(firstNegative).")
    ///     }
    ///     // Prints "The first negative number is -2."
    ///
    /// - Parameter predicate: A closure that takes an element of the sequence as
    ///   its argument and returns a Boolean value indicating whether the
    ///   element is a match.
    /// - Returns: The first element of the sequence that satisfies `predicate`,
    ///   or `nil` if there is no element that satisfies `predicate`.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the sequence.
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

extension Sequence {
    
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
        
        var ringBuffer = ContiguousArray<Element>()
        ringBuffer.reserveCapacity(Swift.min(maxLength, underestimatedCount))
        
        var i = 0
        
        // 这里, 是全部都装了一次, 满了就进行替换工作.
        for element in self {
            if ringBuffer.count < maxLength {
                ringBuffer.append(element)
            } else {
                ringBuffer[i] = element
                i = (i + 1) % maxLength
            }
        }
        // 到最后, ringBuffer 里面的, 一定是要留下来的数据, 只不过可能 i 在中间位置. 要做一次前后两个片段的顺序调整的工作.
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
    
    /*
     上面的 suffix 其实就暴露出, 通过 primitive 来实现所有功能的性能损失.
     如果是数组, 那么可以直接通过下标取得后面的数据, 时间复杂度为 0(1), 而用通用的基本方法, 只能是全部获取之后, 再去获取最后的数据.
     因为 Sequence 是没有 count 的, 所以还不能在遍历的过程中, 到达了某个点再去记录, 就要记录所有的值, 然后调整顺序.
     使用通用算法, 会带来性能的损失.
     这里方法, 在 Collection 里面, 进行了重写. 用了更加有效率的 Index 进行的整体替换.
     */
    
    /// Returns a sequence containing all but the given number of initial
    /// elements.
    ///
    /// If the number of elements to drop exceeds the number of elements in
    /// the sequence, the result is an empty sequence.
    ///
    ///     let numbers = [1, 2, 3, 4, 5]
    ///     print(numbers.dropFirst(2))
    ///     // Prints "[3, 4, 5]"
    ///     print(numbers.dropFirst(10))
    ///     // Prints "[]"
    ///
    /// - Parameter k: The number of elements to drop from the beginning of
    ///   the sequence. `k` must be greater than or equal to zero.
    /// - Returns: A sequence starting after the specified number of
    ///   elements.
    ///
    /// - Complexity: O(1), with O(*k*) deferred to each iteration of the result,
    ///   where *k* is the number of elements to drop from the beginning of
    ///   the sequence.
    /*
     这里, 返回了一个包装对象.
     */
    @inlinable
    public __consuming func dropFirst(_ k: Int = 1) -> DropFirstSequence<Self> {
        return DropFirstSequence(self, dropping: k)
    }
    
    /// Returns a sequence containing all but the given number of final
    /// elements.
    ///
    /// The sequence must be finite. If the number of elements to drop exceeds
    /// the number of elements in the sequence, the result is an empty
    /// sequence.
    ///
    ///     let numbers = [1, 2, 3, 4, 5]
    ///     print(numbers.dropLast(2))
    ///     // Prints "[1, 2, 3]"
    ///     print(numbers.dropLast(10))
    ///     // Prints "[]"
    ///
    /// - Parameter n: The number of elements to drop off the end of the
    ///   sequence. `n` must be greater than or equal to zero.
    /// - Returns: A sequence leaving off the specified number of elements.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the sequence.
    @inlinable
    public __consuming func dropLast(_ k: Int = 1) -> [Element] {
        guard k != 0 else { return Array(self) }
        
        // FIXME: <rdar://problem/21885650> Create reusable RingBuffer<T>
        // Put incoming elements from this sequence in a holding tank, a ring buffer
        // of size <= k. If more elements keep coming in, pull them out of the
        // holding tank into the result, an `Array`. This saves
        // `k` * sizeof(Element) of memory, because slices keep the entire
        // memory of an `Array` alive.
        var result = ContiguousArray<Element>()
        var ringBuffer = ContiguousArray<Element>()
        var i = ringBuffer.startIndex
        
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
    
    /// Returns a sequence by skipping the initial, consecutive elements that
    /// satisfy the given predicate.
    ///
    /// The following example uses the `drop(while:)` method to skip over the
    /// positive numbers at the beginning of the `numbers` array. The result
    /// begins with the first element of `numbers` that does not satisfy
    /// `predicate`.
    ///
    ///     let numbers = [3, 7, 4, -2, 9, -6, 10, 1]
    ///     let startingWithNegative = numbers.drop(while: { $0 > 0 })
    ///     // startingWithNegative == [-2, 9, -6, 10, 1]
    ///
    /// If `predicate` matches every element in the sequence, the result is an
    /// empty sequence.
    ///
    /// - Parameter predicate: A closure that takes an element of the sequence as
    ///   its argument and returns a Boolean value indicating whether the
    ///   element should be included in the result.
    /// - Returns: A sequence starting after the initial, consecutive elements
    ///   that satisfy `predicate`.
    ///
    /// - Complexity: O(*k*), where *k* is the number of elements to drop from
    ///   the beginning of the sequence.
    @inlinable
    public __consuming func drop(
        while predicate: (Element) throws -> Bool
    ) rethrows -> DropWhileSequence<Self> {
        return try DropWhileSequence(self, predicate: predicate)
    }
    
    /// Returns a sequence, up to the specified maximum length, containing the
    /// initial elements of the sequence.
    ///
    /// If the maximum length exceeds the number of elements in the sequence,
    /// the result contains all the elements in the sequence.
    ///
    ///     let numbers = [1, 2, 3, 4, 5]
    ///     print(numbers.prefix(2))
    ///     // Prints "[1, 2]"
    ///     print(numbers.prefix(10))
    ///     // Prints "[1, 2, 3, 4, 5]"
    ///
    /// - Parameter maxLength: The maximum number of elements to return. The
    ///   value of `maxLength` must be greater than or equal to zero.
    /// - Returns: A sequence starting at the beginning of this sequence
    ///   with at most `maxLength` elements.
    ///
    /// - Complexity: O(1)
    @inlinable
    public __consuming func prefix(_ maxLength: Int) -> PrefixSequence<Self> {
        return PrefixSequence(self, maxLength: maxLength)
    }
    
    /// Returns a sequence containing the initial, consecutive elements that
    /// satisfy the given predicate.
    ///
    /// The following example uses the `prefix(while:)` method to find the
    /// positive numbers at the beginning of the `numbers` array. Every element
    /// of `numbers` up to, but not including, the first negative value is
    /// included in the result.
    ///
    ///     let numbers = [3, 7, 4, -2, 9, -6, 10, 1]
    ///     let positivePrefix = numbers.prefix(while: { $0 > 0 })
    ///     // positivePrefix == [3, 7, 4]
    ///
    /// If `predicate` matches every element in the sequence, the resulting
    /// sequence contains every element of the sequence.
    ///
    /// - Parameter predicate: A closure that takes an element of the sequence as
    ///   its argument and returns a Boolean value indicating whether the
    ///   element should be included in the result.
    /// - Returns: A sequence of the initial, consecutive elements that
    ///   satisfy `predicate`.
    ///
    /// - Complexity: O(*k*), where *k* is the length of the result.
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
    /// Copies `self` into the supplied buffer.
    ///
    /// - Precondition: The memory in `self` is uninitialized. The buffer must
    ///   contain sufficient uninitialized memory to accommodate `source.underestimatedCount`.
    ///
    /// - Postcondition: The `Pointee`s at `buffer[startIndex..<returned index]` are
    ///   initialized.
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



/*
 虽然注释很多, 但是就是调用 Array 已经包装好的方法而已.
 */
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
        let whole = Array(self)// 首先, 利用自己生成一个 Array. 这里我有点疑问, 如果这个 Sequence 是无限的怎么办.
        return try whole.split(
            maxSplits: maxSplits,
            omittingEmptySubsequences: omittingEmptySubsequences,
            whereSeparator: isSeparator)
    }
}
