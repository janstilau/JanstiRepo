extension Sequence {

    // 通过序列取值, 和通过索引取值, 其实是两套思路.
    @inlinable // protocol-only
    public func enumerated() -> EnumeratedSequence<Self> {
        return EnumeratedSequence(_base: self)
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

extension Sequence where Element: Comparable {
    // 算法应该提供默认的实现, 来帮助使用者更加方便的使用.
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

//
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
            }
            else {
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

extension Sequence {
    @inlinable
    public func elementsEqual<OtherSequence: Sequence>(
        _ other: OtherSequence,
        by areEquivalent: (Element, OtherSequence.Element) throws -> Bool
    ) rethrows -> Bool {
        var iter1 = self.makeIterator()
        var iter2 = other.makeIterator()
        while true {
            // 各种比较操作, 因为 optinal 的引入, 大量的使用了 swift a, b 的模式, 这种模式, 让代码更加的清晰.
            switch (iter1.next(), iter2.next()) {
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

extension Sequence {
    // 所谓的字典排序方式, 就是从前到后依次比较, 前面的数据能够确定大小, 就作为整个序列的大小.
    // 这里代码的实现, 也就是这个思路.
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


extension Sequence {
    // 序列的 contains 就是从前到尾搂一遍, 如果可以用 predicate 判断为真, 就是含有.
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
    // contains 可能抛出错误, pricicate 可能抛出错误, 都使用了 try.
    // 利用已有的逻辑, 进行逻辑操作, 这样, 所有的代码可以集中到一处.
    // contains 的修改, 可以直接影响到其他的部分.
    @inlinable
    public func allSatisfy(
        _ predicate: (Element) throws -> Bool
    ) rethrows -> Bool {
        return try !contains { try !predicate($0) }
    }
}

extension Sequence where Element: Equatable {
    // _customContainsEquatableElement 是 sequence 协议的一个 primitiveMethod.
    // 各个实现了 sequence 的类型, 如果有着更快的判断 contains 的办法, 可以实现该方法, 这样可以提高效率
    // 例如, stride 就是直接判断, 是否在范围内就可以了.
    // 这个方法, sequence 提供了默认实现, 返回 nil. 这样就回归到了最原始的搂一遍判断的模式了.
    @inlinable
    public func contains(_ element: Element) -> Bool {
        if let result = _customContainsEquatableElement(element) {
            return result
        } else {
            return self.contains { $0 == element }
        }
    }
}

//===----------------------------------------------------------------------===//
// reduce()
//===----------------------------------------------------------------------===//

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
    
    @inlinable
    public func reduce<Result>(
        into initialResult: __owned Result,
        _ updateAccumulatingResult:
            (_ partialResult: inout Result, Element) throws -> ()
    ) rethrows -> Result {
        var accumulator = initialResult
        // 这里, accumulator 只会有一个.
        // inout 本质还是传地址, 所以, 这里 &accumulator 的形式传递, 不会增加里面的引用值的引用计数.
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
    public __consuming func reversed() -> [Element] {
        // 首先, 根据 sequence 生成一个数组, 然后数组的倒置.
        var result = Array(self)
        let count = result.count
        for i in 0..<count/2 {
            result.swapAt(i, count - ((i + 1) as Int))
        }
        return result
    }
}

extension Sequence {
    @inlinable
    public func flatMap<SegmentOfResult: Sequence>(
        _ transform: (Element) throws -> SegmentOfResult
    ) rethrows -> [SegmentOfResult.Element] {
        var result: [SegmentOfResult.Element] = []
        for element in self {
            // 唯一的差别, 就是里面变成了 contentsOf.
            // 所以不能瞎传 transform, 如果 transform 的结果, 不是一个 sequence, 那么会报错的.
            result.append(contentsOf: try transform(element))
        }
        return result
    }
}

extension Sequence {
    // 只添加不是 nil 的 transform 后的数据.
    @inlinable // protocol-only
    public func compactMap<ElementOfResult>(
        _ transform: (Element) throws -> ElementOfResult?
    ) rethrows -> [ElementOfResult] {
        return try _compactMap(transform)
    }
    
    // The implementation of flatMap accepting a closure with an optional result.
    // Factored out into a separate functions in order to be used in multiple
    // overloads.
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
