/*
 所有的以下这些操作, 都是建立在了一个简单的方法之上的.
 */

public protocol RangeReplaceableCollection: Collection
where SubSequence: RangeReplaceableCollection {
    override associatedtype SubSequence
    init()
    /*
     最核心的方法, 下面的所有的方法, 都可以通过 replaceSubrange with 来进行模拟.
     */
    mutating func replaceSubrange<C>(
        _ subrange: Range<Index>,
        with newElements: __owned C
    ) where C: Collection, C.Element == Element
    
    /*
     扩容处理.
     */
    mutating func reserveCapacity(_ n: Int)
    
    init(repeating repeatedValue: Element, count: Int)
    
    init<S: Sequence>(_ elements: S)
        where S.Element == Element
    
    mutating func append(_ newElement: __owned Element)
    
    mutating func append<S: Sequence>(contentsOf newElements: __owned S)
        where S.Element == Element
    
    mutating func insert(_ newElement: __owned Element, at i: Index)
    
    mutating func insert<S: Collection>(contentsOf newElements: __owned S, at i: Index)
        where S.Element == Element
    
    @discardableResult
    mutating func remove(at i: Index) -> Element
    
    mutating func removeSubrange(_ bounds: Range<Index>)
    
    mutating func _customRemoveLast() -> Element?
    
    mutating func _customRemoveLast(_ n: Int) -> Bool
    
    @discardableResult
    mutating func removeFirst() -> Element
    
    mutating func removeFirst(_ k: Int)
    
    mutating func removeAll(keepingCapacity keepCapacity: Bool /*= false*/)
    
    mutating func removeAll(
        where shouldBeRemoved: (Element) throws -> Bool) rethrows
    
    @_borrowed
    override subscript(bounds: Index) -> Element { get }
    override subscript(bounds: Range<Index>) -> SubSequence { get }
}

extension RangeReplaceableCollection {
    @inlinable
    public init(repeating repeatedValue: Element, count: Int) {
        self.init()
        if count != 0 {
            let elements = Repeated(_repeating: repeatedValue, count: count)
            append(contentsOf: elements)
        }
    }
    
    @inlinable
    public init<S: Sequence>(_ elements: S)
        where S.Element == Element {
            self.init()
            append(contentsOf: elements)
    }
    
    
    /*
     insert 就是 endIndex 进行插入
     */
    @inlinable
    public mutating func append(_ newElement: __owned Element) {
        insert(newElement, at: endIndex)
    }
    
    /*
     underestimatedCount 在这里又用到了.
     根据当前的 count, 和 sequence 的 count, 提前进行内存的申请.
     */
    @inlinable
    public mutating func append<S: Sequence>(contentsOf newElements: __owned S)
        where S.Element == Element {
            let approximateCapacity =
                self.count +
                numericCast(newElements.underestimatedCount)
            self.reserveCapacity(approximateCapacity)
            for element in newElements {
                append(element)
            }
    }
    
    
    @inlinable
    public mutating func insert(
        _ newElement: __owned Element, at i: Index
    ) {
        replaceSubrange(i..<i, with: CollectionOfOne(newElement))
    }
    
    @inlinable
    public mutating func insert<C: Collection>(
        contentsOf newElements: __owned C, at i: Index
    ) where C.Element == Element {
        replaceSubrange(i..<i, with: newElements)
    }
    
    @inlinable
    @discardableResult
    public mutating func remove(at position: Index) -> Element {
        _precondition(!isEmpty, "Can't remove from an empty collection")
        let result: Element = self[position]
        replaceSubrange(position..<index(after: position), with: EmptyCollection())
        return result
    }
    
    @inlinable
    public mutating func removeSubrange(_ bounds: Range<Index>) {
        replaceSubrange(bounds, with: EmptyCollection())
    }
    
    @inlinable
    public mutating func removeFirst(_ k: Int) {
        if k == 0 { return }
        _precondition(k >= 0, "Number of elements to remove should be non-negative")
        _precondition(count >= k,
                      "Can't remove more items from a collection than it has")
        let end = index(startIndex, offsetBy: k)
        removeSubrange(startIndex..<end)
    }
    
    @inlinable
    @discardableResult
    public mutating func removeFirst() -> Element {
        _precondition(!isEmpty,
                      "Can't remove first element from an empty collection")
        let firstElement = first!
        removeFirst(1)
        return firstElement
    }
    
    @inlinable
    public mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
        if !keepCapacity {
            self = Self()
        } else {
            replaceSubrange(startIndex..<endIndex, with: EmptyCollection())
        }
    }
    
    @inlinable
    public mutating func reserveCapacity(_ n: Int) {}
}

