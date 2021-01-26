// 其实, 操作指针, 并不是什么高级的行为, 只是不好用, 所以显得很难.
// Swift 也暴露出了操作指针的接口来了, 就是 Unsafe 开头的两个 Pointer.
// Raw Pointer 不带泛型, Pointer 指定了类型

// 指针有很多的状态. 这在 C 代码里面, 也有这么多状态, 但是没有强制指明这回事. Swift 里面, 将操作和状态结合在了一起.
// 指针指向的数据, 没有初始化. alloc, 分配空间, init, 将这份空间初始化. 没有初始化, 就是没有执行 init 操作.

@frozen // unsafe-performance
public struct UnsafePointer<Pointee>: _Pointer {
    public typealias Distance = Int
    public let _rawValue: Builtin.RawPointer
    @_transparent
    public init(_ _rawValue: Builtin.RawPointer) {
        self._rawValue = _rawValue
    }
    
    // 就是 Swift 版本的 free. 这里面, 应该不会调用相应的析构方法.
    @inlinable
    public func deallocate() {
        // Passing zero alignment to the runtime forces "aligned
        // deallocation". Since allocation via `UnsafeMutable[Raw][Buffer]Pointer`
        // always uses the "aligned allocation" path, this ensures that the
        // runtime's allocation and deallocation paths are compatible.
        Builtin.deallocRaw(_rawValue, (-1)._builtinWordValue, (0)._builtinWordValue)
    }
    
    @inlinable // unsafe-performance
    public var pointee: Pointee {
        @_transparent unsafeAddress {
            return self
        }
    }
    
    // Swift 特别喜欢这种, 最后闭包决定返回值的行为.
    @inlinable
    public func withMemoryRebound<T, Result>(to type: T.Type,
                                             capacity count: Int,
                                             _ body: (UnsafePointer<T>) throws -> Result
    ) rethrows -> Result {
        Builtin.bindMemory(_rawValue, count._builtinWordValue, T.self)
        // 先把 rawValue 转为 T 的类型, 然后传入 body 里面, 结束的时候, 再转回来.
        // _rawValue 是一个不透明的数据类型, Builtin.bindMemory 这个函数, 一定会改变这个数据类型里面的数据.
        defer {
            Builtin.bindMemory(_rawValue, count._builtinWordValue, Pointee.self)
        }
        return try body(UnsafePointer<T>(_rawValue))
    }
    
    // 延续 C 的风格, [i] 就是 pointer + i
    @inlinable
    public subscript(i: Int) -> Pointee {
        @_transparent
        unsafeAddress {
            return self + i
        }
    }
    
    @inlinable // unsafe-performance
    internal static var _max: UnsafePointer {
        return UnsafePointer(
            bitPattern: 0 as Int &- MemoryLayout<Pointee>.stride
        )._unsafelyUnwrappedUnchecked
    }
}




@frozen // unsafe-performance
public struct UnsafeMutablePointer<Pointee>: _Pointer {
    
    public typealias Distance = Int
    public let _rawValue: Builtin.RawPointer
    
    @_transparent
    public init(_ _rawValue: Builtin.RawPointer) {
        self._rawValue = _rawValue
    }
    
    @_transparent
    public init(@_nonEphemeral mutating other: UnsafePointer<Pointee>) {
        self._rawValue = other._rawValue
    }
    
    @_transparent
    public init?(@_nonEphemeral mutating other: UnsafePointer<Pointee>?) {
        guard let unwrapped = other else { return nil }
        self.init(mutating: unwrapped)
    }
    
    @_transparent
    public init(@_nonEphemeral _ other: UnsafeMutablePointer<Pointee>) {
        self._rawValue = other._rawValue		
    }		
    
    @_transparent
    public init?(@_nonEphemeral _ other: UnsafeMutablePointer<Pointee>?) {
        guard let unwrapped = other else { return nil }		
        self.init(unwrapped)		
    }		
    
    
    @inlinable
    public static func allocate(capacity count: Int)
    -> UnsafeMutablePointer<Pointee> {
        let size = MemoryLayout<Pointee>.stride * count
        var align = Builtin.alignof(Pointee.self)
        if Int(align) <= _minAllocationAlignment() {
            align = (0)._builtinWordValue
        }
        // 真正的 分配的操作.
        // 然后把 rawPtr 通过 bindMemory 改变为相应的数据.
        let rawPtr = Builtin.allocRaw(size._builtinWordValue, align)
        Builtin.bindMemory(rawPtr, count._builtinWordValue, Pointee.self)
        return UnsafeMutablePointer(rawPtr) // public init(_ _rawValue: Builtin.RawPointer)
    }
    
