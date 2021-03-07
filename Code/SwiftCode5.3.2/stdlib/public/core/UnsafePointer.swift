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
    // body(UnsafePointer<T>(_rawValue)) 的参数, 是根据 rawValue 生成一个新的值对象, 所以, defer 以后在把值转回去, 不会影响到 body 的运行结果了.
    // 地址还是一样的, 只不过闭包里面, 和原始值的类型不一样的.
    public func withMemoryRebound<T, Result>(to type: T.Type,
                                             capacity count: Int, // 这个值, 没有作用啊.
                                             _ body: (UnsafePointer<T>) throws -> Result
    ) rethrows -> Result {
        Builtin.bindMemory(_rawValue, count._builtinWordValue, T.self)
        defer {
            Builtin.bindMemory(_rawValue, count._builtinWordValue, Pointee.self)
        }
        return try body(UnsafePointer<T>(_rawValue))
    }
    
    // + 在 _Pointer 里面, 有默认实现. 就是调用 advance, 里面是根据 T 的 stride 获取到相应的位置
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
        // size, align 最后, 会计算出最终需要的 byte 数量.
        let rawPtr = Builtin.allocRaw(size._builtinWordValue, align)
        // Builtin 里面, 应该会将 ptr 绑定到某个类型上. 所以在 Swift 里面, 指针其实是会和某个类型绑定的
        Builtin.bindMemory(rawPtr, count._builtinWordValue, Pointee.self)
        return UnsafeMutablePointer(rawPtr) // public init(_ _rawValue: Builtin.RawPointer)
    }
    
    // MutablePointer 并不是 Pointer 的子类, 所以还需要重新实现以下.
    public func deallocate() {
        Builtin.deallocRaw(_rawValue, (-1)._builtinWordValue, (0)._builtinWordValue)
    }
    
    // 编译器会返回不同的版本.
    public var pointee: Pointee {
        @_transparent unsafeAddress {
            return UnsafePointer(self)
        }
        @_transparent nonmutating unsafeMutableAddress {
            return self
        }
    }
    
    // Builtin.initialize 在指定的位置, 使用 repeatedValue 进行初始化, 应该就是内存的拷贝.
    // Swift 取消了, C++ 里面的拷贝构造这回事, 所有的值, 都是内存搬移. 然后这个值, 是值语义, 还是引用语义, 由 struct 的设计者决定.
    // 或者说, struct 天然是引用语义的, 要想成为值语义的, 那么在 struct 里面有引用值的话, 要特别小心.
    
    // Initialize 里面, 不会有方法的调用. 因为本身 Swift 的类型, 就没有拷贝构造函数的设计.
    // 但是, 会有引用计数的设计. 当 repeatedValue 里面有 class 值的时候, 会进行引用计数的变化.
    // 如果, repeatedValue 里是 class 值, 也就是指针, 那么 buffer 里面存的是指针值.
    // 如果, repreatedValue 是 struct, 那么 buffer 里面存的是 sturct 的值.
    // 但是, 如果 struct 里面有指针值, 那么对应指针的引用计数, 也会变化.
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
    
    // 这里, 是使用了 subscript 进行赋值.
    // 不过没找到对应的 subscript set 的实现. 姑且认为是值覆盖吧
    public func assign(repeating repeatedValue: Pointee, count: Int) {
        for i in 0..<count {
            self[i] = repeatedValue
        }
    }
    
    // C 风格的 memcopy 的实现.
    // 因为 Swift 里面, 没有拷贝构造这回事, 所以还是值覆盖.
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
    
    // 带有 move 语义的复制操作.
    // 简单地理解, move 之后, source 里面的值会失效吧. 简单地归零操作????
    public func moveInitialize(
        @_nonEphemeral from source: UnsafeMutablePointer, count: Int
    ) {
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
    
    // 就是直接的值覆盖. 还是因为 Swift 在值传递的时候, 没有考虑拷贝构造这回事.
    public func initialize(from source: UnsafePointer<Pointee>, count: Int) {
        Builtin.copyArray(
            Pointee.self, self._rawValue, source._rawValue, count._builtinWordValue)
        // This builtin is equivalent to:
        // for i in 0..<count {
        //   (self + i).initialize(to: source[i])
        // }
    }
    
    // 值覆盖, 然后调用 memset 0 ? 反正会让 src 指针指向的空间进行清空.
    public func moveAssign(
        @_nonEphemeral from source: UnsafeMutablePointer, count: Int
    ) {
        Builtin.assignTakeArray(
            Pointee.self, self._rawValue, source._rawValue, count._builtinWordValue)
        // These builtins are equivalent to:
        // for i in 0..<count {
        //   self[i] = (source + i).move()
        // }
    }
    
    // 调用析构函数??? 只会对 class 有用吧.
    // 因为 Int, 这些其实是 struct, 我们自己写的 struct, 和 Int 没有区别.
    public func deinitialize(count: Int) -> UnsafeMutableRawPointer {
        _debugPrecondition(count >= 0, "UnsafeMutablePointer.deinitialize with negative count")
        // FIXME: optimization should be implemented, where if the `count` value
        // is 1, the `Builtin.destroy(Pointee.self, _rawValue)` gets called.
        Builtin.destroyArray(Pointee.self, _rawValue, count._builtinWordValue)
        return UnsafeMutableRawPointer(self)
    }
    
    public func withMemoryRebound<T, Result>(to type: T.Type,
                                             capacity count: Int,
                                             _ body: (UnsafeMutablePointer<T>) throws -> Result
    ) rethrows -> Result {
        Builtin.bindMemory(_rawValue, count._builtinWordValue, T.self)
        defer {
            Builtin.bindMemory(_rawValue, count._builtinWordValue, Pointee.self)
        }
        return try body(UnsafeMutablePointer<T>(_rawValue))
    }
    
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