extension RangeReplaceableCollection where SubSequence == Self {
    @inlinable
    @discardableResult
    public mutating func removeFirst() -> Element {
        _precondition(!isEmpty, "Can't remove items from an empty collection")
        let element = first!
        self = self[index(after: startIndex)..<endIndex]
        return element
    }
    
    @inlinable
    public mutating func removeFirst(_ k: Int) {
        if k == 0 { return }
        _precondition(k >= 0, "Number of elements to remove should be non-negative")
        _precondition(count >= k,
                      "Can't remove more items from a collection than it contains")
        self = self[index(startIndex, offsetBy: k)..<endIndex]
    }
}

extension RangeReplaceableCollection {
    /*
     最终, 还是调用了 replaceSubRange 方法.
     subrange.relative(to: self) 在这里会被调用了, 首先会根据 collection, 进行 subrange 的一次范围的核查工作.
     */
    @inlinable
    public mutating func replaceSubrange<C: Collection, R: RangeExpression>(
        _ subrange: R,
        with newElements: __owned C
    ) where C.Element == Element, R.Bound == Index {
        self.replaceSubrange(subrange.relative(to: self), with: newElements)
    }
    
    @inlinable
    public mutating func removeSubrange<R: RangeExpression>(
        _ bounds: R
    ) where R.Bound == Index  {
        removeSubrange(bounds.relative(to: self))
    }
}

extension RangeReplaceableCollection {
    @inlinable
    public mutating func _customRemoveLast() -> Element? {
        return nil
    }
    
    @inlinable
    public mutating func _customRemoveLast(_ n: Int) -> Bool {
        return false
    }
}

extension RangeReplaceableCollection
where Self: BidirectionalCollection, SubSequence == Self {
    
    @inlinable
    public mutating func _customRemoveLast() -> Element? {
        let element = last!
        self = self[startIndex..<index(before: endIndex)]
        return element
    }
    
    @inlinable
    public mutating func _customRemoveLast(_ n: Int) -> Bool {
        self = self[startIndex..<index(endIndex, offsetBy: numericCast(-n))]
        return true
    }
}

extension RangeReplaceableCollection where Self: BidirectionalCollection {
    /// Removes and returns the last element of the collection.
    ///
    /// Calling this method may invalidate all saved indices of this
    /// collection. Do not rely on a previously stored index value after
    /// altering a collection with any operation that can change its length.
    ///
    /// - Returns: The last element of the collection if the collection is not
    /// empty; otherwise, `nil`.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func popLast() -> Element? {
        if isEmpty { return nil }
        // duplicate of removeLast logic below, to avoid redundant precondition
        if let result = _customRemoveLast() { return result }
        return remove(at: index(before: endIndex))
    }
    
    /// Removes and returns the last element of the collection.
    ///
    /// The collection must not be empty.
    ///
    /// Calling this method may invalidate all saved indices of this
    /// collection. Do not rely on a previously stored index value after
    /// altering a collection with any operation that can change its length.
    ///
    /// - Returns: The last element of the collection.
    ///
    /// - Complexity: O(1)
    @inlinable
    @discardableResult
    public mutating func removeLast() -> Element {
        _precondition(!isEmpty, "Can't remove last element from an empty collection")
        // NOTE if you change this implementation, change popLast above as well
        // AND change the tie-breaker implementations in the next extension
        if let result = _customRemoveLast() { return result }
        return remove(at: index(before: endIndex))
    }
    
    /// Removes the specified number of elements from the end of the
    /// collection.
    ///
    /// Attempting to remove more elements than exist in the collection
    /// triggers a runtime error.
    ///
    /// Calling this method may invalidate all saved indices of this
    /// collection. Do not rely on a previously stored index value after
    /// altering a collection with any operation that can change its length.
    ///
    /// - Parameter k: The number of elements to remove from the collection.
    ///   `k` must be greater than or equal to zero and must not exceed the
    ///   number of elements in the collection.
    ///
    /// - Complexity: O(*k*), where *k* is the specified number of elements.
    @inlinable
    public mutating func removeLast(_ k: Int) {
        if k == 0 { return }
        _precondition(k >= 0, "Number of elements to remove should be non-negative")
        _precondition(count >= k,
                      "Can't remove more items from a collection than it contains")
        if _customRemoveLast(k) {
            return
        }
        let end = endIndex
        removeSubrange(index(end, offsetBy: -k)..<end)
    }
}