    @inlinable
    public func deallocate() {
        Builtin.deallocRaw(_rawValue, (-1)._builtinWordValue, (0)._builtinWordValue)
    }
    
    @inlinable // unsafe-performance
    public var pointee: Pointee {
        @_transparent unsafeAddress {
            return UnsafePointer(self)
        }
        @_transparent nonmutating unsafeMutableAddress {
            return self
        }
    }
    
    @inlinable
    public func initialize(repeating repeatedValue: Pointee, count: Int) {
        for offset in 0..<count {
            Builtin.initialize(repeatedValue, (self + offset)._rawValue)
        }
    }
    
    /// Initializes this pointer's memory with a single instance of the given value.
    ///
    /// The destination memory must be uninitialized or the pointer's `Pointee`
    /// must be a trivial type. After a call to `initialize(to:)`, the
    /// memory referenced by this pointer is initialized. Calling this method is 
    /// roughly equivalent to calling `initialize(repeating:count:)` with a 
    /// `count` of 1.
    ///
    /// - Parameters:
    ///   - value: The instance to initialize this pointer's pointee to.
    @inlinable
    public func initialize(to value: Pointee) {
        Builtin.initialize(value, self._rawValue)
    }
    
    /// Retrieves and returns the referenced instance, returning the pointer's
    /// memory to an uninitialized state.
    ///
    /// Calling the `move()` method on a pointer `p` that references memory of
    /// type `T` is equivalent to the following code, aside from any cost and
    /// incidental side effects of copying and destroying the value:
    ///
    ///     let value: T = {
    ///         defer { p.deinitialize(count: 1) }
    ///         return p.pointee
    ///     }()
    ///
    /// The memory referenced by this pointer must be initialized. After calling
    /// `move()`, the memory is uninitialized.
    ///
    /// - Returns: The instance referenced by this pointer.
    @inlinable
    public func move() -> Pointee {
        return Builtin.take(_rawValue)
    }
    
    /// Replaces this pointer's memory with the specified number of
    /// consecutive copies of the given value.
    ///
    /// The region of memory starting at this pointer and covering `count`
    /// instances of the pointer's `Pointee` type must be initialized or
    /// `Pointee` must be a trivial type. After calling
    /// `assign(repeating:count:)`, the region is initialized.
    ///
    /// - Parameters:
    ///   - repeatedValue: The instance to assign this pointer's memory to.
    ///   - count: The number of consecutive copies of `newValue` to assign.
    ///     `count` must not be negative. 
    @inlinable
    public func assign(repeating repeatedValue: Pointee, count: Int) {
        _debugPrecondition(count >= 0, "UnsafeMutablePointer.assign(repeating:count:) with negative count")
        for i in 0..<count {
            self[i] = repeatedValue
        }
    }
    
    /// Replaces this pointer's initialized memory with the specified number of
    /// instances from the given pointer's memory.
    ///
    /// The region of memory starting at this pointer and covering `count`
    /// instances of the pointer's `Pointee` type must be initialized or
    /// `Pointee` must be a trivial type. After calling
    /// `assign(from:count:)`, the region is initialized.
    ///
    /// - Note: Returns without performing work if `self` and `source` are equal.
    ///
    /// - Parameters:
    ///   - source: A pointer to at least `count` initialized instances of type
    ///     `Pointee`. The memory regions referenced by `source` and this
    ///     pointer may overlap.
    ///   - count: The number of instances to copy from the memory referenced by
    ///     `source` to this pointer's memory. `count` must not be negative.
    @inlinable
    public func assign(from source: UnsafePointer<Pointee>, count: Int) {
        _debugPrecondition(
            count >= 0, "UnsafeMutablePointer.assign with negative count")
        if UnsafePointer(self) < source || UnsafePointer(self) >= source + count {
            // assign forward from a disjoint or following overlapping range.
            Builtin.assignCopyArrayFrontToBack(
                Pointee.self, self._rawValue, source._rawValue, count._builtinWordValue)
            // This builtin is equivalent to:
            // for i in 0..<count {
            //   self[i] = source[i]
            // }
        }
        else if UnsafePointer(self) != source {
            // assign backward from a non-following overlapping range.
            Builtin.assignCopyArrayBackToFront(
                Pointee.self, self._rawValue, source._rawValue, count._builtinWordValue)
            // This builtin is equivalent to:
            // var i = count-1
            // while i >= 0 {
            //   self[i] = source[i]
            //   i -= 1
            // }
        }
    }
    
