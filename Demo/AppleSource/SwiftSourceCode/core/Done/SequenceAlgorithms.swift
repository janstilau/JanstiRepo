/*
 一个专门的, 定义 Sequence 算法的 extension 的集合.
 所有的操作, 都是建立在 可迭代的这个基础上的.
 */
extension Sequence {
    /*
     EnumeratedSequence 是一个特殊的结构体, 他也是 Sequence 协议类型的. 只不过, 它的 iterator 返回的是 (idx, ele) 的一个元组数据.
     他并没有复制原始的 sequence, 而是在原始的 sequence 的遍历过程中, 增加了一些记录 index 的逻辑.
     enumerated() 隐藏了 EnumeratedSequence 的存在, 在使用者眼里, 好像是调用这个方法, 就能改变遍历时返回值的类型.
     Swift 里面, 经常有着这种中间适配器类型的存在, 这种适配器类型, 和原始类型是一个抽象, 所以, 能够很好地安插到原始类型出现的位置.
     */
    @inlinable // protocol-only
    public func enumerated() -> EnumeratedSequence<Self> {
        return EnumeratedSequence(_base: self)
    }
}

/*
 这个类, 就是 Sequence 类的一层包装, 把每个返回来的数据, 增加了 index 值.
 EnumeratedSequence 里面记录 baseSequence 的信息, 但是 index 是 iterator 记录的.
 */

@frozen
public struct EnumeratedSequence<Base: Sequence> {
  @usableFromInline
  internal var _base: Base
  @inlinable
  internal init(_base: Base) {
    self._base = _base
  }
}

extension EnumeratedSequence {
  @frozen
  public struct Iterator {
    @usableFromInline
    internal var _base: Base.Iterator
    @usableFromInline
    internal var _count: Int // 这就是为什么会有 index 的原因, interator 里面, 把迭代的过程记录了下来.
    @inlinable
    internal init(_base: Base.Iterator) {
      self._base = _base
      self._count = 0
    }
  }
}

extension EnumeratedSequence.Iterator: IteratorProtocol, Sequence {
  public typealias Element = (offset: Int, element: Base.Element)
  @inlinable
  public mutating func next() -> Element? {
    guard let b = _base.next() else { return nil }
    let result = (offset: _count, element: b)
    _count += 1
    return result
  }
}

extension EnumeratedSequence: Sequence {
  @inlinable
  public __consuming func makeIterator() -> Iterator {
    return Iterator(_base: _base.makeIterator())
  }
}


//===----------------------------------------------------------------------===//
// min(), max()
//===----------------------------------------------------------------------===//

extension Sequence {
    @inlinable // protocol-only
    public func min(
        by areInIncreasingOrder: (Element, Element) throws -> Bool
    ) rethrows -> Element? {
        var it = makeIterator()
        guard var result = it.next() else { return nil }
        while let e = it.next() {
            if try areInIncreasingOrder(e, result) { result = e }
        }
        return result
    }
    
    @inlinable // protocol-only
    @warn_unqualified_access
    public func max(
        by areInIncreasingOrder: (Element, Element) throws -> Bool
    ) rethrows -> Element? {
        var it = makeIterator()
        guard var result = it.next() else { return nil }
        while let e = it.next() {
            if try areInIncreasingOrder(result, e) { result = e }
        }
        return result
    }
}

/*
 如果 Element: Comparable, 就可以直接使用操作符当做闭包传入了.
 C++ 里面, 是编译的时候, 而 Swfit 里面, 则是通过协议进行的限制.
 */
extension Sequence where Element: Comparable {
    @inlinable
    @warn_unqualified_access
    public func min() -> Element? {
        return self.min(by: <)
    }
    
    @inlinable
    @warn_unqualified_access
    public func max() -> Element? {
        return self.max(by: <)
    }
}