/// Ambiguity breakers.
extension RangeReplaceableCollection
where Self: BidirectionalCollection, SubSequence == Self {
    /// Removes and returns the last element of the collection.
    ///
    /// Calling this method may invalidate all saved indices of this
    /// collection. Do not rely on a previously stored index value after
    /// altering a collection with any operation that can change its length.
    ///
    /// - Returns: The last element of the collection if the collection is not
    /// empty; otherwise, `nil`.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func popLast() -> Element? {
        if isEmpty { return nil }
        // duplicate of removeLast logic below, to avoid redundant precondition
        if let result = _customRemoveLast() { return result }
        return remove(at: index(before: endIndex))
    }
    
    /// Removes and returns the last element of the collection.
    ///
    /// The collection must not be empty.
    ///
    /// Calling this method may invalidate all saved indices of this
    /// collection. Do not rely on a previously stored index value after
    /// altering a collection with any operation that can change its length.
    ///
    /// - Returns: The last element of the collection.
    ///
    /// - Complexity: O(1)
    @inlinable
    @discardableResult
    public mutating func removeLast() -> Element {
        _precondition(!isEmpty, "Can't remove last element from an empty collection")
        // NOTE if you change this implementation, change popLast above as well
        if let result = _customRemoveLast() { return result }
        return remove(at: index(before: endIndex))
    }
    
    /// Removes the specified number of elements from the end of the
    /// collection.
    ///
    /// Attempting to remove more elements than exist in the collection
    /// triggers a runtime error.
    ///
    /// Calling this method may invalidate all saved indices of this
    /// collection. Do not rely on a previously stored index value after
    /// altering a collection with any operation that can change its length.
    ///
    /// - Parameter k: The number of elements to remove from the collection.
    ///   `k` must be greater than or equal to zero and must not exceed the
    ///   number of elements in the collection.
    ///
    /// - Complexity: O(*k*), where *k* is the specified number of elements.
    @inlinable
    public mutating func removeLast(_ k: Int) {
        if k == 0 { return }
        _precondition(k >= 0, "Number of elements to remove should be non-negative")
        _precondition(count >= k,
                      "Can't remove more items from a collection than it contains")
        if _customRemoveLast(k) {
            return
        }
        let end = endIndex
        removeSubrange(index(end, offsetBy: -k)..<end)
    }
}

/*
 + 操作符的重载, 注意, 这里是生成了一个新的集合.
 */
extension RangeReplaceableCollection {
    /// Creates a new collection by concatenating the elements of a collection and
    /// a sequence.
    ///
    /// The two arguments must have the same `Element` type. For example, you can
    /// concatenate the elements of an integer array and a `Range<Int>` instance.
    ///
    ///     let numbers = [1, 2, 3, 4]
    ///     let moreNumbers = numbers + 5...10
    ///     print(moreNumbers)
    ///     // Prints "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
    ///
    /// The resulting collection has the type of the argument on the left-hand
    /// side. In the example above, `moreNumbers` has the same type as `numbers`,
    /// which is `[Int]`.
    ///
    /// - Parameters:
    ///   - lhs: A range-replaceable collection.
    ///   - rhs: A collection or finite sequence.
    @inlinable
    public static func + <
        Other: Sequence
        >(lhs: Self, rhs: Other) -> Self
        where Element == Other.Element {
            var lhs = lhs
            // FIXME: what if lhs is a reference type?  This will mutate it.
            lhs.append(contentsOf: rhs)
            return lhs
    }
    
    /// Creates a new collection by concatenating the elements of a sequence and a
    /// collection.
    ///
    /// The two arguments must have the same `Element` type. For example, you can
    /// concatenate the elements of a `Range<Int>` instance and an integer array.
    ///
    ///     let numbers = [7, 8, 9, 10]
    ///     let moreNumbers = 1...6 + numbers
    ///     print(moreNumbers)
    ///     // Prints "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
    ///
    /// The resulting collection has the type of argument on the right-hand side.
    /// In the example above, `moreNumbers` has the same type as `numbers`, which
    /// is `[Int]`.
    ///
    /// - Parameters:
    ///   - lhs: A collection or finite sequence.
    ///   - rhs: A range-replaceable collection.
    @inlinable
    public static func + <
        Other: Sequence
        >(lhs: Other, rhs: Self) -> Self
        where Element == Other.Element {
            var result = Self()
            result.reserveCapacity(rhs.count + numericCast(lhs.underestimatedCount))
            result.append(contentsOf: lhs)
            result.append(contentsOf: rhs)
            return result
    }
    
