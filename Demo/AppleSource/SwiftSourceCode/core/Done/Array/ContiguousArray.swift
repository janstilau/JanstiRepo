/// A contiguously stored array.
///
/// The `ContiguousArray` type is a specialized array that always stores its
/// elements in a contiguous region of memory. This contrasts with `Array`,
/// which can store its elements in either a contiguous region of memory or an
/// `NSArray` instance if its `Element` type is a class or `@objc` protocol.
///
/// Array 可能是通过 ContiguousArray 进行的存储, 也可能是经过 NSArray 进行的存储.
///
/// If your array's `Element` type is a class or `@objc` protocol and you do
/// not need to bridge the array to `NSArray` or pass the array to Objective-C
/// APIs, using `ContiguousArray` may be more efficient and have more
/// predictable performance than `Array`. If the array's `Element` type is a
/// struct or enumeration, `Array` and `ContiguousArray` should have similar
/// efficiency.
///
/// For more information about using arrays, see `Array` and `ArraySlice`, with
/// which `ContiguousArray` shares most properties and methods.
@frozen
public struct ContiguousArray<Element>: _DestructorSafeContainer {
    /*
     真正的存储值的地方, 是用了 _ContiguousArrayBuffer .
     */
    @usableFromInline
    internal typealias _Buffer = _ContiguousArrayBuffer<Element>
    
    @usableFromInline
    internal var _buffer: _Buffer
    
    /// Initialization from an existing buffer does not have "array.init"
    /// semantics because the caller may retain an alias to buffer.
    @inlinable
    internal init(_buffer: _Buffer) {
        self._buffer = _buffer
    }
}

//===--- private helpers---------------------------------------------------===//
extension ContiguousArray {
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
    
    @inlinable
    @_semantics("array.make_mutable")
    internal mutating func _makeMutableAndUnique() {
        if _slowPath(!_buffer.isMutableAndUniquelyReferenced()) {
            _buffer = _Buffer(copying: _buffer)
        }
    }
    
    /// Check that the given `index` is valid for subscripting, i.e.
    /// `0 ≤ index < count`.
    @inlinable
    @inline(__always)
    internal func _checkSubscript_native(_ index: Int) {
        _buffer._checkValidSubscript(index)
    }
    
    /// Check that the specified `index` is valid, i.e. `0 ≤ index ≤ count`.
    @inlinable
    @_semantics("array.check_index")
    internal func _checkIndex(_ index: Int) {
        _precondition(index <= endIndex, "ContiguousArray index is out of range")
        _precondition(index >= startIndex, "Negative ContiguousArray index is out of range")
    }
    
    @inlinable
    @_semantics("array.get_element_address")
    internal func _getElementAddress(_ index: Int) -> UnsafeMutablePointer<Element> {
        return _buffer.subscriptBaseAddress + index
    }
}

extension ContiguousArray: _ArrayProtocol {
    @inlinable
    public var capacity: Int {
        return _getCapacity()
    }
    
    /// An object that guarantees the lifetime of this array's elements.
    @inlinable
    public // @testable
    var _owner: AnyObject? {
        return _buffer.owner
    }
    
    /// 取得数组的源地址.
    @inlinable
    public var _baseAddressIfContiguous: UnsafeMutablePointer<Element>? {
        @inline(__always) // FIXME(TODO: JIRA): Hack around test failure
        get { return _buffer.firstElementAddressIfContiguous }
    }
    
    @inlinable
    internal var _baseAddress: UnsafeMutablePointer<Element> {
        return _buffer.firstElementAddress
    }
}

/*
 ContiguousArray 对于 Collection 的适配工作
 所有的一切, 又是交给了 buffer 进行的处理.
 */
extension ContiguousArray: RandomAccessCollection, MutableCollection {
    /// Index 为 Int
    public typealias Index = Int
    
    /// The type that represents the indices that are valid for subscripting an
    /// array, in ascending order.
    public typealias Indices = Range<Int>
    
    /// Iterator 是 IndexingIterator, IndexingIterator 会调用 ContiguousArray 的方法来获取数据.
    public typealias Iterator = IndexingIterator<ContiguousArray>
    
    // Start, end 都是符合原来对于数组的定义的.
    @inlinable
    public var startIndex: Int {
        return 0
    }
    
    public var endIndex: Int {
        @inlinable
        get {
            return _getCount()
        }
    }
    
    /// 对于连续数组来说, index 也是连续的.
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
    