//===----------------------------------------------------------------------===//
// starts(with:)
//===----------------------------------------------------------------------===//
/*
 一个序列的前半部分, 是否是另一个序列. 就是不断的迭代, 判断相同位置的值是否相等.
 C++ 的泛型算法里面, 也有完全类似的功能.
 可见, Swift 的面向协议编程, 只是将原来的通用功能, 用一种更好的方式, 进行了组织.
*/
extension Sequence  {
    @inlinable
    public func starts<PossiblePrefix: Sequence>(
        with possiblePrefix: PossiblePrefix,
        by areEquivalent: (Element, PossiblePrefix.Element) throws -> Bool
    ) rethrows -> Bool {
        var possiblePrefixIterator = possiblePrefix.makeIterator()
        for e0 in self {
            if let e1 = possiblePrefixIterator.next() {
                if try !areEquivalent(e0, e1) {
                    return false
                }
            } else {
                return true
            }
        }
        return possiblePrefixIterator.next() == nil
    }
}

extension Sequence where Element: Equatable {
    @inlinable
    public func starts<PossiblePrefix: Sequence>(
        with possiblePrefix: PossiblePrefix
    ) -> Bool where PossiblePrefix.Element == Element {
        return self.starts(with: possiblePrefix, by: ==)
    }
}

//===----------------------------------------------------------------------===//
// elementsEqual()
//===----------------------------------------------------------------------===//
/*
 elementsEqual, 就是不断的进行迭代, 比较相同位置的元素是否都一样.
*/
extension Sequence {
    
    @inlinable
    public func elementsEqual<OtherSequence: Sequence>(
        _ other: OtherSequence,
        by areEquivalent: (Element, OtherSequence.Element) throws -> Bool
    ) rethrows -> Bool {
        var iter1 = self.makeIterator()
        var iter2 = other.makeIterator()
        while true {
            switch (iter1.next(), iter2.next()) {
            // 如果都有值, 就调用比较. 注意, 系统的 API 很少进行强制解包的操作.
            case let (e1?, e2?):
                if try !areEquivalent(e1, e2) {
                    return false
                }
            case (_?, nil), (nil, _?): return false
            case (nil, nil):           return true
            }
        }
    }
}

extension Sequence where Element: Equatable {
    @inlinable
    public func elementsEqual<OtherSequence: Sequence>(
        _ other: OtherSequence
    ) -> Bool where OtherSequence.Element == Element {
        return self.elementsEqual(other, by: ==)
    }
}

//===----------------------------------------------------------------------===//
// lexicographicallyPrecedes()
//===----------------------------------------------------------------------===//

extension Sequence {
    /*
     所谓的 lexicographically 的顺序, 就是比较前面几个元素, 如果前面几个元素可以比较出结果, 就不管后面的了.
     */
    @inlinable
    public func lexicographicallyPrecedes<OtherSequence: Sequence>(
        _ other: OtherSequence,
        by areInIncreasingOrder: (Element, Element) throws -> Bool
    ) rethrows -> Bool
        where OtherSequence.Element == Element {
            var iter1 = self.makeIterator()
            var iter2 = other.makeIterator()
            while true {
                if let e1 = iter1.next() {
                    if let e2 = iter2.next() {
                        if try areInIncreasingOrder(e1, e2) {
                            return true
                        }
                        if try areInIncreasingOrder(e2, e1) {
                            return false
                        }
                        continue // Equivalent
                    }
                    return false
                }
                
                return iter2.next() != nil
            }
    }
}

extension Sequence where Element: Comparable {
    @inlinable
    public func lexicographicallyPrecedes<OtherSequence: Sequence>(
        _ other: OtherSequence
    ) -> Bool where OtherSequence.Element == Element {
        return self.lexicographicallyPrecedes(other, by: <)
    }
}

//===----------------------------------------------------------------------===//
// contains()
//===----------------------------------------------------------------------===//

extension Sequence {
    /*
     迭代, 每次迭代的时候, 判断是否符合标准, 迭代结束时还没有发现, 就是 false.
     这是很常见的代码, 标准库固定下来, 开发者只关心 predicate 的编写.
     */
    @inlinable
    public func contains(
        where predicate: (Element) throws -> Bool
    ) rethrows -> Bool {
        for e in self {
            if try predicate(e) {
                return true
            }
        }
        return false
    }
    