    /// Appends the elements of a sequence to a range-replaceable collection.
    ///
    /// Use this operator to append the elements of a sequence to the end of
    /// range-replaceable collection with same `Element` type. This example
    /// appends the elements of a `Range<Int>` instance to an array of integers.
    ///
    ///     var numbers = [1, 2, 3, 4, 5]
    ///     numbers += 10...15
    ///     print(numbers)
    ///     // Prints "[1, 2, 3, 4, 5, 10, 11, 12, 13, 14, 15]"
    ///
    /// - Parameters:
    ///   - lhs: The array to append to.
    ///   - rhs: A collection or finite sequence.
    ///
    /// - Complexity: O(*m*), where *m* is the length of the right-hand-side
    ///   argument.
    /// += 的话, 就可以直接在 lhs 进行操作.
    @inlinable
    public static func += <
        Other: Sequence
        >(lhs: inout Self, rhs: Other)
        where Element == Other.Element {
            lhs.append(contentsOf: rhs)
    }
    
    /// Creates a new collection by concatenating the elements of two collections.
    ///
    /// The two arguments must have the same `Element` type. For example, you can
    /// concatenate the elements of two integer arrays.
    ///
    ///     let lowerNumbers = [1, 2, 3, 4]
    ///     let higherNumbers: ContiguousArray = [5, 6, 7, 8, 9, 10]
    ///     let allNumbers = lowerNumbers + higherNumbers
    ///     print(allNumbers)
    ///     // Prints "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
    ///
    /// The resulting collection has the type of the argument on the left-hand
    /// side. In the example above, `moreNumbers` has the same type as `numbers`,
    /// which is `[Int]`.
    ///
    /// - Parameters:
    ///   - lhs: A range-replaceable collection.
    ///   - rhs: Another range-replaceable collection.
    @inlinable
    public static func + <
        Other: RangeReplaceableCollection
        >(lhs: Self, rhs: Other) -> Self
        where Element == Other.Element {
            var lhs = lhs
            // FIXME: what if lhs is a reference type?  This will mutate it.
            lhs.append(contentsOf: rhs)
            return lhs
    }
}


extension RangeReplaceableCollection {
    /// Returns a new collection of the same type containing, in order, the
    /// elements of the original collection that satisfy the given predicate.
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
    ///   whether the element should be included in the returned collection.
    /// - Returns: A collection of the elements that `isIncluded` allowed.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the collection.
    @inlinable
    @available(swift, introduced: 4.0)
    public __consuming func filter(
        _ isIncluded: (Element) throws -> Bool
    ) rethrows -> Self {
        return try Self(self.lazy.filter(isIncluded))
    }
}

extension RangeReplaceableCollection where Self: MutableCollection {
    /// Removes all the elements that satisfy the given predicate.
    ///
    /// Use this method to remove every element in a collection that meets
    /// particular criteria. The order of the remaining elements is preserved.
    /// This example removes all the odd values from an
    /// array of numbers:
    ///
    ///     var numbers = [5, 6, 7, 8, 9, 10, 11]
    ///     numbers.removeAll(where: { $0 % 2 != 0 })
    ///     // numbers == [6, 8, 10]
    ///
    /// - Parameter shouldBeRemoved: A closure that takes an element of the
    ///   sequence as its argument and returns a Boolean value indicating
    ///   whether the element should be removed from the collection.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the collection.
    @inlinable
    public mutating func removeAll(
        where shouldBeRemoved: (Element) throws -> Bool
    ) rethrows {
        let suffixStart = try _halfStablePartition(isSuffixElement: shouldBeRemoved)
        removeSubrange(suffixStart...)
    }
}

extension RangeReplaceableCollection {
    /// Removes all the elements that satisfy the given predicate.
    ///
    /// Use this method to remove every element in a collection that meets
    /// particular criteria. The order of the remaining elements is preserved.
    /// This example removes all the vowels from a string:
    ///
    ///     var phrase = "The rain in Spain stays mainly in the plain."
    ///
    ///     let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
    ///     phrase.removeAll(where: { vowels.contains($0) })
    ///     // phrase == "Th rn n Spn stys mnly n th pln."
    ///
    /// - Parameter shouldBeRemoved: A closure that takes an element of the
    ///   sequence as its argument and returns a Boolean value indicating
    ///   whether the element should be removed from the collection.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the collection.
    @inlinable
    public mutating func removeAll(
        where shouldBeRemoved: (Element) throws -> Bool
    ) rethrows {
        // FIXME: Switch to using RRC.filter once stdlib is compiled for 4.0
        // self = try filter { try !predicate($0) }
        self = try Self(self.lazy.filter { try !shouldBeRemoved($0) })
    }
}
