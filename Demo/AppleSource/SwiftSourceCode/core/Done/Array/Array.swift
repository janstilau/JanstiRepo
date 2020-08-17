/*
 Swfit 里面, 真实的存储空间, 建立在 _ContiguousArrayBuffer 这个类中.
 */
@frozen
public struct Array<Element>: _DestructorSafeContainer {
    #if _runtime(_ObjC)
    @usableFromInline
    internal typealias _Buffer = _ArrayBuffer<Element>
    #else
    @usableFromInline
    internal typealias _Buffer = _ContiguousArrayBuffer<Element>
    #endif
    
    @usableFromInline
    internal var _buffer: _Buffer // Array 里面, 实际上存储的, 仅仅只有这样一个值.
    
    @inlinable
    internal init(_buffer: _Buffer) {
        self._buffer = _buffer
    }
}

//===--- private helpers---------------------------------------------------===//
/*
 以下, 对于 Array 的操作, 都转移到了 Buffer 里面.
 */
extension Array {
    /// Returns `true` if the array is native and does not need a deferred
    /// type check.  May be hoisted by the optimizer, which means its
    /// results may be stale by the time they are used if there is an
    /// inout violation in user code.
    @inlinable
    @_semantics("array.props.isNativeTypeChecked")
    public // @testable
    func _hoistableIsNativeTypeChecked() -> Bool {
        return _buffer.arrayPropertyIsNativeTypeChecked
    }
    
    @inlinable
    @_semantics("array.get_count")
    internal func _getCount() -> Int {
        return _buffer.count
    }
    
    @inlinable
    @_semantics("array.get_capacity")
    internal func _getCapacity() -> Int {
        return _buffer.capacity
    }
    
    /*
     如果, Buffer 不是唯一的引用的话, 就会进行自身 Buffer 的复制工作.
     在修改方法里面, 需要调用这个方法.
     */
    @inlinable
    @_semantics("array.make_mutable")
    internal mutating func _makeMutableAndUnique() {
        if _slowPath(!_buffer.isMutableAndUniquelyReferenced()) {
            _buffer = _Buffer(copying: _buffer)
        }
    }
    
    @inlinable
    @inline(__always)
    internal func _checkSubscript_native(_ index: Int) {
        _ = _checkSubscript(index, wasNativeTypeChecked: true)
    }
    
    /// Check that the given `index` is valid for subscripting, i.e.
    /// `0 ≤ index < count`.
    @inlinable
    @_semantics("array.check_subscript")
    public // @testable
    func _checkSubscript(
        _ index: Int, wasNativeTypeChecked: Bool
    ) -> _DependenceToken {
        #if _runtime(_ObjC)
        _buffer._checkInoutAndNativeTypeCheckedBounds(
            index, wasNativeTypeChecked: wasNativeTypeChecked)
        #else
        _buffer._checkValidSubscript(index)
        #endif
        return _DependenceToken()
    }
    
    /// Check that the specified `index` is valid, i.e. `0 ≤ index ≤ count`.
    /*
     容器类的安全操作, 如果越界, 就抛出异常了.
     异常不会被捕捉, 直接引起崩溃.
     */
    @inlinable
    @_semantics("array.check_index")
    internal func _checkIndex(_ index: Int) {
        _precondition(index <= endIndex, "Array index is out of range")
        _precondition(index >= startIndex, "Negative Array index is out of range")
    }
    
    @_semantics("array.get_element")
    @inlinable // FIXME(inline-always)
    @inline(__always)
    public // @testable
    func _getElement(
        _ index: Int,
        wasNativeTypeChecked: Bool,
        matchingSubscriptCheck: _DependenceToken
    ) -> Element {
        #if _runtime(_ObjC)
        return _buffer.getElement(index, wasNativeTypeChecked: wasNativeTypeChecked)
        #else
        return _buffer.getElement(index)
        #endif
    }
    
    /*
     _buffer.subscriptBaseAddress 的返回值类型是 UnsafeMutablePointer<Element>,
     所以, + Index, 返回的新的 pointer, 是会考虑 element 的长度的.
     */
    @inlinable
    @_semantics("array.get_element_address")
    internal func _getElementAddress(_ index: Int) -> UnsafeMutablePointer<Element> {
        return _buffer.subscriptBaseAddress + index
    }
}

extension Array: _ArrayProtocol {
    /// The total number of elements that the array can contain without
    /// allocating new storage.
    ///
    /// Every array reserves a specific amount of memory to hold its contents.
    /// When you add elements to an array and that array begins to exceed its
    /// reserved capacity, the array allocates a larger region of memory and
    /// copies its elements into the new storage. The new storage is a multiple
    /// of the old storage's size. This exponential growth strategy means that
    /// appending an element happens in constant time, averaging the performance
    /// of many append operations. Append operations that trigger reallocation
    /// have a performance cost, but they occur less and less often as the array
    /// grows larger.
    ///
    /// The following example creates an array of integers from an array literal,
    /// then appends the elements of another collection. Before appending, the
    /// array allocates new storage that is large enough store the resulting
    /// elements.
    ///
    ///     var numbers = [10, 20, 30, 40, 50]
    ///     // numbers.count == 5
    ///     // numbers.capacity == 5
    ///
    ///     numbers.append(contentsOf: stride(from: 60, through: 100, by: 10))
    ///     // numbers.count == 10
    ///     // numbers.capacity == 12
    /*
     这里, 增加了一层抽象, _getCapacity 会根据 buffer 的 特性, 进行不同的访问.
     */
    @inlinable
    public var capacity: Int {
        return _getCapacity()
    }
    
    /// An object that guarantees the lifetime of this array's elements.
    @inlinable
    public // @testable
    var _owner: AnyObject? {
        @inlinable // FIXME(inline-always)
        @inline(__always)
        get {
            return _buffer.owner      
        }
    }
    
    /// If the elements are stored contiguously, a pointer to the first
    /// element. Otherwise, `nil`.
    @inlinable
    public var _baseAddressIfContiguous: UnsafeMutablePointer<Element>? {
        @inline(__always) // FIXME(TODO: JIRA): Hack around test failure
        get { return _buffer.firstElementAddressIfContiguous }
    }
}

/*
 数组, 对于 Colleciton 的支持.
 */
extension Array: RandomAccessCollection, MutableCollection {
    public typealias Index = Int
    
    public typealias Indices = Range<Int>
    