    /*
     没有不满足条件的, 就是 allSatisfy.
     注意, 这里有两个 try, 第一个是 predicate 的调用, 第二个是 contains 调用.
     */
    @inlinable
    public func allSatisfy(
        _ predicate: (Element) throws -> Bool
    ) rethrows -> Bool {
        return try !contains { try !predicate($0) }
    }
}

extension Sequence where Element: Equatable {
    @inlinable
    /*
     _customContainsEquatableElement
     如果你的类有更好的设计, 可以快速的判断出 contians 来, 那么就用你的设计.
     否则, 就使用 contains 来判断, contains 使用迭代的方式, 来判断.
     */
    public func contains(_ element: Element) -> Bool {
        if let result = _customContainsEquatableElement(element) {
            return result
        } else {
            return self.contains { $0 == element }
        }
    }
}

/*
 reduce, 将序列里面的值, 归并到一个值.
 */
extension Sequence {
    @inlinable
    public func reduce<Result>(
        _ initialResult: Result,
        _ nextPartialResult:
        (_ partialResult: Result, Element) throws -> Result
    ) rethrows -> Result {
        var accumulator = initialResult
        for element in self {
            accumulator = try nextPartialResult(accumulator, element)
        }
        return accumulator
    }
    
    /// This method is preferred over `reduce(_:_:)` for efficiency when the
    /// result is a copy-on-write type, for example an Array or a Dictionary.
    /*
     之前的理解有点问题, 这种 inout 版本的, 更多的是为了减少 copyOnWrite, 而不是说为了使用传出参数这种方式.
     */
    @inlinable
    public func reduce<Result>(
        into initialResult: __owned Result,
        _ updateAccumulatingResult:
        (_ partialResult: inout Result, Element) throws -> ()
    ) rethrows -> Result {
        var accumulator = initialResult
        for element in self {
            try updateAccumulatingResult(&accumulator, element)
        }
        return accumulator
    }
}

//===----------------------------------------------------------------------===//
// reversed()
//===----------------------------------------------------------------------===//

extension Sequence {
    @inlinable
    public __consuming func reversed() -> [Element] {
        /*
         首先, 根据 sequence 建立一个数组, 然后在数组上进行操作.
         因为数组是一个 randomAccess Colleciton, 直接可以通过下标进行操作.
         */
        var result = Array(self)
        let count = result.count
        for i in 0..<count/2 {
            result.swapAt(i, count - ((i + 1) as Int))
        }
        return result
    }
}

//===----------------------------------------------------------------------===//
// flatMap()
//===----------------------------------------------------------------------===//

extension Sequence {
    /*
     如果, 闭包的返回值还是一个 sequence, flatMap 会对里面的值, 进行一次抽取的工作.
     */
    @inlinable
    public func flatMap<SegmentOfResult: Sequence>(
        _ transform: (Element) throws -> SegmentOfResult
    ) rethrows -> [SegmentOfResult.Element] {
        var result: [SegmentOfResult.Element] = []
        for element in self {
            result.append(contentsOf: try transform(element))
        }
        return result
    }
}

extension Sequence {
    @inlinable // protocol-only
    public func compactMap<ElementOfResult>(
        _ transform: (Element) throws -> ElementOfResult?
    ) rethrows -> [ElementOfResult] {
        return try _compactMap(transform)
    }
    
    /*
     如果, transform 的结果非空的话, 才会加到结果里面.
     */
    @inlinable // protocol-only
    @inline(__always)
    public func _compactMap<ElementOfResult>(
        _ transform: (Element) throws -> ElementOfResult?
    ) rethrows -> [ElementOfResult] {
        var result: [ElementOfResult] = []
        for element in self {
            if let newElement = try transform(element) {
                result.append(newElement)
            }
        }
        return result
    }
}