    /*
     在一个具体类型, 在实现协议的方法的时候, 如果有必要, 就重写这样更加高效.
     */
    @inlinable
    public func index(
        _ i: Int, offsetBy distance: Int, limitedBy limit: Int
    ) -> Int? {
        let l = limit - i
        if distance > 0 ? l >= 0 && l < distance : l <= 0 && distance < l {
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
    }
    
    @inlinable
    public func _failEarlyRangeCheck(_ range: Range<Int>, bounds: Range<Int>) {
    }
    
    /*
     _checkSubscript_native 确保了索引的范围.
     _makeMutableAndUnique , 修改的时候, 进行写时复制, 以及扩容处理.
     */
    @inlinable
    public subscript(index: Int) -> Element {
        get {
            _checkSubscript_native(index)
            return _buffer.getElement(index)
        }
        _modify {
            _makeMutableAndUnique()
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
            if self[bounds]._buffer.identity != rhs._buffer.identity
                || bounds != rhs.startIndex..<rhs.endIndex {
                self.replaceSubrange(bounds, with: rhs)
            }
        }
    }
    
    @inlinable
    public var count: Int {
        return _getCount()
    }
}

extension ContiguousArray: ExpressibleByArrayLiteral {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(_buffer: ContiguousArray(elements)._buffer)
    }
}


extension ContiguousArray: RangeReplaceableCollection {

    @inlinable
    @_semantics("array.init")
    public init() {
        _buffer = _Buffer()
    }
    
    /*
     将一个 Sequence 变成一个 Array.
     */
    @inlinable
    public init<S: Sequence>(_ s: S) where S.Element == Element {
        self.init(_buffer: s._copyToContiguousArray()._buffer)
    }
    
    /*
     这里有指针操作了.
     */
    @inlinable
    @_semantics("array.init")
    public init(repeating repeatedValue: Element, count: Int) {
        /*
         首先, 申请一块足够大的内存空间. 然后直接在这块内存空间上操作, 将 repeatedValue 赋值到这块内存空间上.
         */
        var p: UnsafeMutablePointer<Element>
        (self, p) = ContiguousArray._allocateUninitialized(count)
        for _ in 0..<count {
            p.initialize(to: repeatedValue)
            p += 1
        }
    }
    
    // 初始化, 并且把起始地址传递回来.
    @inlinable
    @_semantics("array.uninitialized")
    internal static func _allocateUninitialized(
        _ count: Int
    ) -> (ContiguousArray, UnsafeMutablePointer<Element>) {
        let result = ContiguousArray(_uninitializedCount: count)
        return (result, result._buffer.firstElementAddress)
    }
    
    
    /*
     Array 进行申请, 最终还是要靠 buffer 进行申请.
     */
    @inlinable
    internal init(_uninitializedCount count: Int) {
        _precondition(count >= 0, "Can't construct ContiguousArray with count < 0")
        _buffer = _Buffer()
        if count > 0 {
            _buffer = ContiguousArray._allocateBufferUninitialized(minimumCapacity: count)
            _buffer.count = count
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
        
    //===--- basic mutations ------------------------------------------------===//
    // 非常重要的方法.
    @inlinable
    @_semantics("array.mutate_unknown")
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        if _buffer.requestUniqueMutableBackingBuffer(
            minimumCapacity: minimumCapacity) == nil {
            
            // 扩容
            let newBuffer = _ContiguousArrayBuffer<Element>(
                _uninitializedCount: count, minimumCapacity: minimumCapacity)
            // 拷贝
            _buffer._copyContents(
                subRange: _buffer.indices,
                initializing: newBuffer.firstElementAddress)
            // 修改成员变量
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
        _buffer._arrayOutOfPlaceUpdate(
            &newBuffer, oldCount, 0)
    }
    
    /*
     这里应该做了引用计数的考虑了.
     如果不是 unique, 就进行一次拷贝的工作.
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
            
            _buffer.count += writtenCount
            
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
        _precondition(newCount >= 0, "Can't removeLast from an empty ContiguousArray")
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

extension ContiguousArray: CustomReflectable {
    /// A mirror that reflects the array.
    public var customMirror: Mirror {
        return Mirror(
            self,
            unlabeledChildren: self,
            displayStyle: .collection)
    }
}

extension ContiguousArray: CustomStringConvertible, CustomDebugStringConvertible {
    /// A textual representation of the array and its elements.
    public var description: String {
        return _makeCollectionDescription()
    }
    
    /// A textual representation of the array and its elements, suitable for
    /// debugging.
    public var debugDescription: String {
        return _makeCollectionDescription(withTypeName: "ContiguousArray")
    }
}

extension ContiguousArray {
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

extension ContiguousArray {
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
        self = try ContiguousArray(Array(
            _unsafeUninitializedCapacity: unsafeUninitializedCapacity,
            initializingWith: initializer))
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
    ///   points to the contiguous storage for the array.  If
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
    ///    If `body` has a return value, that value is also
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
        
        var work = ContiguousArray()
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
                "ContiguousArray withUnsafeMutableBufferPointer: replacing the buffer is not allowed")
            
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


extension ContiguousArray {
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
                      "ContiguousArray replace: subrange start is negative")
        
        _precondition(subrange.upperBound <= _buffer.endIndex,
                      "ContiguousArray replace: subrange extends past the end")
        
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

extension ContiguousArray: Equatable where Element: Equatable {
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
    public static func ==(lhs: ContiguousArray<Element>, rhs: ContiguousArray<Element>) -> Bool {
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

extension ContiguousArray: Hashable where Element: Hashable {
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

extension ContiguousArray {
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