    /*
     IndexingIterator, 直接利用 Colleciton 的 api, 做 sequence 的适配.
     */
    public typealias Iterator = IndexingIterator<Array>
    
    @inlinable
    public var startIndex: Int {
        return 0
    }
    
    @inlinable
    public var endIndex: Int {
        @inlinable
        get {
            return _getCount()
        }
    }
    
    /*
     index(after i: Index) -> Index 是非常重要的方法, 几乎每个容器类, 都要去专门设计一下这个方法.
     */
    @inlinable
    public func index(after i: Int) -> Int {
        return i + 1
    }
    
    @inlinable
    public func formIndex(after i: inout Int) {
        i += 1
    }
    
    @inlinable
    public func index(before i: Int) -> Int {
        return i - 1
    }
    
    @inlinable
    public func formIndex(before i: inout Int) {
        i -= 1
    }
    
    @inlinable
    public func index(_ i: Int, offsetBy distance: Int) -> Int {
        return i + distance
    }
    
    @inlinable
    public func index(
        _ i: Int,
        offsetBy distance: Int,
        limitedBy limit: Int
    ) -> Int? {
        let l = limit - i
        if distance > 0 ? l >= 0 && l < distance :
            l <= 0 && distance < l {
            return nil
        }
        return i + distance
    }
    
    @inlinable
    public func distance(from start: Int, to end: Int) -> Int {
        return end - start
    }
    
    @inlinable
    public func _failEarlyRangeCheck(_ index: Int, bounds: Range<Int>) {
        // NOTE: This method is a no-op for performance reasons.
    }
    
    @inlinable
    public func _failEarlyRangeCheck(_ range: Range<Int>, bounds: Range<Int>) {
        // NOTE: This method is a no-op for performance reasons.
    }
    
    @inlinable
    public subscript(index: Int) -> Element {
        get {
            // This call may be hoisted or eliminated by the optimizer.  If
            // there is an inout violation, this value may be stale so needs to be
            // checked again below.
            let wasNativeTypeChecked = _hoistableIsNativeTypeChecked()
            
            // Make sure the index is in range and wasNativeTypeChecked is
            // still valid.
            let token = _checkSubscript(
                index, wasNativeTypeChecked: wasNativeTypeChecked)
            
            return _getElement(
                index, wasNativeTypeChecked: wasNativeTypeChecked,
                matchingSubscriptCheck: token)
        }
        _modify {
            _makeMutableAndUnique() // makes the array native, too
            _checkSubscript_native(index)
            let address = _buffer.subscriptBaseAddress + index
            yield &address.pointee
        }
    }
    
    @inlinable
    public subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        get {
            _checkIndex(bounds.lowerBound)
            _checkIndex(bounds.upperBound)
            return ArraySlice(_buffer: _buffer[bounds])
        }
        set(rhs) {
            _checkIndex(bounds.lowerBound)
            _checkIndex(bounds.upperBound)
            // If the replacement buffer has same identity, and the ranges match,
            // then this was a pinned in-place modification, nothing further needed.
            if self[bounds]._buffer.identity != rhs._buffer.identity
                || bounds != rhs.startIndex..<rhs.endIndex {
                self.replaceSubrange(bounds, with: rhs)
            }
        }
    }
    
    /// The number of elements in the array.
    @inlinable
    public var count: Int {
        return _getCount()
    }
}

extension Array: RangeReplaceableCollection {
    /// Creates a new, empty array.
    ///
    /// This is equivalent to initializing with an empty array literal.
    /// For example:
    ///
    ///     var emptyArray = Array<Int>()
    ///     print(emptyArray.isEmpty)
    ///     // Prints "true"
    ///
    ///     emptyArray = []
    ///     print(emptyArray.isEmpty)
    ///     // Prints "true"
    @inlinable
    @_semantics("array.init.empty")
    public init() {
        _buffer = _Buffer()
    }
    
    /// Creates an array containing the elements of a sequence.
    ///
    /// You can use this initializer to create an array from any other type that
    /// conforms to the `Sequence` protocol. For example, you might want to
    /// create an array with the integers from 1 through 7. Use this initializer
    /// around a range instead of typing all those numbers in an array literal.
    ///
    ///     let numbers = Array(1...7)
    ///     print(numbers)
    ///     // Prints "[1, 2, 3, 4, 5, 6, 7]"
    ///
    /// You can also use this initializer to convert a complex sequence or
    /// collection type back to an array. For example, the `keys` property of
    /// a dictionary isn't an array with its own storage, it's a collection
    /// that maps its elements from the dictionary only when they're
    /// accessed, saving the time and space needed to allocate an array. If
    /// you need to pass those keys to a method that takes an array, however,
    /// use this initializer to convert that list from its type of
    /// `LazyMapCollection<Dictionary<String, Int>, Int>` to a simple
    /// `[String]`.
    ///
    ///     func cacheImagesWithNames(names: [String]) {
    ///         // custom image loading and caching
    ///      }
    ///
    ///     let namedHues: [String: Int] = ["Vermillion": 18, "Magenta": 302,
    ///             "Gold": 50, "Cerise": 320]
    ///     let colorNames = Array(namedHues.keys)
    ///     cacheImagesWithNames(colorNames)
    ///
    ///     print(colorNames)
    ///     // Prints "["Gold", "Cerise", "Magenta", "Vermillion"]"
    ///
    /// - Parameter s: The sequence of elements to turn into an array.
    @inlinable
    public init<S: Sequence>(_ s: S) where S.Element == Element {
        self = Array(
            _buffer: _Buffer(
                _buffer: s._copyToContiguousArray()._buffer,
                shiftedToStartIndex: 0))
    }
    
    /// Creates a new array containing the specified number of a single, repeated
    /// value.
    ///
    /// Here's an example of creating an array initialized with five strings
    /// containing the letter *Z*.
    ///
    ///     let fiveZs = Array(repeating: "Z", count: 5)
    ///     print(fiveZs)
    ///     // Prints "["Z", "Z", "Z", "Z", "Z"]"
    ///
    /// - Parameters:
    ///   - repeatedValue: The element to repeat.
    ///   - count: The number of times to repeat the value passed in the
    ///     `repeating` parameter. `count` must be zero or greater.
    @inlinable
    @_semantics("array.init")
    public init(repeating repeatedValue: Element, count: Int) {
        
        /*
         当, count 的值已经固定的时候, _allocateUninitialized 会先生成相应大小的内存的值. 然后通过指针直接对相应的位置进行设值的操作.
         */
        var p: UnsafeMutablePointer<Element>
        (self, p) = Array._allocateUninitialized(count)
        
        for _ in 0..<count {
            p.initialize(to: repeatedValue)
            p += 1
        }
    }
    
