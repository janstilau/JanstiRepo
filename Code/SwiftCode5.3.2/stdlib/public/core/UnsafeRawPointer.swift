
public struct UnsafeRawPointer: _Pointer {
    public typealias Pointee = UInt8
    public let _rawValue: Builtin.RawPointer
    
    // 各种, 不同类型之间的 pointer 的转化, 都要显示的定义出 init 函数出来.
    
    public init(_ _rawValue: Builtin.RawPointer) {
        self._rawValue = _rawValue
    }
    
    public init<T>(@_nonEphemeral _ other: UnsafePointer<T>) {
        _rawValue = other._rawValue
    }
    
    public init?<T>(@_nonEphemeral _ other: UnsafePointer<T>?) {
        guard let unwrapped = other else { return nil }
        _rawValue = unwrapped._rawValue
    }
    
    public init(@_nonEphemeral _ other: UnsafeMutableRawPointer) {
        _rawValue = other._rawValue
    }
    
    public init?(@_nonEphemeral _ other: UnsafeMutableRawPointer?) {
        guard let unwrapped = other else { return nil }
        _rawValue = unwrapped._rawValue
    }
    
    public init<T>(@_nonEphemeral _ other: UnsafeMutablePointer<T>) {
        _rawValue = other._rawValue		
    }		
    
    public init?<T>(@_nonEphemeral _ other: UnsafeMutablePointer<T>?) {
        guard let unwrapped = other else { return nil }		
        _rawValue = unwrapped._rawValue		
    }		
    
    /// The memory to be deallocated must be uninitialized or initialized to a
    /// trivial type.
    // free 对应的空间. 这里, deallocate 里面, 不会有引用计数的管理.
    // 引用计数的管理, 是放到了 initialize 和 deinitialize 里面了.
    // swift 用更加清晰的命名, 分离了初始化, 和内存分配两个部分.
    @inlinable
    public func deallocate() {
        // Passing zero alignment to the runtime forces "aligned
        // deallocation". Since allocation via `UnsafeMutable[Raw][Buffer]Pointer`
        // always uses the "aligned allocation" path, this ensures that the
        // runtime's allocation and deallocation paths are compatible.
        Builtin.deallocRaw(_rawValue, (-1)._builtinWordValue, (0)._builtinWordValue)
    }
    
    // 根据当前值, 创造 typed UnsafePointer .
    // 这个操作, 会改变当前 rawpointer 的类型/
    public func bindMemory<T>(
        to type: T.Type, capacity count: Int
    ) -> UnsafePointer<T> {
        Builtin.bindMemory(_rawValue, count._builtinWordValue, type)
        return UnsafePointer<T>(_rawValue)
    }
    
    // C++ 经常有这样的做法, 使用函数的参数, 来确定类型, 这是因为, 函数的泛型, 可以根据参数自动的进行类型推导, 但是推导的类型的作用, 是生成泛型类型的对象.
    public func assumingMemoryBound<T>(to: T.Type) -> UnsafePointer<T> {
        return UnsafePointer<T>(_rawValue)
    }
    
    public func load<T>(fromByteOffset offset: Int = 0, as type: T.Type) -> T {
        return Builtin.loadRaw((self + offset)._rawValue)
    }
}

extension UnsafeRawPointer: Strideable {
    public func advanced(by n: Int) -> UnsafeRawPointer {
        return UnsafeRawPointer(Builtin.gepRaw_Word(_rawValue, n._builtinWordValue))
    }
}
public struct UnsafeMutableRawPointer: _Pointer {
    public typealias Pointee = UInt8
    public let _rawValue: Builtin.RawPointer
    
    public init(_ _rawValue: Builtin.RawPointer) {
        self._rawValue = _rawValue
    }
    
    public init<T>(@_nonEphemeral _ other: UnsafeMutablePointer<T>) {
        _rawValue = other._rawValue
    }
    
    public init?<T>(@_nonEphemeral _ other: UnsafeMutablePointer<T>?) {
        guard let unwrapped = other else { return nil }
        _rawValue = unwrapped._rawValue
    }
    
    public init(@_nonEphemeral mutating other: UnsafeRawPointer) {
        _rawValue = other._rawValue
    }
    
    public init?(@_nonEphemeral mutating other: UnsafeRawPointer?) {
        guard let unwrapped = other else { return nil }
        _rawValue = unwrapped._rawValue
    }
    
    public static func allocate(
        byteCount: Int, alignment: Int
    ) -> UnsafeMutableRawPointer {
        var alignment = alignment
        if alignment <= _minAllocationAlignment() {
            alignment = 0
        }
        return UnsafeMutableRawPointer(Builtin.allocRaw(
                                        byteCount._builtinWordValue, alignment._builtinWordValue))
    }
    