    /// Moves instances from initialized source memory into the uninitialized
    /// memory referenced by this pointer, leaving the source memory
    /// uninitialized and the memory referenced by this pointer initialized.
    ///
    /// The region of memory starting at this pointer and covering `count`
    /// instances of the pointer's `Pointee` type must be uninitialized or
    /// `Pointee` must be a trivial type. After calling
    /// `moveInitialize(from:count:)`, the region is initialized and the memory
    /// region `source..<(source + count)` is uninitialized.
    ///
    /// - Parameters:
    ///   - source: A pointer to the values to copy. The memory region
    ///     `source..<(source + count)` must be initialized. The memory regions
    ///     referenced by `source` and this pointer may overlap.
    ///   - count: The number of instances to move from `source` to this
    ///     pointer's memory. `count` must not be negative.
    @inlinable
    public func moveInitialize(
        @_nonEphemeral from source: UnsafeMutablePointer, count: Int
    ) {
        _debugPrecondition(
            count >= 0, "UnsafeMutablePointer.moveInitialize with negative count")
        if self < source || self >= source + count {
            // initialize forward from a disjoint or following overlapping range.
            Builtin.takeArrayFrontToBack(
                Pointee.self, self._rawValue, source._rawValue, count._builtinWordValue)
            // This builtin is equivalent to:
            // for i in 0..<count {
            //   (self + i).initialize(to: (source + i).move())
            // }
        }
        else {
            // initialize backward from a non-following overlapping range.
            Builtin.takeArrayBackToFront(
                Pointee.self, self._rawValue, source._rawValue, count._builtinWordValue)
            // This builtin is equivalent to:
            // var src = source + count
            // var dst = self + count
            // while dst != self {
            //   (--dst).initialize(to: (--src).move())
            // }
        }
    }
    
    /// Initializes the memory referenced by this pointer with the values
    /// starting at the given pointer.
    ///
    /// The region of memory starting at this pointer and covering `count`
    /// instances of the pointer's `Pointee` type must be uninitialized or
    /// `Pointee` must be a trivial type. After calling
    /// `initialize(from:count:)`, the region is initialized.
    ///
    /// - Parameters:
    ///   - source: A pointer to the values to copy. The memory region
    ///     `source..<(source + count)` must be initialized. The memory regions
    ///     referenced by `source` and this pointer must not overlap.
    ///   - count: The number of instances to move from `source` to this
    ///     pointer's memory. `count` must not be negative.
    @inlinable
    public func initialize(from source: UnsafePointer<Pointee>, count: Int) {
        _debugPrecondition(
            count >= 0, "UnsafeMutablePointer.initialize with negative count")
        _debugPrecondition(
            UnsafePointer(self) + count <= source ||
                source + count <= UnsafePointer(self),
            "UnsafeMutablePointer.initialize overlapping range")
        Builtin.copyArray(
            Pointee.self, self._rawValue, source._rawValue, count._builtinWordValue)
        // This builtin is equivalent to:
        // for i in 0..<count {
        //   (self + i).initialize(to: source[i])
        // }
    }
    
    /// Replaces the memory referenced by this pointer with the values
    /// starting at the given pointer, leaving the source memory uninitialized.
    ///
    /// The region of memory starting at this pointer and covering `count`
    /// instances of the pointer's `Pointee` type must be initialized or
    /// `Pointee` must be a trivial type. After calling
    /// `moveAssign(from:count:)`, the region is initialized and the memory
    /// region `source..<(source + count)` is uninitialized.
    ///
    /// - Parameters:
    ///   - source: A pointer to the values to copy. The memory region
    ///     `source..<(source + count)` must be initialized. The memory regions
    ///     referenced by `source` and this pointer must not overlap.
    ///   - count: The number of instances to move from `source` to this
    ///     pointer's memory. `count` must not be negative.
    @inlinable
    public func moveAssign(
        @_nonEphemeral from source: UnsafeMutablePointer, count: Int
    ) {
        _debugPrecondition(
            count >= 0, "UnsafeMutablePointer.moveAssign(from:) with negative count")
        _debugPrecondition(
            self + count <= source || source + count <= self,
            "moveAssign overlapping range")
        Builtin.assignTakeArray(
            Pointee.self, self._rawValue, source._rawValue, count._builtinWordValue)
        // These builtins are equivalent to:
        // for i in 0..<count {
        //   self[i] = (source + i).move()
        // }
    }
    