    @inline(never)
    @usableFromInline
    internal static func _allocateBufferUninitialized(
        minimumCapacity: Int
    ) -> _Buffer {
        let newBuffer = _ContiguousArrayBuffer<Element>(
            _uninitializedCount: 0, minimumCapacity: minimumCapacity)
        return _Buffer(_buffer: newBuffer, shiftedToStartIndex: 0)
    }
    
    /// Construct an Array of `count` uninitialized elements.
    @inlinable
    internal init(_uninitializedCount count: Int) {
        _precondition(count >= 0, "Can't construct Array with count < 0")
        // Note: Sinking this constructor into an else branch below causes an extra
        // Retain/Release.
        _buffer = _Buffer()
        if count > 0 {
            // Creating a buffer instead of calling reserveCapacity saves doing an
            // unnecessary uniqueness check. We disable inlining here to curb code
            // growth.
            _buffer = Array._allocateBufferUninitialized(minimumCapacity: count)
            _buffer.count = count
        }
        // Can't store count here because the buffer might be pointing to the
        // shared empty array.
    }
    
    /// Entry point for `Array` literal construction; builds and returns
    /// an Array of `count` uninitialized elements.
    @inlinable
    @_semantics("array.uninitialized")
    internal static func _allocateUninitialized(
        _ count: Int
    ) -> (Array, UnsafeMutablePointer<Element>) {
        let result = Array(_uninitializedCount: count)
        return (result, result._buffer.firstElementAddress)
    }
    
    
    /// Returns an Array of `count` uninitialized elements using the
    /// given `storage`, and a pointer to uninitialized memory for the
    /// first element.
    ///
    /// - Precondition: `storage is _ContiguousArrayStorage`.
    @inlinable
    @_semantics("array.uninitialized")
    internal static func _adoptStorage(
        _ storage: __owned _ContiguousArrayStorage<Element>, count: Int
    ) -> (Array, UnsafeMutablePointer<Element>) {
        
        let innerBuffer = _ContiguousArrayBuffer<Element>(
            count: count,
            storage: storage)
        
        return (
            Array(
                _buffer: _Buffer(_buffer: innerBuffer, shiftedToStartIndex: 0)),
            innerBuffer.firstElementAddress)
    }
    
    /// Entry point for aborting literal construction: deallocates
    /// an Array containing only uninitialized elements.
    @inlinable
    internal mutating func _deallocateUninitialized() {
        // Set the count to zero and just release as normal.
        // Somewhat of a hack.
        _buffer.count = 0
    }
    
