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
///     For in 循环, 就是 while 循环, 和迭代器的综合使用的结果.
///     next 就是 * 操作符, ++ 操作符的结合体.
///     语言就是大号的语法糖的工厂.
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


/// Using Multiple Iterators
/// ========================

/// Sequence 不保证, 是可以多次迭代的. 如果你要多次使用, 自己把握.
/// 如果你知道是可以多次迭代的, 或者可以确定操作的对象是 Collection , 因为 Collection 协议保证了是多次可迭代的.
/// Whenever you use multiple iterators (or `for`-`in` loops) over a single
/// sequence, be sure you know that the specific sequence supports repeated
/// iteration, either because you know its concrete type or because the
/// sequence is also constrained to the `Collection` protocol.



// 不要传递迭代器, 传递迭代器本身是安全的, 但是一个迭代器的 next, 可能会改变 Sequence 的状态. 导致其他迭代器执行的时候, 得到的是另外一个值.
// 不过, 从以往的使用来说, 传递迭代器这件事基本没做过.

/// Obtain each separate iterator from separate calls to the sequence's
/// `makeIterator()` method rather than by copying. Copying an iterator is
/// safe, but advancing one copy of an iterator by calling its `next()` method
/// may invalidate other copies of that iterator. `for`-`in` loops are safe in
/// this regard.
///
/// Adding IteratorProtocol Conformance to Your Type
/// ================================================
/// 基本上来说, 如果你要提供一个特殊的序列, 那么就要提供一下与之相配对的迭代器. 然后, 把取值的逻辑, 放到这个迭代器类中.
///  每个  Sequence 所能够获取的 Iterator, 都是和这个 Sequence 相关的. 可以说, 就是它的内部类.
///  序列, 更多的是一个可遍历的概念, 而容器, 则是进行存储的状态的场所.
///  获取当前值, 是迭代器的功能, 这个功能可以是从容器中获取值, 也可以是迭代器算出来的.
/// Implementing an iterator that conforms to `IteratorProtocol` is simple.
/// Declare a `next()` method that advances one step in the related sequence
/// and returns the current element. When the sequence has been exhausted, the
/// `next()` method returns `nil`.

/*
 associatedtype, 其实就是协议里面的泛型而已.
 */
public protocol IteratorProtocol {
    /// The type of element traversed by the iterator.
    associatedtype Element
    
    /// mutating, 是因为, 对于大部分的迭代器来说, 还是要在内部存储一下迭代的状态的
    /// 这个方法, 是可以重复使用的, 只不过在 exhaust 之后, 一直返回 nil 了就. 所以, iterator 内部, 一定要记录好, 是不是已经到头了.
    mutating func next() -> Element?
}

/// Squence 的概念很简单, 就是可以迭代取值的一个抽象对象. 这个值, 如何得到, 是在容器里面, 还是动态生成的, 他不管.
///
/// 这里说的很清楚了, 这就是一个 primitiveMethod.
/// 很多的方法, 都是建立在这个基本方法之上的.
///
///  这些方法, 提供了通用的逻辑, 然后提供了可以变化的参数, 一般来说是一个 Block.
///  通过这个 Block, 可以做业务上的变化.
///  Protocol 这种设计的方式, 将方法, 操作的能力, 抽象到了一个类中.
///  其他的类, 通过实现这个类的基本方法, 自动的继承了那些高级能力. 这个过程是自适应的.
///  这是一种非常高级的, 可以做到代码复用的能力. 不过, 会让整个系统类库变得很复杂.
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
/// Repeated Access 不保证. 不过, 平时使用的还是容器, 对于容器 Collection 来说, 可重复遍历是标配.
/// ===============
///
/// Conforming to the Sequence Protocol 对于一个序列来说, 一定要实现对应的 iterator. 真正的取值, 是放在 iterator 里面的. Iterator, 通过序列提供的方法, 进行取值操作, 然后将值进行进一步的处理.
/// ===================================
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
public protocol Sequence {
    associatedtype Element
    /// 迭代器类型的 Element 要和 Sequence 的一致, 也就是在泛型里面, 增加了限制.
    associatedtype Iterator: IteratorProtocol where Iterator.Element == Element
    
    /// 最重要的方法, 返回一个迭代器, 在迭代器中, 进行取值操作和状态管理.
    func makeIterator() -> Iterator
    
    /// - Complexity: O(1), except if the sequence also conforms to `Collection`.
    ///   In this case, see the documentation of `Collection.underestimatedCount`.
    ///
    /// 这个值, 目前只用在了容器的初始化操作里了. 容器要存放 sequence 里面的值, 可能会有扩容的处理. 提前进行 bucket 的分配, 可以大大减少搬移数据的次数.
    var underestimatedCount: Int { get }
    