    public func deallocate() {
        Builtin.deallocRaw(_rawValue, (-1)._builtinWordValue, (0)._builtinWordValue)
    }
    
    public func bindMemory<T>(
        to type: T.Type, capacity count: Int
    ) -> UnsafeMutablePointer<T> {
        Builtin.bindMemory(_rawValue, count._builtinWordValue, type)
        return UnsafeMutablePointer<T>(_rawValue)
    }
    
    public func assumingMemoryBound<T>(to: T.Type) -> UnsafeMutablePointer<T> {
        return UnsafeMutablePointer<T>(_rawValue)
    }
    
    public func initializeMemory<T>(
        as type: T.Type, repeating repeatedValue: T, count: Int
    ) -> UnsafeMutablePointer<T> {
        _debugPrecondition(count >= 0,
                           "UnsafeMutableRawPointer.initializeMemory: negative count")
        
        Builtin.bindMemory(_rawValue, count._builtinWordValue, type)
        var nextPtr = self
        for _ in 0..<count {
            Builtin.initialize(repeatedValue, nextPtr._rawValue)
            nextPtr += MemoryLayout<T>.stride
        }
        return UnsafeMutablePointer(_rawValue)
    }
    
    public func initializeMemory<T>(
        as type: T.Type, from source: UnsafePointer<T>, count: Int
    ) -> UnsafeMutablePointer<T> {
        _debugPrecondition(
            count >= 0,
            "UnsafeMutableRawPointer.initializeMemory with negative count")
        _debugPrecondition(
            (UnsafeRawPointer(self + count * MemoryLayout<T>.stride)
                <= UnsafeRawPointer(source))
                || UnsafeRawPointer(source + count) <= UnsafeRawPointer(self),
            "UnsafeMutableRawPointer.initializeMemory overlapping range")
        
        Builtin.bindMemory(_rawValue, count._builtinWordValue, type)
        Builtin.copyArray(
            T.self, self._rawValue, source._rawValue, count._builtinWordValue)
        // This builtin is equivalent to:
        // for i in 0..<count {
        //   (self.assumingMemoryBound(to: T.self) + i).initialize(to: source[i])
        // }
        return UnsafeMutablePointer(_rawValue)
    }
    
    public func moveInitializeMemory<T>(
        as type: T.Type, from source: UnsafeMutablePointer<T>, count: Int
    ) -> UnsafeMutablePointer<T> {
        _debugPrecondition(
            count >= 0,
            "UnsafeMutableRawPointer.moveInitializeMemory with negative count")
        
        Builtin.bindMemory(_rawValue, count._builtinWordValue, type)
        if self < UnsafeMutableRawPointer(source)
            || self >= UnsafeMutableRawPointer(source + count) {
            // initialize forward from a disjoint or following overlapping range.
            Builtin.takeArrayFrontToBack(
                T.self, self._rawValue, source._rawValue, count._builtinWordValue)
            // This builtin is equivalent to:
            // for i in 0..<count {
            //   (self.assumingMemoryBound(to: T.self) + i)
            //   .initialize(to: (source + i).move())
            // }
        }
        else {
            // initialize backward from a non-following overlapping range.
            Builtin.takeArrayBackToFront(
                T.self, self._rawValue, source._rawValue, count._builtinWordValue)
            // This builtin is equivalent to:
            // var src = source + count
            // var dst = self.assumingMemoryBound(to: T.self) + count
            // while dst != self {
            //   (--dst).initialize(to: (--src).move())
            // }
        }
        return UnsafeMutablePointer(_rawValue)
    }
    
    /// Returns a new instance of the given type, constructed from the raw memory
    /// at the specified offset.
    ///
    /// The memory at this pointer plus `offset` must be properly aligned for
    /// accessing `T` and initialized to `T` or another type that is layout
    /// compatible with `T`.
    ///
    /// - Parameters:
    ///   - offset: The offset from this pointer, in bytes. `offset` must be
    ///     nonnegative. The default is zero.
    ///   - type: The type of the instance to create.
    /// - Returns: A new instance of type `T`, read from the raw bytes at
    ///   `offset`. The returned instance is memory-managed and unassociated
    ///   with the value in the memory referenced by this pointer.
    @inlinable
    public func load<T>(fromByteOffset offset: Int = 0, as type: T.Type) -> T {
        _debugPrecondition(0 == (UInt(bitPattern: self + offset)
                                    & (UInt(MemoryLayout<T>.alignment) - 1)),
                           "load from misaligned raw pointer")
        
        return Builtin.loadRaw((self + offset)._rawValue)
    }
    