    //===--- basic mutations ------------------------------------------------===//
    
    
    /// Reserves enough space to store the specified number of elements.
    ///
    /// If you are adding a known number of elements to an array, use this method
    /// to avoid multiple reallocations. This method ensures that the array has
    /// unique, mutable, contiguous storage, with space allocated for at least
    /// the requested number of elements.
    ///
    /// Calling the `reserveCapacity(_:)` method on an array with bridged storage
    /// triggers a copy to contiguous storage even if the existing storage
    /// has room to store `minimumCapacity` elements.
    ///
    /// For performance reasons, the size of the newly allocated storage might be
    /// greater than the requested capacity. Use the array's `capacity` property
    /// to determine the size of the new storage.
    ///
    /// Preserving an Array's Geometric Growth Strategy
    /// ===============================================
    ///
    /// If you implement a custom data structure backed by an array that grows
    /// dynamically, naively calling the `reserveCapacity(_:)` method can lead
    /// to worse than expected performance. Arrays need to follow a geometric
    /// allocation pattern for appending elements to achieve amortized
    /// constant-time performance. The `Array` type's `append(_:)` and
    /// `append(contentsOf:)` methods take care of this detail for you, but
    /// `reserveCapacity(_:)` allocates only as much space as you tell it to
    /// (padded to a round value), and no more. This avoids over-allocation, but
    /// can result in insertion not having amortized constant-time performance.
    ///
    /// The following code declares `values`, an array of integers, and the
    /// `addTenQuadratic()` function, which adds ten more values to the `values`
    /// array on each call.
    ///
    ///       var values: [Int] = [0, 1, 2, 3]
    ///
    ///       // Don't use 'reserveCapacity(_:)' like this
    ///       func addTenQuadratic() {
    ///           let newCount = values.count + 10
    ///           values.reserveCapacity(newCount)
    ///           for n in values.count..<newCount {
    ///               values.append(n)
    ///           }
    ///       }
    ///
    /// The call to `reserveCapacity(_:)` increases the `values` array's capacity
    /// by exactly 10 elements on each pass through `addTenQuadratic()`, which
    /// is linear growth. Instead of having constant time when averaged over
    /// many calls, the function may decay to performance that is linear in
    /// `values.count`. This is almost certainly not what you want.
    ///
    /// In cases like this, the simplest fix is often to simply remove the call
    /// to `reserveCapacity(_:)`, and let the `append(_:)` method grow the array
    /// for you.
    ///
    ///       func addTen() {
    ///           let newCount = values.count + 10
    ///           for n in values.count..<newCount {
    ///               values.append(n)
    ///           }
    ///       }
    ///
    /// If you need more control over the capacity of your array, implement your
    /// own geometric growth strategy, passing the size you compute to
    /// `reserveCapacity(_:)`.
    ///
    /// - Parameter minimumCapacity: The requested number of elements to store.
    ///
    /// - Complexity: O(*n*), where *n* is the number of elements in the array.
    @inlinable
    @_semantics("array.mutate_unknown")
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        if _buffer.requestUniqueMutableBackingBuffer(
            minimumCapacity: minimumCapacity) == nil {
            
            let newBuffer = _ContiguousArrayBuffer<Element>(
                _uninitializedCount: count, minimumCapacity: minimumCapacity)
            
            _buffer._copyContents(
                subRange: _buffer.indices,
                initializing: newBuffer.firstElementAddress)
            _buffer = _Buffer(
                _buffer: newBuffer, shiftedToStartIndex: _buffer.startIndex)
        }
        _internalInvariant(capacity >= minimumCapacity)
    }
    
    /// Copy the contents of the current buffer to a new unique mutable buffer.
    /// The count of the new buffer is set to `oldCount`, the capacity of the
    /// new buffer is big enough to hold 'oldCount' + 1 elements.
    @inline(never)
    @inlinable // @specializable
    internal mutating func _copyToNewBuffer(oldCount: Int) {
        let newCount = oldCount + 1
        var newBuffer = _buffer._forceCreateUniqueMutableBuffer(
            countForNewBuffer: oldCount, minNewCapacity: newCount)
        _buffer._arrayOutOfPlaceUpdate(&newBuffer, oldCount, 0)
    }
    
    /*
     * 这里, 就是判断是不是唯一索引, 然后进行 copy 操作.
     */
    @inlinable
    @_semantics("array.make_mutable")
    internal mutating func _makeUniqueAndReserveCapacityIfNotUnique() {
        if _slowPath(!_buffer.isMutableAndUniquelyReferenced()) {
            _copyToNewBuffer(oldCount: _buffer.count)
        }
    }
    
    @inlinable
    @_semantics("array.mutate_unknown")
    internal mutating func _reserveCapacityAssumingUniqueBuffer(oldCount: Int) {
        // This is a performance optimization. This code used to be in an ||
        // statement in the _internalInvariant below.
        //
        //   _internalInvariant(_buffer.capacity == 0 ||
        //                _buffer.isMutableAndUniquelyReferenced())
        //
        // SR-6437
        let capacity = _buffer.capacity == 0
        
        // Due to make_mutable hoisting the situation can arise where we hoist
        // _makeMutableAndUnique out of loop and use it to replace
        // _makeUniqueAndReserveCapacityIfNotUnique that preceeds this call. If the
        // array was empty _makeMutableAndUnique does not replace the empty array
        // buffer by a unique buffer (it just replaces it by the empty array
        // singleton).
        // This specific case is okay because we will make the buffer unique in this
        // function because we request a capacity > 0 and therefore _copyToNewBuffer
        // will be called creating a new buffer.
        _internalInvariant(capacity ||
            _buffer.isMutableAndUniquelyReferenced())
        
        if _slowPath(oldCount + 1 > _buffer.capacity) {
            _copyToNewBuffer(oldCount: oldCount)
        }
    }
    
    @inlinable
    @_semantics("array.mutate_unknown")
    internal mutating func _appendElementAssumeUniqueAndCapacity(
        _ oldCount: Int,
        newElement: __owned Element
    ) {
        _internalInvariant(_buffer.isMutableAndUniquelyReferenced())
        _internalInvariant(_buffer.capacity >= _buffer.count + 1)
        
        _buffer.count = oldCount + 1
        (_buffer.firstElementAddress + oldCount).initialize(to: newElement)
    }
    
    /// Adds a new element at the end of the array.
    ///
    /// Use this method to append a single element to the end of a mutable array.
    ///
    ///     var numbers = [1, 2, 3, 4, 5]
    ///     numbers.append(100)
    ///     print(numbers)
    ///     // Prints "[1, 2, 3, 4, 5, 100]"
    ///
    /// Because arrays increase their allocated capacity using an exponential
    /// strategy, appending a single element to an array is an O(1) operation
    /// when averaged over many calls to the `append(_:)` method. When an array
    /// has additional capacity and is not sharing its storage with another
    /// instance, appending an element is O(1). When an array needs to
    /// reallocate storage before appending or its storage is shared with
    /// another copy, appending is O(*n*), where *n* is the length of the array.
    ///
    /// - Parameter newElement: The element to append to the array.
    ///
    /// - Complexity: O(1) on average, over many calls to `append(_:)` on the
    ///   same array.
    @inlinable
    @_semantics("array.append_element")
    public mutating func append(_ newElement: __owned Element) {
        _makeUniqueAndReserveCapacityIfNotUnique()
        let oldCount = _getCount()
        _reserveCapacityAssumingUniqueBuffer(oldCount: oldCount)
        _appendElementAssumeUniqueAndCapacity(oldCount, newElement: newElement)
    }
    
    /// Adds the elements of a sequence to the end of the array.
    ///
    /// Use this method to append the elements of a sequence to the end of this
    /// array. This example appends the elements of a `Range<Int>` instance
    /// to an array of integers.
    ///
    ///     var numbers = [1, 2, 3, 4, 5]
    ///     numbers.append(contentsOf: 10...15)
    ///     print(numbers)
    ///     // Prints "[1, 2, 3, 4, 5, 10, 11, 12, 13, 14, 15]"
    ///
    /// - Parameter newElements: The elements to append to the array.
    ///
    /// - Complexity: O(*m*) on average, where *m* is the length of
    ///   `newElements`, over many calls to `append(contentsOf:)` on the same
    ///   array.
    @inlinable
    @_semantics("array.append_contentsOf")
    public mutating func append<S: Sequence>(contentsOf newElements: __owned S)
        where S.Element == Element {
            
            let newElementsCount = newElements.underestimatedCount
            reserveCapacityForAppend(newElementsCount: newElementsCount)
            
            let oldCount = self.count
            let startNewElements = _buffer.firstElementAddress + oldCount
            let buf = UnsafeMutableBufferPointer(
                start: startNewElements, 
                count: self.capacity - oldCount)
            
            let (remainder,writtenUpTo) = buf.initialize(from: newElements)
            
            // trap on underflow from the sequence's underestimate:
            let writtenCount = buf.distance(from: buf.startIndex, to: writtenUpTo)
            _precondition(newElementsCount <= writtenCount, 
                          "newElements.underestimatedCount was an overestimate")
            // can't check for overflow as sequences can underestimate
            
            // This check prevents a data race writting to _swiftEmptyArrayStorage
            if writtenCount > 0 {
                _buffer.count += writtenCount
            }
            
            if writtenUpTo == buf.endIndex {
                // there may be elements that didn't fit in the existing buffer,
                // append them in slow sequence-only mode
                _buffer._arrayAppendSequence(IteratorSequence(remainder))
            }
    }
    
    @inlinable
    @_semantics("array.reserve_capacity_for_append")
    internal mutating func reserveCapacityForAppend(newElementsCount: Int) {
        let oldCount = self.count
        let oldCapacity = self.capacity
        let newCount = oldCount + newElementsCount
        
        // Ensure uniqueness, mutability, and sufficient storage.  Note that
        // for consistency, we need unique self even if newElements is empty.
        self.reserveCapacity(
            newCount > oldCapacity ?
                Swift.max(newCount, _growArrayCapacity(oldCapacity))
                : newCount)
    }
    
    @inlinable
    public mutating func _customRemoveLast() -> Element? {
        let newCount = _getCount() - 1
        _precondition(newCount >= 0, "Can't removeLast from an empty Array")
        _makeUniqueAndReserveCapacityIfNotUnique()
        let pointer = (_buffer.firstElementAddress + newCount)
        let element = pointer.move()
        _buffer.count = newCount
        return element
    }
    
    /// Removes and returns the element at the specified position.
    ///
    /// All the elements following the specified position are moved up to
    /// close the gap.
    ///
    ///     var measurements: [Double] = [1.1, 1.5, 2.9, 1.2, 1.5, 1.3, 1.2]
    ///     let removed = measurements.remove(at: 2)
    ///     print(measurements)
    ///     // Prints "[1.1, 1.5, 1.2, 1.5, 1.3, 1.2]"
    ///
    /// - Parameter index: The position of the element to remove. `index` must
    ///   be a valid index of the array.
    /// - Returns: The element at the specified index.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the array.
    @inlinable
    @discardableResult
    public mutating func remove(at index: Int) -> Element {
        _precondition(index < endIndex, "Index out of range")
        _precondition(index >= startIndex, "Index out of range")
        _makeUniqueAndReserveCapacityIfNotUnique()
        let newCount = _getCount() - 1
        let pointer = (_buffer.firstElementAddress + index)
        let result = pointer.move()
        pointer.moveInitialize(from: pointer + 1, count: newCount - index)
        _buffer.count = newCount
        return result
    }
    
    /// Inserts a new element at the specified position.
    ///
    /// The new element is inserted before the element currently at the specified
    /// index. If you pass the array's `endIndex` property as the `index`
    /// parameter, the new element is appended to the array.
    ///
    ///     var numbers = [1, 2, 3, 4, 5]
    ///     numbers.insert(100, at: 3)
    ///     numbers.insert(200, at: numbers.endIndex)
    ///
    ///     print(numbers)
    ///     // Prints "[1, 2, 3, 100, 4, 5, 200]"
    ///
    /// - Parameter newElement: The new element to insert into the array.
    /// - Parameter i: The position at which to insert the new element.
    ///   `index` must be a valid index of the array or equal to its `endIndex`
    ///   property.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the array. If
    ///   `i == endIndex`, this method is equivalent to `append(_:)`.
    @inlinable
    public mutating func insert(_ newElement: __owned Element, at i: Int) {
        _checkIndex(i)
        self.replaceSubrange(i..<i, with: CollectionOfOne(newElement))
    }
    
    /// Removes all elements from the array.
    ///
    /// - Parameter keepCapacity: Pass `true` to keep the existing capacity of
    ///   the array after removing its elements. The default value is
    ///   `false`.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the array.
    @inlinable
    public mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
        if !keepCapacity {
            _buffer = _Buffer()
        }
        else {
            self.replaceSubrange(indices, with: EmptyCollection())
        }
    }
    
    //===--- algorithms -----------------------------------------------------===//
    
    @inlinable
    public mutating func _withUnsafeMutableBufferPointerIfSupported<R>(
        _ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R
    ) rethrows -> R? {
        return try withUnsafeMutableBufferPointer {
            (bufferPointer) -> R in
            return try body(&bufferPointer)
        }
    }
    
    @inlinable
    public mutating func withContiguousMutableStorageIfAvailable<R>(
        _ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R
    ) rethrows -> R? {
        return try withUnsafeMutableBufferPointer {
            (bufferPointer) -> R in
            return try body(&bufferPointer)
        }
    }
    
    @inlinable
    public func withContiguousStorageIfAvailable<R>(
        _ body: (UnsafeBufferPointer<Element>) throws -> R
    ) rethrows -> R? {
        return try withUnsafeBufferPointer {
            (bufferPointer) -> R in
            return try body(bufferPointer)
        }
    }
    
    @inlinable
    public __consuming func _copyToContiguousArray() -> ContiguousArray<Element> {
        if let n = _buffer.requestNativeBuffer() {
            return ContiguousArray(_buffer: n)
        }
        return _copyCollectionToContiguousArray(self)
    }
}

