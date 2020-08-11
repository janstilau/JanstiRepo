extension BidirectionalCollection {
    /*
     只有 BidirectionalCollection 才能进行 last, 因为要找到 end, 然后做一次--操作才可以.
     */
    @inlinable
    public var last: Element? {
        return isEmpty ? nil : self[index(before: endIndex)]
    }
}

extension Collection where Element: Equatable {
    /*
     firstIndex 这种, 没有太好的办法, 就是按个找, 不过 Diction, 应该有更好的办法.
     这其实就是 _customIndexOfEquatableElement 这个方法的作用. 如果你的类, 有着更好的办法, 不要重写 firstIndex, 因为这个方法是 Collection 的 extension, 你重写的话也不会调用的.
     但是 _customIndexOfEquatableElement 是 Collection 的 primitive, 重写的话, 在 firstIndex 里面, 还是可以调用的到的.
     */
    @inlinable
    public func firstIndex(of element: Element) -> Index? {
        if let result = _customIndexOfEquatableElement(element) {
            return result
        }
        
        var i = self.startIndex
        while i != self.endIndex {
            /*
             这里, 直接用的 ==, 因为 Element: Equatable 这里已经添加了限制.
             */
            if self[i] == element {
                return i
            }
            self.formIndex(after: &i)
        }
        return nil
    }
}

extension Collection {
    @inlinable
    public func firstIndex(
        where predicate: (Element) throws -> Bool
    ) rethrows -> Index? {
        var i = self.startIndex
        while i != self.endIndex {
            if try predicate(self[i]) { // 增加了闭包的变形.
                return i
            }
            self.formIndex(after: &i)
        }
        return nil
    }
}

/*
 双向的集合, 才能使用 last 方法, 这里是 last 的变形, criteria 代替了 == 判断.
 */
extension BidirectionalCollection {
    /*
     使用了 lastIndex 的结果, 作为后续操作的基础.
     */
    @inlinable
    public func last(
        where predicate: (Element) throws -> Bool
    ) rethrows -> Element? {
        return try lastIndex(where: predicate).map { self[$0] }
    }
    
    @inlinable
    public func lastIndex(
        where predicate: (Element) throws -> Bool
    ) rethrows -> Index? {
        var i = endIndex
        while i != startIndex {
            formIndex(before: &i)
            if try predicate(self[i]) {
                return i
            }
        }
        return nil
    }
}

extension BidirectionalCollection where Element: Equatable {
    @inlinable
    public func lastIndex(of element: Element) -> Index? {
        if let result = _customLastIndexOfEquatableElement(element) {
            return result
        }
        return lastIndex(where: { $0 == element })
    }
}

//===----------------------------------------------------------------------===//
// partition(by:)
//===----------------------------------------------------------------------===//

extension MutableCollection {
    /// Reorders the elements of the collection such that all the elements
    /// that match the given predicate are after all the elements that don't
    /// match.
    ///
    /// After partitioning a collection, there is a pivot index `p` where
    /// no element before `p` satisfies the `belongsInSecondPartition`
    /// predicate and every element at or after `p` satisfies
    /// `belongsInSecondPartition`.
    ///
    /// In the following example, an array of numbers is partitioned by a
    /// predicate that matches elements greater than 30.
    ///
    ///     var numbers = [30, 40, 20, 30, 30, 60, 10]
    ///     let p = numbers.partition(by: { $0 > 30 })
    ///     // p == 5
    ///     // numbers == [30, 10, 20, 30, 30, 60, 40]
    ///
    /// The `numbers` array is now arranged in two partitions. The first
    /// partition, `numbers[..<p]`, is made up of the elements that
    /// are not greater than 30. The second partition, `numbers[p...]`,
    /// is made up of the elements that *are* greater than 30.
    ///
    ///     let first = numbers[..<p]
    ///     // first == [30, 10, 20, 30, 30]
    ///     let second = numbers[p...]
    ///     // second == [60, 40]
    ///
    /// - Parameter belongsInSecondPartition: A predicate used to partition
    ///   the collection. All elements satisfying this predicate are ordered
    ///   after all elements not satisfying it.
    /// - Returns: The index of the first element in the reordered collection
    ///   that matches `belongsInSecondPartition`. If no elements in the
    ///   collection match `belongsInSecondPartition`, the returned index is
    ///   equal to the collection's `endIndex`.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the collection.
    @inlinable
    public mutating func partition(
        by belongsInSecondPartition: (Element) throws -> Bool
    ) rethrows -> Index {
        return try _halfStablePartition(isSuffixElement: belongsInSecondPartition)
    }
    