    /// Stores the given value's bytes into raw memory at the specified offset.
    ///
    /// The type `T` to be stored must be a trivial type. The memory at this
    /// pointer plus `offset` must be properly aligned for accessing `T`. The
    /// memory must also be uninitialized, initialized to `T`, or initialized to
    /// another trivial type that is layout compatible with `T`.
    ///
    /// After calling `storeBytes(of:toByteOffset:as:)`, the memory is
    /// initialized to the raw bytes of `value`. If the memory is bound to a
    /// type `U` that is layout compatible with `T`, then it contains a value of
    /// type `U`. Calling `storeBytes(of:toByteOffset:as:)` does not change the
    /// bound type of the memory.
    ///
    /// - Note: A trivial type can be copied with just a bit-for-bit copy without
    ///   any indirection or reference-counting operations. Generally, native
    ///   Swift types that do not contain strong or weak references or other
    ///   forms of indirection are trivial, as are imported C structs and enums.
    ///
    /// If you need to store a copy of a nontrivial value into memory, or to
    /// store a value into memory that contains a nontrivial value, you cannot
    /// use the `storeBytes(of:toByteOffset:as:)` method. Instead, you must know
    /// the type of value previously in memory and initialize or assign the
    /// memory. For example, to replace a value stored in a raw pointer `p`,
    /// where `U` is the current type and `T` is the new type, use a typed
    /// pointer to access and deinitialize the current value before initializing
    /// the memory with a new value.
    ///
    ///     let typedPointer = p.bindMemory(to: U.self, capacity: 1)
    ///     typedPointer.deinitialize(count: 1)
    ///     p.initializeMemory(as: T.self, to: newValue)
    ///
    /// - Parameters:
    ///   - value: The value to store as raw bytes.
    ///   - offset: The offset from this pointer, in bytes. `offset` must be
    ///     nonnegative. The default is zero.
    ///   - type: The type of `value`.
    @inlinable
    public func storeBytes<T>(
        of value: T, toByteOffset offset: Int = 0, as type: T.Type
    ) {
        _debugPrecondition(0 == (UInt(bitPattern: self + offset)
                                    & (UInt(MemoryLayout<T>.alignment) - 1)),
                           "storeBytes to misaligned raw pointer")
        
        var temp = value
        withUnsafeMutablePointer(to: &temp) { source in
            let rawSrc = UnsafeMutableRawPointer(source)._rawValue
            // FIXME: to be replaced by _memcpy when conversions are implemented.
            Builtin.int_memcpy_RawPointer_RawPointer_Int64(
                (self + offset)._rawValue, rawSrc, UInt64(MemoryLayout<T>.size)._value,
                /*volatile:*/ false._value)
        }
    }
    
    /// Copies the specified number of bytes from the given raw pointer's memory
    /// into this pointer's memory.
    ///
    /// If the `byteCount` bytes of memory referenced by this pointer are bound to 
    /// a type `T`, then `T` must be a trivial type, this pointer and `source`
    /// must be properly aligned for accessing `T`, and `byteCount` must be a
    /// multiple of `MemoryLayout<T>.stride`.
    ///
    /// The memory in the region `source..<(source + byteCount)` may overlap with
    /// the memory referenced by this pointer.
    ///
    /// After calling `copyMemory(from:byteCount:)`, the `byteCount` bytes of 
    /// memory referenced by this pointer are initialized to raw bytes. If the
    /// memory is bound to type `T`, then it contains values of type `T`.
    ///
    /// - Parameters:
    ///   - source: A pointer to the memory to copy bytes from. The memory in the
    ///     region `source..<(source + byteCount)` must be initialized to a
    ///     trivial type.
    ///   - byteCount: The number of bytes to copy. `byteCount` must not be negative.
    @inlinable
    public func copyMemory(from source: UnsafeRawPointer, byteCount: Int) {
        _memmove(dest: self, src: source, size: UInt(byteCount))
    }
}

extension UnsafeMutableRawPointer: Strideable {
    // custom version for raw pointers
    @_transparent
    public func advanced(by n: Int) -> UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(Builtin.gepRaw_Word(_rawValue, n._builtinWordValue))
    }
}

extension OpaquePointer {
    @_transparent
    public init(@_nonEphemeral _ from: UnsafeMutableRawPointer) {
        self._rawValue = from._rawValue
    }
    
    @_transparent
    public init?(@_nonEphemeral _ from: UnsafeMutableRawPointer?) {
        guard let unwrapped = from else { return nil }
        self._rawValue = unwrapped._rawValue
    }
    
    @_transparent
    public init(@_nonEphemeral _ from: UnsafeRawPointer) {
        self._rawValue = from._rawValue
    }
    
    @_transparent
    public init?(@_nonEphemeral _ from: UnsafeRawPointer?) {
        guard let unwrapped = from else { return nil }
        self._rawValue = unwrapped._rawValue
    }
}