    /// Deinitializes the specified number of values starting at this pointer.
    ///
    /// The region of memory starting at this pointer and covering `count`
    /// instances of the pointer's `Pointee` type must be initialized. After
    /// calling `deinitialize(count:)`, the memory is uninitialized, but still
    /// bound to the `Pointee` type.
    ///
    /// - Parameter count: The number of instances to deinitialize. `count` must
    ///   not be negative. 
    /// - Returns: A raw pointer to the same address as this pointer. The memory
    ///   referenced by the returned raw pointer is still bound to `Pointee`.
    @inlinable
    @discardableResult
    public func deinitialize(count: Int) -> UnsafeMutableRawPointer {
        _debugPrecondition(count >= 0, "UnsafeMutablePointer.deinitialize with negative count")
        // FIXME: optimization should be implemented, where if the `count` value
        // is 1, the `Builtin.destroy(Pointee.self, _rawValue)` gets called.
        Builtin.destroyArray(Pointee.self, _rawValue, count._builtinWordValue)
        return UnsafeMutableRawPointer(self)
    }
    
    /// Executes the given closure while temporarily binding the specified number
    /// of instances to the given type.
    ///
    /// Use this method when you have a pointer to memory bound to one type and
    /// you need to access that memory as instances of another type. Accessing
    /// memory as a type `T` requires that the memory be bound to that type. A
    /// memory location may only be bound to one type at a time, so accessing
    /// the same memory as an unrelated type without first rebinding the memory
    /// is undefined.
    ///
    /// The region of memory starting at this pointer and covering `count`
    /// instances of the pointer's `Pointee` type must be initialized.
    ///
    /// The following example temporarily rebinds the memory of a `UInt64`
    /// pointer to `Int64`, then accesses a property on the signed integer.
    ///
    ///     let uint64Pointer: UnsafeMutablePointer<UInt64> = fetchValue()
    ///     let isNegative = uint64Pointer.withMemoryRebound(to: Int64.self) { ptr in
    ///         return ptr.pointee < 0
    ///     }
    ///
    /// Because this pointer's memory is no longer bound to its `Pointee` type
    /// while the `body` closure executes, do not access memory using the
    /// original pointer from within `body`. Instead, use the `body` closure's
    /// pointer argument to access the values in memory as instances of type
    /// `T`.
    ///
    /// After executing `body`, this method rebinds memory back to the original
    /// `Pointee` type.
    ///
    /// - Note: Only use this method to rebind the pointer's memory to a type
    ///   with the same size and stride as the currently bound `Pointee` type.
    ///   To bind a region of memory to a type that is a different size, convert
    ///   the pointer to a raw pointer and use the `bindMemory(to:capacity:)`
    ///   method.
    ///
    /// - Parameters:
    ///   - type: The type to temporarily bind the memory referenced by this
    ///     pointer. The type `T` must be the same size and be layout compatible
    ///     with the pointer's `Pointee` type.
    ///   - count: The number of instances of `Pointee` to bind to `type`.
    ///   - body: A closure that takes a mutable typed pointer to the
    ///     same memory as this pointer, only bound to type `T`. The closure's
    ///     pointer argument is valid only for the duration of the closure's
    ///     execution. If `body` has a return value, that value is also used as
    ///     the return value for the `withMemoryRebound(to:capacity:_:)` method.
    /// - Returns: The return value, if any, of the `body` closure parameter.
    @inlinable
    public func withMemoryRebound<T, Result>(to type: T.Type, capacity count: Int,
                                             _ body: (UnsafeMutablePointer<T>) throws -> Result
    ) rethrows -> Result {
        Builtin.bindMemory(_rawValue, count._builtinWordValue, T.self)
        defer {
            Builtin.bindMemory(_rawValue, count._builtinWordValue, Pointee.self)
        }
        return try body(UnsafeMutablePointer<T>(_rawValue))
    }
    
    /// Accesses the pointee at the specified offset from this pointer.
    ///
    /// For a pointer `p`, the memory at `p + i` must be initialized when reading
    /// the value by using the subscript. When the subscript is used as the left
    /// side of an assignment, the memory at `p + i` must be initialized or
    /// the pointer's `Pointee` type must be a trivial type.
    ///
    /// Do not assign an instance of a nontrivial type through the subscript to
    /// uninitialized memory. Instead, use an initializing method, such as
    /// `initialize(to:count:)`.
    ///
    /// - Parameter i: The offset from this pointer at which to access an
    ///   instance, measured in strides of the pointer's `Pointee` type.
    @inlinable
    public subscript(i: Int) -> Pointee {
        @_transparent
        unsafeAddress {
            return UnsafePointer(self + i)
        }
        @_transparent
        nonmutating unsafeMutableAddress {
            return self + i
        }
    }
    
    @inlinable // unsafe-performance
    internal static var _max: UnsafeMutablePointer {
        return UnsafeMutablePointer(
            bitPattern: 0 as Int &- MemoryLayout<Pointee>.stride
        )._unsafelyUnwrappedUnchecked
    }
}