    /// Moves all elements satisfying `isSuffixElement` into a suffix of the
    /// collection, returning the start position of the resulting suffix.
    ///
    /// - Complexity: O(*n*) where n is the length of the collection.
    @inlinable
    internal mutating func _halfStablePartition(
        isSuffixElement: (Element) throws -> Bool
    ) rethrows -> Index {
        guard var i = try firstIndex(where: isSuffixElement)
            else { return endIndex }
        
        var j = index(after: i)
        while j != endIndex {
            if try !isSuffixElement(self[j]) { swapAt(i, j); formIndex(after: &i) }
            formIndex(after: &j)
        }
        return i
    }  
}

extension MutableCollection where Self: BidirectionalCollection {
    /// Reorders the elements of the collection such that all the elements
    /// that match the given predicate are after all the elements that don't
    /// match.
    ///
    /// After partitioning a collection, there is a pivot index `p` where
    /// no element before `p` satisfies the `belongsInSecondPartition`
    /// predicate and every element at or after `p` satisfies
    /// `belongsInSecondPartition`.
    ///
    /// In the following example, an array of numbers is partitioned by a
    /// predicate that matches elements greater than 30.
    ///
    ///     var numbers = [30, 40, 20, 30, 30, 60, 10]
    ///     let p = numbers.partition(by: { $0 > 30 })
    ///     // p == 5
    ///     // numbers == [30, 10, 20, 30, 30, 60, 40]
    ///
    /// The `numbers` array is now arranged in two partitions. The first
    /// partition, `numbers[..<p]`, is made up of the elements that
    /// are not greater than 30. The second partition, `numbers[p...]`,
    /// is made up of the elements that *are* greater than 30.
    ///
    ///     let first = numbers[..<p]
    ///     // first == [30, 10, 20, 30, 30]
    ///     let second = numbers[p...]
    ///     // second == [60, 40]
    ///
    /// - Parameter belongsInSecondPartition: A predicate used to partition
    ///   the collection. All elements satisfying this predicate are ordered
    ///   after all elements not satisfying it.
    /// - Returns: The index of the first element in the reordered collection
    ///   that matches `belongsInSecondPartition`. If no elements in the
    ///   collection match `belongsInSecondPartition`, the returned index is
    ///   equal to the collection's `endIndex`.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the collection.
    @inlinable
    public mutating func partition(
        by belongsInSecondPartition: (Element) throws -> Bool
    ) rethrows -> Index {
        let maybeOffset = try _withUnsafeMutableBufferPointerIfSupported {
            (bufferPointer) -> Int in
            let unsafeBufferPivot = try bufferPointer._partitionImpl(
                by: belongsInSecondPartition)
            return unsafeBufferPivot - bufferPointer.startIndex
        }
        if let offset = maybeOffset {
            return index(startIndex, offsetBy: offset)
        } else {
            return try _partitionImpl(by: belongsInSecondPartition)
        }
    }
    
    @usableFromInline
    internal mutating func _partitionImpl(
        by belongsInSecondPartition: (Element) throws -> Bool
    ) rethrows -> Index {
        var lo = startIndex
        var hi = endIndex
        
        // 'Loop' invariants (at start of Loop, all are true):
        // * lo < hi
        // * predicate(self[i]) == false, for i in startIndex ..< lo
        // * predicate(self[i]) == true, for i in hi ..< endIndex
        
        Loop: while true {
            FindLo: repeat {
                while lo < hi {
                    if try belongsInSecondPartition(self[lo]) { break FindLo }
                    formIndex(after: &lo)
                }
                break Loop
            } while false
            
            FindHi: repeat {
                formIndex(before: &hi)
                while lo < hi {
                    if try !belongsInSecondPartition(self[hi]) { break FindHi }
                    formIndex(before: &hi)
                }
                break Loop
            } while false
            
            swapAt(lo, hi)
            formIndex(after: &lo)
        }
        
        return lo
    }
}