// Implementations of + and += for same-type arrays. This combined
// with the operator declarations for these operators designating this
// type as a place to prefer this operator help the expression type
// checker speed up cases where there is a large number of uses of the
// operator in the same expression.
extension Array {
    @inlinable
    public static func + (lhs: Array, rhs: Array) -> Array {
        var lhs = lhs
        lhs.append(contentsOf: rhs)
        return lhs
    }
    
    @inlinable
    public static func += (lhs: inout Array, rhs: Array) {
        lhs.append(contentsOf: rhs)
    }
}

extension Array: CustomStringConvertible, CustomDebugStringConvertible {
    /// A textual representation of the array and its elements.
    public var description: String {
        return _makeCollectionDescription()
    }
    
    /// A textual representation of the array and its elements, suitable for
    /// debugging.
    public var debugDescription: String {
        // Always show sugared representation for Arrays.
        return _makeCollectionDescription()
    }
}

extension Array {
    @usableFromInline @_transparent
    internal func _cPointerArgs() -> (AnyObject?, UnsafeRawPointer?) {
        let p = _baseAddressIfContiguous
        if _fastPath(p != nil || isEmpty) {
            return (_owner, UnsafeRawPointer(p))
        }
        let n = ContiguousArray(self._buffer)._buffer
        return (n.owner, UnsafeRawPointer(n.firstElementAddress))
    }
}

extension Array {
    /// Implementation for Array(unsafeUninitializedCapacity:initializingWith:)
    /// and ContiguousArray(unsafeUninitializedCapacity:initializingWith:)
    @inlinable
    internal init(
        _unsafeUninitializedCapacity: Int,
        initializingWith initializer: (
        _ buffer: inout UnsafeMutableBufferPointer<Element>,
        _ initializedCount: inout Int) throws -> Void
    ) rethrows {
        var firstElementAddress: UnsafeMutablePointer<Element>
        (self, firstElementAddress) =
            Array._allocateUninitialized(_unsafeUninitializedCapacity)
        
        var initializedCount = 0
        var buffer = UnsafeMutableBufferPointer<Element>(
            start: firstElementAddress, count: _unsafeUninitializedCapacity)
        defer {
            // Update self.count even if initializer throws an error.
            _precondition(
                initializedCount <= _unsafeUninitializedCapacity,
                "Initialized count set to greater than specified capacity."
            )
            _precondition(
                buffer.baseAddress == firstElementAddress,
                "Can't reassign buffer in Array(unsafeUninitializedCapacity:initializingWith:)"
            )
            self._buffer.count = initializedCount
        }
        try initializer(&buffer, &initializedCount)
    }
    