    /*
     这个也是为了提升效率的. Contains 的逻辑, 是从头到尾遍历然后判断相等.
     但是如果实现类, 有着快速的版本判断, 就重写该方法. 比如, set, dict, range, 都是能在 O(1) 中实现判断的.
     contains 首先判断该函数, 如果不能确定结果, 在会去走 contains 的默认实现.
     contains 可以算作是, 模板方法, 该函数, 就是模板方法的切口.
     */
    func _customContainsEquatableElement(
        _ element: Element
    ) -> Bool?
    
    /*
     ContiguousArray 可以认为是 Swift 版本的数组的主要版本.
     基本上, Sequence 作为一个序列的概念, 变换为数组, 是很常见的事情.
     */
    __consuming func _copyToContiguousArray() -> ContiguousArray<Element>
    
    /*
     这个函数, 是一个比较底层的函数, 一般系统类库才会使用.
     首先要提前分配出一块物理空间来, 然后将 Sequence 里面的值, 搬到该空间上.
     */
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

extension Sequence where Self: IteratorProtocol {
    public typealias _Default_Iterator = Self
}

/*
 如果, Seuqnce 的内部, 实现了 next 方法, 那么自己就可以充当迭代器.
 不建议这样, 因为迭代的状态, 是需要管理的, 如果 sequence 自己管理, 多次迭代之间, 把这个值重置下.
 还是单独一个对象, 进行单次迭代的管理, 比较好操作.
 */
extension Sequence where Self.Iterator == Self {
    /// Returns an iterator over the elements of this sequence.
    @inlinable
    public __consuming func makeIterator() -> Self {
        return self
    }
}

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
 一个类, 它的自己的定义, 放在一个区块里面.
 它对于协议的适配, 放到另外一个区块里面, 让代码清晰了不少.
 配置 Swift 的访问权限控制, 让代码更好维护.
 */

/*
 并不是, 这些包装类进行了延迟计算的功能, 本身迭代就是一个延迟计算的东西.
 就算是容器取值, 他也是在需要时才进行取值, 而不是生成迭代器, 就把所有的值都取了出来.
 如果, base 是一个数组, 当然可以直接 +n. 但是, 作为 sequence 来说, 他并不能确认自己能够 randomAccess, 所以这里就是循环进行.
 */
extension DropFirstSequence: Sequence {
    public typealias Element = Base.Element
    public typealias Iterator = Base.Iterator
    public typealias SubSequence = AnySequence<Element>
    
    /*
     为什么不把这个过程, 放到 iterator 内部呢.
     当然, 这个类没有专门定义一个 DropFirstIterater. 不过, 其他的几个实现过程, 都是这样做的, 统一下其实比较好.
     */
    @inlinable
    public __consuming func makeIterator() -> Iterator {
        var it = _base.makeIterator()
        var dropped = 0
        while dropped < _limit, it.next() != nil { dropped &+= 1 }
        return it
    }
    
    /*
     如果, 一个 dropSequence 还想继续 drop, 仅仅是一个值的相加而已. 没有任何的数据的搬移工作.
     */
    @inlinable
    public __consuming func dropFirst(_ k: Int) -> DropFirstSequence<Base> {
        return DropFirstSequence(_base, dropping: _limit + k)
    }
}

/*
Sequence 仅仅做的是, 相关值的记录, 然后把相关的值, 传递到自己的 Iterator 里面.
迭代过程的数值, 都记录在 Iterator 的内部. 这样, 多次迭代, 也就没有问题了.
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
 PrefixSequence 的内部类 Iterator 的定义, 和对于 IteratorProtocol 的实现, 都是分开的. 是不是有点太过于繁琐了.
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

/*
 PrefixSequence 对于 Sequence 的实现
 */
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





/*
 Returns a sequence by skipping the initial, consecutive elements that satisfy the given predicate.
 既然这个类, 都已经有了自己的 iterator 了, 感觉还是应该把前期过滤的事情, 放到自己的 iterator 的 next 方法里面.
 */
@frozen
public struct DropWhileSequence<Base: Sequence> {
    public typealias Element = Base.Element
    
    @usableFromInline
    internal var _iterator: Base.Iterator
    @usableFromInline
    internal var _nextElement: Element?
    
