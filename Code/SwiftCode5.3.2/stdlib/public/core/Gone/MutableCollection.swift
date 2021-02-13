// MutableCollection, 就是有了可变性.
// MutableCollection 的 primitive method 就是 subscript set 方法.
// 也就是说, 只要 subscript 增加了 set, 就是可变的了.
// MutableCollection 是可以改变数据, 但是不能增加或者删除, 增加或者删除相关的逻辑, 在 RangeReplaceableCollection 中

public protocol MutableCollection: Collection
where SubSequence: MutableCollection
{
    override associatedtype Element
    override associatedtype Index
    override associatedtype SubSequence
    
    override subscript(position: Index) -> Element { get set }
    override subscript(bounds: Range<Index>) -> SubSequence { get set }
    
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
    mutating func partition(
        by belongsInSecondPartition: (Element) throws -> Bool
    ) rethrows -> Index
    
    mutating func swapAt(_ i: Index, _ j: Index)
    
    /// Call `body(p)`, where `p` is a pointer to the collection's
    /// mutable contiguous storage.  If no such storage exists, it is
    /// first created.  If the collection does not support an internal
    /// representation in a form of mutable contiguous storage, `body` is not
    /// called and `nil` is returned.
    ///
    /// Often, the optimizer can eliminate bounds- and uniqueness-checks
    /// within an algorithm, but when that fails, invoking the
    /// same algorithm on `body`\ 's argument lets you trade safety for
    /// speed.
    mutating func _withUnsafeMutableBufferPointerIfSupported<R>(
        _ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R
    ) rethrows -> R?
    
    /// Call `body(p)`, where `p` is a pointer to the collection's
    /// mutable contiguous storage.  If no such storage exists, it is
    /// first created.  If the collection does not support an internal
    /// representation in a form of mutable contiguous storage, `body` is not
    /// called and `nil` is returned.
    ///
    /// Often, the optimizer can eliminate bounds- and uniqueness-checks
    /// within an algorithm, but when that fails, invoking the
    /// same algorithm on `body`\ 's argument lets you trade safety for
    /// speed.
    mutating func withContiguousMutableStorageIfAvailable<R>(
        _ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R
    ) rethrows -> R?
}

extension MutableCollection {
    public mutating func _withUnsafeMutableBufferPointerIfSupported<R>(
        _ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R
    ) rethrows -> R? {
        return nil
    }
    
    public mutating func withContiguousMutableStorageIfAvailable<R>(
        _ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R
    ) rethrows -> R? {
        return nil
    }
    
    /// Accesses a contiguous subrange of the collection's elements.
    ///
    /// The accessed slice uses the same indices for the same elements as the
    /// original collection. Always use the slice's `startIndex` property
    /// instead of assuming that its indices start at a particular value.
    ///
    /// This example demonstrates getting a slice of an array of strings, finding
    /// the index of one of the strings in the slice, and then using that index
    /// in the original array.
    ///
    ///     let streets = ["Adams", "Bryant", "Channing", "Douglas", "Evarts"]
    ///     let streetsSlice = streets[2 ..< streets.endIndex]
    ///     print(streetsSlice)
    ///     // Prints "["Channing", "Douglas", "Evarts"]"
    ///
    ///     let index = streetsSlice.firstIndex(of: "Evarts")    // 4
    ///     streets[index!] = "Eustace"
    ///     print(streets[index!])
    ///     // Prints "Eustace"
    ///
    /// - Parameter bounds: A range of the collection's indices. The bounds of
    ///   the range must be valid indices of the collection.
    ///
    /// - Complexity: O(1)
    @inlinable
    public subscript(bounds: Range<Index>) -> Slice<Self> {
        get {
            _failEarlyRangeCheck(bounds, bounds: startIndex..<endIndex)
            return Slice(base: self, bounds: bounds)
        }
        set {
            _writeBackMutableSlice(&self, bounds: bounds, slice: newValue)
        }
    }
    
    // 只有, 可以修改, 才能进行 swap
    public mutating func swapAt(_ i: Index, _ j: Index) {
        guard i != j else { return }
        let tmp = self[i]
        self[i] = self[j]
        self[j] = tmp
    }
}

// 这个方法, 其实和 * 操作符做的事情是一样的, 不过是使用了 Swfit 里面的指针操作.
public func swap<T>(_ a: inout T, _ b: inout T) {
    // Semantically equivalent to (a, b) = (b, a).
    // Microoptimized to avoid retain/release traffic.
    let p1 = Builtin.addressof(&a)
    let p2 = Builtin.addressof(&b)
    
    // Take from P1.
    let tmp: T = Builtin.take(p1)
    // Transfer P2 into P1.
    Builtin.initialize(Builtin.take(p2) as T, p1)
    // Initialize P2.
    Builtin.initialize(tmp, p2)
}