    /// Creates an array with the specified capacity, then calls the given
    /// closure with a buffer covering the array's uninitialized memory.
    ///
    /// Inside the closure, set the `initializedCount` parameter to the number of
    /// elements that are initialized by the closure. The memory in the range
    /// `buffer[0..<initializedCount]` must be initialized at the end of the
    /// closure's execution, and the memory in the range
    /// `buffer[initializedCount...]` must be uninitialized. This postcondition
    /// must hold even if the `initializer` closure throws an error.
    ///
    /// - Note: While the resulting array may have a capacity larger than the
    ///   requested amount, the buffer passed to the closure will cover exactly
    ///   the requested number of elements.
    ///
    /// - Parameters:
    ///   - unsafeUninitializedCapacity: The number of elements to allocate
    ///     space for in the new array.
    ///   - initializer: A closure that initializes elements and sets the count
    ///     of the new array.
    ///     - Parameters:
    ///       - buffer: A buffer covering uninitialized memory with room for the
    ///         specified number of of elements.
    ///       - initializedCount: The count of initialized elements in the array,
    ///         which begins as zero. Set `initializedCount` to the number of
    ///         elements you initialize.
    @_alwaysEmitIntoClient @inlinable
    public init(
        unsafeUninitializedCapacity: Int,
        initializingWith initializer: (
        _ buffer: inout UnsafeMutableBufferPointer<Element>,
        _ initializedCount: inout Int) throws -> Void
    ) rethrows {
        self = try Array(
            _unsafeUninitializedCapacity: unsafeUninitializedCapacity,
            initializingWith: initializer)
    }
    
    /// Calls a closure with a pointer to the array's contiguous storage.
    ///
    /// Often, the optimizer can eliminate bounds checks within an array
    /// algorithm, but when that fails, invoking the same algorithm on the
    /// buffer pointer passed into your closure lets you trade safety for speed.
    ///
    /// The following example shows how you can iterate over the contents of the
    /// buffer pointer:
    ///
    ///     let numbers = [1, 2, 3, 4, 5]
    ///     let sum = numbers.withUnsafeBufferPointer { buffer -> Int in
    ///         var result = 0
    ///         for i in stride(from: buffer.startIndex, to: buffer.endIndex, by: 2) {
    ///             result += buffer[i]
    ///         }
    ///         return result
    ///     }
    ///     // 'sum' == 9
    ///
    /// The pointer passed as an argument to `body` is valid only during the
    /// execution of `withUnsafeBufferPointer(_:)`. Do not store or return the
    /// pointer for later use.
    ///
    /// - Parameter body: A closure with an `UnsafeBufferPointer` parameter that
    ///   points to the contiguous storage for the array.  If no such storage exists, it is created. If
    ///   `body` has a return value, that value is also used as the return value
    ///   for the `withUnsafeBufferPointer(_:)` method. The pointer argument is
    ///   valid only for the duration of the method's execution.
    /// - Returns: The return value, if any, of the `body` closure parameter.
    @inlinable
    public func withUnsafeBufferPointer<R>(
        _ body: (UnsafeBufferPointer<Element>) throws -> R
    ) rethrows -> R {
        return try _buffer.withUnsafeBufferPointer(body)
    }
    
    /// Calls the given closure with a pointer to the array's mutable contiguous
    /// storage.
    ///
    /// Often, the optimizer can eliminate bounds checks within an array
    /// algorithm, but when that fails, invoking the same algorithm on the
    /// buffer pointer passed into your closure lets you trade safety for speed.
    ///
    /// The following example shows how modifying the contents of the
    /// `UnsafeMutableBufferPointer` argument to `body` alters the contents of
    /// the array:
    ///
    ///     var numbers = [1, 2, 3, 4, 5]
    ///     numbers.withUnsafeMutableBufferPointer { buffer in
    ///         for i in stride(from: buffer.startIndex, to: buffer.endIndex - 1, by: 2) {
    ///             buffer.swapAt(i, i + 1)
    ///         }
    ///     }
    ///     print(numbers)
    ///     // Prints "[2, 1, 4, 3, 5]"
    ///
    /// The pointer passed as an argument to `body` is valid only during the
    /// execution of `withUnsafeMutableBufferPointer(_:)`. Do not store or
    /// return the pointer for later use.
    ///
    /// - Warning: Do not rely on anything about the array that is the target of
    ///   this method during execution of the `body` closure; it might not
    ///   appear to have its correct value. Instead, use only the
    ///   `UnsafeMutableBufferPointer` argument to `body`.
    ///
    /// - Parameter body: A closure with an `UnsafeMutableBufferPointer`
    ///   parameter that points to the contiguous storage for the array.
    ///    If no such storage exists, it is created. If `body` has a return value, that value is also
    ///   used as the return value for the `withUnsafeMutableBufferPointer(_:)`
    ///   method. The pointer argument is valid only for the duration of the
    ///   method's execution.
    /// - Returns: The return value, if any, of the `body` closure parameter.
    @_semantics("array.withUnsafeMutableBufferPointer")
    @inlinable // FIXME(inline-always)
    @inline(__always) // Performance: This method should get inlined into the
    // caller such that we can combine the partial apply with the apply in this
    // function saving on allocating a closure context. This becomes unnecessary
    // once we allocate noescape closures on the stack.
    public mutating func withUnsafeMutableBufferPointer<R>(
        _ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R
    ) rethrows -> R {
        let count = self.count
        // Ensure unique storage
        _buffer._outlinedMakeUniqueBuffer(bufferCount: count)
        
        // Ensure that body can't invalidate the storage or its bounds by
        // moving self into a temporary working array.
        // NOTE: The stack promotion optimization that keys of the
        // "array.withUnsafeMutableBufferPointer" semantics annotation relies on the
        // array buffer not being able to escape in the closure. It can do this
        // because we swap the array buffer in self with an empty buffer here. Any
        // escape via the address of self in the closure will therefore escape the
        // empty array.
        
        var work = Array()
        (work, self) = (self, work)
        
        // Create an UnsafeBufferPointer over work that we can pass to body
        let pointer = work._buffer.firstElementAddress
        var inoutBufferPointer = UnsafeMutableBufferPointer(
            start: pointer, count: count)
        
        // Put the working array back before returning.
        defer {
            _precondition(
                inoutBufferPointer.baseAddress == pointer &&
                    inoutBufferPointer.count == count,
                "Array withUnsafeMutableBufferPointer: replacing the buffer is not allowed")
            
            (work, self) = (self, work)
        }
        
        // Invoke the body.
        return try body(&inoutBufferPointer)
    }
    