    @inlinable
    internal init(iterator: Base.Iterator, predicate: (Element) throws -> Bool) rethrows {
        _iterator = iterator
        _nextElement = _iterator.next()
        // predicate 是 throws 的, 那么调用的时候, 就要增加上 try.
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

/*
 Sequence 的一些工具方法. 在平常, 要大量使用这些工具方法.
 一定要多多使用这些方法. 因为
 1. 这种写法, 是现在非常流行的写法
 2. 代码更加整洁
 3. 减少了出错的可能, 在熟知各个方法的内部逻辑后, 基本上, 不用在考虑那些胶水函数了.
 */

/*
 下面, 所有的 Sequence 的 extension, 都是根据 Sequence 提供的可迭代的能力, 封装了相关功能的通用逻辑, 提出了业务变化点.
 使用这些方法的时候, 一定要是在这些方法对应的场景下.
 熟知每个方法的内部实现, 使用对应名称的方法, 能够使得代码更加的觉有自解释性.
 尽量使用, 符合业务功能含义的方法. 而不是能够实现功能, 使用了错误的方法.
 */
extension Sequence {
    /*
     返回一个数组, 将各个元组通过 transform 处理之后, 添加到这个数组内部.
     */
    @inlinable
    public func map<T>(
        _ transform: (Element) throws -> T
    ) rethrows -> [T] {
        // 这里, 及时利用了 underestimatedCount, 进行了一个效率的提升.
        let initialCapacity = underestimatedCount
        var result = ContiguousArray<T>()
        result.reserveCapacity(initialCapacity) // 扩容.
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
         Array 通过 ContiguousArray 进行初始化非常快, 因为 Array 内部的存储, 就是利用的 ContiguousArray.
         */
        return Array(result)
    }
    
    @inlinable
    public __consuming func filter(
        _ isIncluded: (Element) throws -> Bool
    ) rethrows -> [Element] {
        return try _filter(isIncluded)
    }
    
    /*
     只返回符合 isIncluded 的 element.
     注意, 这里返回去的, 如果 element 是值语义的, 是会有值的拷贝的.
     */
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
    
    /*
     这个值, 用于提升效率, 容器一般都知道自己的容量, 普通的 sequence, 返回 0.
     */
    @inlinable
    public var underestimatedCount: Int {
        return 0
    }
    
    /*
     如果, 实现类有着更加快速的 contains 寻找方式, 比如哈希表, 排序数组, 那么就重载这个方法.
     否则, sequence 的 contains, 是迭代判断相等进行查找的.
     */
    @inlinable
    @inline(__always)
    public func _customContainsEquatableElement(
        _ element: Iterator.Element
    ) -> Bool? {
        return nil
    }
    
    /*
     迭代, 每个进行 body 的调用.
     这个方法, 使用的频率比较低, 因为没有办法停下来. 使用 forin 是同样的效果, 还有更多的操作空间.
     */
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
    @inlinable
    /*
     返回第一个满足条件的 element, 因为可能不存在, 返回值是 optional
     */
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
    
    /*
     返回序列的后面几个值, 装到数组中.
     下面试 Collection 的定义. Collection 会利用自己的 subscript, 进行更快速的实现.
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
     */
    @inlinable
    public __consuming func suffix(_ maxLength: Int) -> [Element] {
        guard maxLength != 0 else { return [] }
        // 生成容器
        var ringBuffer = ContiguousArray<Element>()
        ringBuffer.reserveCapacity(Swift.min(maxLength, underestimatedCount))
        var i = 0
        
        /*
         由于 Sequence 没有办法随机访问, 这里会有一个轮替的算法.
         和链表的最后几个元素一样, 可以使用那个算法.
         */
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
    
    
    
    /*
     返回一个适配器对象. 丢弃前面几个值.
     */
    @inlinable
    public __consuming func dropFirst(_ k: Int = 1) -> DropFirstSequence<Self> {
        return DropFirstSequence(self, dropping: k)
    }
    
    /*
     返回一个数组, 丢弃后面几个值.
     之所以, 这里返回数组, 而 dropFirst 返回适配器是因为, 只有遍历一次, 才知道最后几个值从哪里开始.
     */
    @inlinable
    public __consuming func dropLast(_ k: Int = 1) -> [Element] {
        guard k != 0 else { return Array(self) }
        
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
    
    /*
     提供一个简便方法, 来使用 DropWhile 的功能.
     */
    @inlinable
    public __consuming func drop(
        while predicate: (Element) throws -> Bool
    ) rethrows -> DropWhileSequence<Self> {
        return try DropWhileSequence(self, predicate: predicate)
    }
    
    /*
     提供一个简便方法, 来使用 prefix 的功能.
     */
    @inlinable
    public __consuming func prefix(_ maxLength: Int) -> PrefixSequence<Self> {
        return PrefixSequence(self, maxLength: maxLength)
    }
    
    /*
     返回头部符合 predicate 的元素, 直到出现一个不适合的.
     */
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
    /*
     将一个 Sequence, 装到一个内存地址的过程. 这里用到了 UnsafeMutableBufferPointer 提供的功能.
     */
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
            ptr.initialize(to: x) // 相关内存值的赋值工作.
            ptr += 1 // 指针的偏移, 偏移量是 Element 相关的.
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

@frozen
public struct IteratorSequence<Base: IteratorProtocol> {
    @usableFromInline
    internal var _base: Base
    @inlinable
    public init(_ base: Base) {
        _base = base
    }
}

extension IteratorSequence: IteratorProtocol, Sequence {
    @inlinable
    public mutating func next() -> Base.Element? {
        return _base.next()
    }
}



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