//===----------------------------------------------------------------------===//
// shuffled()/shuffle()
//===----------------------------------------------------------------------===//

extension Sequence {
    /// Returns the elements of the sequence, shuffled using the given generator
    /// as a source for randomness.
    ///
    /// You use this method to randomize the elements of a sequence when you are
    /// using a custom random number generator. For example, you can shuffle the
    /// numbers between `0` and `9` by calling the `shuffled(using:)` method on
    /// that range:
    ///
    ///     let numbers = 0...9
    ///     let shuffledNumbers = numbers.shuffled(using: &myGenerator)
    ///     // shuffledNumbers == [8, 9, 4, 3, 2, 6, 7, 0, 5, 1]
    ///
    /// - Parameter generator: The random number generator to use when shuffling
    ///   the sequence.
    /// - Returns: An array of this sequence's elements in a shuffled order.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the sequence.
    /// - Note: The algorithm used to shuffle a sequence may change in a future
    ///   version of Swift. If you're passing a generator that results in the
    ///   same shuffled order each time you run your program, that sequence may
    ///   change when your program is compiled using a different version of
    ///   Swift.
    @inlinable
    public func shuffled<T: RandomNumberGenerator>(
        using generator: inout T
    ) -> [Element] {
        var result = ContiguousArray(self)
        result.shuffle(using: &generator)
        return Array(result)
    }
    
    /// Returns the elements of the sequence, shuffled.
    ///
    /// For example, you can shuffle the numbers between `0` and `9` by calling
    /// the `shuffled()` method on that range:
    ///
    ///     let numbers = 0...9
    ///     let shuffledNumbers = numbers.shuffled()
    ///     // shuffledNumbers == [1, 7, 6, 2, 8, 9, 4, 3, 5, 0]
    ///
    /// This method is equivalent to calling `shuffled(using:)`, passing in the
    /// system's default random generator.
    ///
    /// - Returns: A shuffled array of this sequence's elements.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the sequence.
    @inlinable
    public func shuffled() -> [Element] {
        var g = SystemRandomNumberGenerator()
        return shuffled(using: &g)
    }
}

extension MutableCollection where Self: RandomAccessCollection {
    /// Shuffles the collection in place, using the given generator as a source
    /// for randomness.
    ///
    /// You use this method to randomize the elements of a collection when you
    /// are using a custom random number generator. For example, you can use the
    /// `shuffle(using:)` method to randomly reorder the elements of an array.
    ///
    ///     var names = ["Alejandro", "Camila", "Diego", "Luciana", "Luis", "Sofía"]
    ///     names.shuffle(using: &myGenerator)
    ///     // names == ["Sofía", "Alejandro", "Camila", "Luis", "Diego", "Luciana"]
    ///
    /// - Parameter generator: The random number generator to use when shuffling
    ///   the collection.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the collection.
    /// - Note: The algorithm used to shuffle a collection may change in a future
    ///   version of Swift. If you're passing a generator that results in the
    ///   same shuffled order each time you run your program, that sequence may
    ///   change when your program is compiled using a different version of
    ///   Swift.
    @inlinable
    public mutating func shuffle<T: RandomNumberGenerator>(
        using generator: inout T
    ) {
        guard count > 1 else { return }
        var amount = count
        var currentIndex = startIndex
        while amount > 1 {
            let random = Int.random(in: 0 ..< amount, using: &generator)
            amount -= 1
            swapAt(
                currentIndex,
                index(currentIndex, offsetBy: random)
            )
            formIndex(after: &currentIndex)
        }
    }
    
    /// Shuffles the collection in place.
    ///
    /// Use the `shuffle()` method to randomly reorder the elements of an array.
    ///
    ///     var names = ["Alejandro", "Camila", "Diego", "Luciana", "Luis", "Sofía"]
    ///     names.shuffle(using: myGenerator)
    ///     // names == ["Luis", "Camila", "Luciana", "Sofía", "Alejandro", "Diego"]
    ///
    /// This method is equivalent to calling `shuffle(using:)`, passing in the
    /// system's default random generator.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the collection.
    @inlinable
    public mutating func shuffle() {
        var g = SystemRandomNumberGenerator()
        shuffle(using: &g)
    }
}