    @inlinable
    public __consuming func _copyContents(
        initializing buffer: UnsafeMutableBufferPointer<Element>
    ) -> (Iterator,UnsafeMutableBufferPointer<Element>.Index) {
        
        guard !self.isEmpty else { return (makeIterator(),buffer.startIndex) }
        
        // It is not OK for there to be no pointer/not enough space, as this is
        // a precondition and Array never lies about its count.
        guard var p = buffer.baseAddress
            else { _preconditionFailure("Attempt to copy contents into nil buffer pointer") }
        _precondition(self.count <= buffer.count, 
                      "Insufficient space allocated to copy array contents")
        
        if let s = _baseAddressIfContiguous {
            p.initialize(from: s, count: self.count)
            // Need a _fixLifetime bracketing the _baseAddressIfContiguous getter
            // and all uses of the pointer it returns:
            _fixLifetime(self._owner)
        } else {
            for x in self {
                p.initialize(to: x)
                p += 1
            }
        }
        
        var it = IndexingIterator(_elements: self)
        it._position = endIndex
        return (it,buffer.index(buffer.startIndex, offsetBy: self.count))
    }
}

extension Array {
    /// Replaces a range of elements with the elements in the specified
    /// collection.
    ///
    /// This method has the effect of removing the specified range of elements
    /// from the array and inserting the new elements at the same location. The
    /// number of new elements need not match the number of elements being
    /// removed.
    ///
    /// In this example, three elements in the middle of an array of integers are
    /// replaced by the five elements of a `Repeated<Int>` instance.
    ///
    ///      var nums = [10, 20, 30, 40, 50]
    ///      nums.replaceSubrange(1...3, with: repeatElement(1, count: 5))
    ///      print(nums)
    ///      // Prints "[10, 1, 1, 1, 1, 1, 50]"
    ///
    /// If you pass a zero-length range as the `subrange` parameter, this method
    /// inserts the elements of `newElements` at `subrange.startIndex`. Calling
    /// the `insert(contentsOf:at:)` method instead is preferred.
    ///
    /// Likewise, if you pass a zero-length collection as the `newElements`
    /// parameter, this method removes the elements in the given subrange
    /// without replacement. Calling the `removeSubrange(_:)` method instead is
    /// preferred.
    ///
    /// - Parameters:
    ///   - subrange: The subrange of the array to replace. The start and end of
    ///     a subrange must be valid indices of the array.
    ///   - newElements: The new elements to add to the array.
    ///
    /// - Complexity: O(*n* + *m*), where *n* is length of the array and
    ///   *m* is the length of `newElements`. If the call to this method simply
    ///   appends the contents of `newElements` to the array, this method is
    ///   equivalent to `append(contentsOf:)`.
    @inlinable
    @_semantics("array.mutate_unknown")
    public mutating func replaceSubrange<C>(
        _ subrange: Range<Int>,
        with newElements: __owned C
    ) where C: Collection, C.Element == Element {
        _precondition(subrange.lowerBound >= self._buffer.startIndex,
                      "Array replace: subrange start is negative")
        
        _precondition(subrange.upperBound <= _buffer.endIndex,
                      "Array replace: subrange extends past the end")
        
        let oldCount = _buffer.count
        let eraseCount = subrange.count
        let insertCount = newElements.count
        let growth = insertCount - eraseCount
        
        if _buffer.requestUniqueMutableBackingBuffer(
            minimumCapacity: oldCount + growth) != nil {
            
            _buffer.replaceSubrange(
                subrange, with: insertCount, elementsOf: newElements)
        } else {
            _buffer._arrayOutOfPlaceReplace(subrange, with: newElements, count: insertCount)
        }
    }
}

extension Array: Equatable where Element: Equatable {
    /// Returns a Boolean value indicating whether two arrays contain the same
    /// elements in the same order.
    ///
    /// You can use the equal-to operator (`==`) to compare any two arrays
    /// that store the same, `Equatable`-conforming element type.
    ///
    /// - Parameters:
    ///   - lhs: An array to compare.
    ///   - rhs: Another array to compare.
    @inlinable
    public static func ==(lhs: Array<Element>, rhs: Array<Element>) -> Bool {
        let lhsCount = lhs.count
        if lhsCount != rhs.count {
            return false
        }
        
        // Test referential equality.
        if lhsCount == 0 || lhs._buffer.identity == rhs._buffer.identity {
            return true
        }
        
        
        _internalInvariant(lhs.startIndex == 0 && rhs.startIndex == 0)
        _internalInvariant(lhs.endIndex == lhsCount && rhs.endIndex == lhsCount)
        
        // We know that lhs.count == rhs.count, compare element wise.
        for idx in 0..<lhsCount {
            if lhs[idx] != rhs[idx] {
                return false
            }
        }
        
        return true
    }
}

extension Array: Hashable where Element: Hashable {
    /// Hashes the essential components of this value by feeding them into the
    /// given hasher.
    ///
    /// - Parameter hasher: The hasher to use when combining the components
    ///   of this instance.
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count) // discriminator
        for element in self {
            hasher.combine(element)
        }
    }
}

