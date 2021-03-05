// A pointer for accessing data of a specific type.

public struct UnsafePointer<Pointee>: _Pointer {
    public typealias Distance = Int
    public let _rawValue: Builtin.RawPointer
    public init(_ _rawValue: Builtin.RawPointer) {
        self._rawValue = _rawValue
    }
    public var pointee: Pointee {
        return self
    }
    
    // 就是 Swift 版本的 free. 这里面, 应该不会调用相应的析构方法.
    public func deallocate() {
        Builtin.deallocRaw(_rawValue, (-1)._builtinWordValue, (0)._builtinWordValue)
    }
    
    
    // Swift 特别喜欢这种, 最后闭包决定返回值的行为.
    // 先把 rawValue 转为 T 的类型, 然后传入 body 里面, 结束的时候, 再转回来.
    // _rawValue 是一个不透明的数据类型, Builtin.bindMemory 这个函数, 一定会改变这个数据类型里面的数据.
    // body(UnsafePointer<T>(_rawValue)) 的参数, 是根据 rawValue 生成一个新的值对象, 所以, defer 以后在把值转回去, 不会影响到 body 的运行结果了. 仅仅是 rawValue 里面的地址数据是一样的, rawValue 里面的类型数据, 是不相同的
    public func withMemoryRebound<T, Result>(to type: T.Type,
                                             capacity count: Int,
                                             _ body: (UnsafePointer<T>) throws -> Result
    ) rethrows -> Result {
        Builtin.bindMemory(_rawValue, count._builtinWordValue, T.self)
        defer {
            Builtin.bindMemory(_rawValue, count._builtinWordValue, Pointee.self)
        }
        return try body(UnsafePointer<T>(_rawValue))
    }
    
    // 延续 C 的风格, [i] 就是 pointer + i
    public subscript(i: Int) -> Pointee {
        return self + i
    }
}



// 具有可变的 Pointer.
public struct UnsafeMutablePointer<Pointee>: _Pointer {
    public typealias Distance = Int
    public let _rawValue: Builtin.RawPointer
    // 和之前的 NSArray, NSMutableArray 是一样的. 数据部分, 其实可变不可变都一样, 但是可变类有了更多的接口.
    public init(_ _rawValue: Builtin.RawPointer) {
        self._rawValue = _rawValue
    }
    public init(@_nonEphemeral mutating other: UnsafePointer<Pointee>) {
        self._rawValue = other._rawValue
    }
    public init?(@_nonEphemeral mutating other: UnsafePointer<Pointee>?) {
        guard let unwrapped = other else { return nil }
        self.init(mutating: unwrapped)
    }
    public init(@_nonEphemeral _ other: UnsafeMutablePointer<Pointee>) {
        self._rawValue = other._rawValue		
    }		
    public init?(@_nonEphemeral _ other: UnsafeMutablePointer<Pointee>?) {
        guard let unwrapped = other else { return nil }		
        self.init(unwrapped)		
    }		
    
    // alloc 变为了 Poitner 的一部分了, 这也体现了, Swift 将基本数据类型, 归纳到类型管理的强大之处. 所有的代码, 都在自己应该在的地方.
    // allocate 放到了 mutable 里面, 因为创建一个不可变的指针, 是没有什么用途的.
    public static func allocate(capacity count: Int)
    -> UnsafeMutablePointer<Pointee> {
        let size = MemoryLayout<Pointee>.stride * count
        var align = Builtin.alignof(Pointee.self)
        if Int(align) <= _minAllocationAlignment() {
            align = (0)._builtinWordValue
        }
        // Builtin.allocRaw 应该就是  malloc 函数.
        let rawPtr = Builtin.allocRaw(size._builtinWordValue, align)
        // rawPtr 是 rawPointer, 是一个不透明的类型, 猜测, bindMemory 会把类型信息, 注册到 rawPointer 的内部.
        Builtin.bindMemory(rawPtr, count._builtinWordValue, Pointee.self)
        return UnsafeMutablePointer(rawPtr) // public init(_ _rawValue: Builtin.RawPointer)
    }
    
    public func deallocate() {
        // Builtin.deallocRaw 应该是 free 函数
        Builtin.deallocRaw(_rawValue, (-1)._builtinWordValue, (0)._builtinWordValue)
    }
    
    public var pointee: Pointee {
        @_transparent unsafeAddress {
            return UnsafePointer(self)
        }
        @_transparent nonmutating unsafeMutableAddress {
            return self
        }
    }
    
    // 根据 repeatedValue 初始化数据.
    public func initialize(repeating repeatedValue: Pointee, count: Int) {
        for offset in 0..<count {
            Builtin.initialize(repeatedValue, (self + offset)._rawValue)
        }
    }
    
    public func initialize(to value: Pointee) {
        Builtin.initialize(value, self._rawValue)
    }
    
    // 这个命令, 会让 _rawValue 重新回到 uninit 状态.
    // 所以, rawPointer 里面, 一定有一个值, 来记录自己是否已经经过了初始化
    public func move() -> Pointee {
        return Builtin.take(_rawValue)
    }
    
    public func assign(repeating repeatedValue: Pointee, count: Int) {
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