extension Array {
    /// Calls the given closure with a pointer to the underlying bytes of the
    /// array's mutable contiguous storage.
    ///
    /// The array's `Element` type must be a *trivial type*, which can be copied
    /// with just a bit-for-bit copy without any indirection or
    /// reference-counting operations. Generally, native Swift types that do not
    /// contain strong or weak references are trivial, as are imported C structs
    /// and enums.
    ///
    /// The following example copies bytes from the `byteValues` array into
    /// `numbers`, an array of `Int`:
    ///
    ///     var numbers: [Int32] = [0, 0]
    ///     var byteValues: [UInt8] = [0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00]
    ///
    ///     numbers.withUnsafeMutableBytes { destBytes in
    ///         byteValues.withUnsafeBytes { srcBytes in
    ///             destBytes.copyBytes(from: srcBytes)
    ///         }
    ///     }
    ///     // numbers == [1, 2]
    ///
    /// The pointer passed as an argument to `body` is valid only for the
    /// lifetime of the closure. Do not escape it from the closure for later
    /// use.
    ///
    /// - Warning: Do not rely on anything about the array that is the target of
    ///   this method during execution of the `body` closure; it might not
    ///   appear to have its correct value. Instead, use only the
    ///   `UnsafeMutableRawBufferPointer` argument to `body`.
    ///
    /// - Parameter body: A closure with an `UnsafeMutableRawBufferPointer`
    ///   parameter that points to the contiguous storage for the array.
    ///    If no such storage exists, it is created. If `body` has a return value, that value is also
    ///   used as the return value for the `withUnsafeMutableBytes(_:)` method.
    ///   The argument is valid only for the duration of the closure's
    ///   execution.
    /// - Returns: The return value, if any, of the `body` closure parameter.
    @inlinable
    public mutating func withUnsafeMutableBytes<R>(
        _ body: (UnsafeMutableRawBufferPointer) throws -> R
    ) rethrows -> R {
        return try self.withUnsafeMutableBufferPointer {
            return try body(UnsafeMutableRawBufferPointer($0))
        }
    }
    
    /// Calls the given closure with a pointer to the underlying bytes of the
    /// array's contiguous storage.
    ///
    /// The array's `Element` type must be a *trivial type*, which can be copied
    /// with just a bit-for-bit copy without any indirection or
    /// reference-counting operations. Generally, native Swift types that do not
    /// contain strong or weak references are trivial, as are imported C structs
    /// and enums.
    ///
    /// The following example copies the bytes of the `numbers` array into a
    /// buffer of `UInt8`:
    ///
    ///     var numbers = [1, 2, 3]
    ///     var byteBuffer: [UInt8] = []
    ///     numbers.withUnsafeBytes {
    ///         byteBuffer.append(contentsOf: $0)
    ///     }
    ///     // byteBuffer == [1, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, ...]
    ///
    /// - Parameter body: A closure with an `UnsafeRawBufferPointer` parameter
    ///   that points to the contiguous storage for the array.
    ///    If no such storage exists, it is created. If `body` has a return value, that value is also
    ///   used as the return value for the `withUnsafeBytes(_:)` method. The
    ///   argument is valid only for the duration of the closure's execution.
    /// - Returns: The return value, if any, of the `body` closure parameter.
    @inlinable
    public func withUnsafeBytes<R>(
        _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R {
        return try self.withUnsafeBufferPointer {
            try body(UnsafeRawBufferPointer($0))
        }
    }
}

#if _runtime(_ObjC)
// We isolate the bridging of the Cocoa Array -> Swift Array here so that
// in the future, we can eagerly bridge the Cocoa array. We need this function
// to do the bridging in an ABI safe way. Even though this looks useless,
// DO NOT DELETE!
@usableFromInline internal
func _bridgeCocoaArray<T>(_ _immutableCocoaArray: AnyObject) -> Array<T> {
    return Array(_buffer: _ArrayBuffer(nsArray: _immutableCocoaArray))
}

extension Array {
    @inlinable
    public // @SPI(Foundation)
    func _bridgeToObjectiveCImpl() -> AnyObject {
        return _buffer._asCocoaArray()
    }
    
    /// Tries to downcast the source `NSArray` as our native buffer type.
    /// If it succeeds, creates a new `Array` around it and returns that.
    /// Returns `nil` otherwise.
    // Note: this function exists here so that Foundation doesn't have
    // to know Array's implementation details.
    @inlinable
    public static func _bridgeFromObjectiveCAdoptingNativeStorageOf(
        _ source: AnyObject
    ) -> Array? {
        // If source is deferred, we indirect to get its native storage
        let maybeNative = (source as? __SwiftDeferredNSArray)?._nativeStorage ?? source
        
        return (maybeNative as? _ContiguousArrayStorage<Element>).map {
            Array(_ContiguousArrayBuffer($0))
        }
    }
    
    /// Private initializer used for bridging.
    ///
    /// Only use this initializer when both conditions are true:
    ///
    /// * it is statically known that the given `NSArray` is immutable;
    /// * `Element` is bridged verbatim to Objective-C (i.e.,
    ///   is a reference type).
    @inlinable
    public init(_immutableCocoaArray: AnyObject) {
        self = _bridgeCocoaArray(_immutableCocoaArray)
    }
}
#endif

extension Array: _HasCustomAnyHashableRepresentation
where Element: Hashable {
    public __consuming func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(_box: _ArrayAnyHashableBox(self))
    }
}

internal protocol _ArrayAnyHashableProtocol: _AnyHashableBox {
    var count: Int { get }
    subscript(index: Int) -> AnyHashable { get }
}

internal struct _ArrayAnyHashableBox<Element: Hashable>
: _ArrayAnyHashableProtocol {
    internal let _value: [Element]
    
    internal init(_ value: [Element]) {
        self._value = value
    }
    
    internal var _base: Any {
        return _value
    }
    
    internal var count: Int {
        return _value.count
    }
    
    internal subscript(index: Int) -> AnyHashable {
        return _value[index] as AnyHashable
    }
    
    func _isEqual(to other: _AnyHashableBox) -> Bool? {
        guard let other = other as? _ArrayAnyHashableProtocol else { return nil }
        guard _value.count == other.count else { return false }
        for i in 0 ..< _value.count {
            if self[i] != other[i] { return false }
        }
        return true
    }
    
    var _hashValue: Int {
        var hasher = Hasher()
        _hash(into: &hasher)
        return hasher.finalize()
    }
    
    func _hash(into hasher: inout Hasher) {
        hasher.combine(_value.count) // discriminator
        for i in 0 ..< _value.count {
            hasher.combine(self[i])
        }
    }
    
    func _rawHashValue(_seed: Int) -> Int {
        var hasher = Hasher(_seed: _seed)
        self._hash(into: &hasher)
        return hasher._finalize()
    }
    
    internal func _unbox<T: Hashable>() -> T? {
        return _value as? T
    }
    
    internal func _downCastConditional<T>(
        into result: UnsafeMutablePointer<T>
    ) -> Bool {
        guard let value = _value as? T else { return false }
        result.initialize(to: value)
        return true
    }
}
