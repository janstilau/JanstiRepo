
// 实际上, _Pointer 就是对于系统原始指针的一层封装. 并且, 里面Pointee规范了指向的类型.
public protocol _Pointer
: Hashable, Strideable, CustomDebugStringConvertible, CustomReflectable {
    // 默认 Int, 其实就是字节, 并且, 计算机的内存是有限的
    typealias Distance = Int
    
    associatedtype Pointee
    
    var _rawValue: Builtin.RawPointer { get }
    
    init(_ _rawValue: Builtin.RawPointer)
}

extension _Pointer {
    public init(_ from: OpaquePointer) {
        // OpaquePointer 的 rawValue 就是 Builtin.RawPointer
        self.init(from._rawValue)
    }
    
    public init?(_ from: OpaquePointer?) {
        guard let unwrapped = from else { return nil }
        self.init(unwrapped)
    }
    
    // 通过二进制表示返回一个指针.
    public init?(bitPattern: Int) {
        if bitPattern == 0 { return nil }
        self.init(Builtin.inttoptr_Word(bitPattern._builtinWordValue))
    }
    
    public init?(bitPattern: UInt) {
        if bitPattern == 0 { return nil }
        self.init(Builtin.inttoptr_Word(bitPattern._builtinWordValue))
    }
    
    // copy 构造函数
    public init(@_nonEphemeral _ other: Self) {
        self.init(other._rawValue)
    }
    
    public init?(@_nonEphemeral _ other: Self?) {
        guard let unwrapped = other else { return nil }
        self.init(unwrapped._rawValue)
    }
}

// 指针的比较, 就是地址的比较, 就是虚拟地址的比较.
extension _Pointer /*: Equatable */ {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return Bool(Builtin.cmp_eq_RawPointer(lhs._rawValue, rhs._rawValue))
    }
}

// 指针的比较, 就是地址的比较, 就是虚拟地址的比较.
extension _Pointer /*: Comparable */ {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        return Bool(Builtin.cmp_ult_RawPointer(lhs._rawValue, rhs._rawValue))
    }
}

extension _Pointer /*: Strideable*/ {
    // A pointer advanced from this pointer by   `MemoryLayout<Pointee>.stride` bytes
    public func successor() -> Self {
        return advanced(by: 1)
    }
    
    public func predecessor() -> Self {
        return advanced(by: -1)
    }
    
    // 地址相减然后除以指针代表类型的长度. 和之前 c 是一样的.
    public func distance(to end: Self) -> Int {
        return
            Int(Builtin.sub_Word(Builtin.ptrtoint_Word(end._rawValue),
                                 Builtin.ptrtoint_Word(_rawValue)))
            / MemoryLayout<Pointee>.stride
    }
    
    /// Returns a pointer offset from this pointer by the specified number of
    /// instances.
    ///
    /// With pointer `p` and distance `n`, the result of `p.advanced(by: n)` is
    /// equivalent to `p + n`.
    ///
    /// The resulting pointer must be within the bounds of the same allocation as
    /// this pointer.
    ///
    /// - Parameter n: The number of strides of the pointer's `Pointee` type to
    ///   offset this pointer. To access the stride, use
    ///   `MemoryLayout<Pointee>.stride`. `n` may be positive, negative, or
    ///   zero.
    /// - Returns: A pointer offset from this pointer by `n` instances of the
    ///   `Pointee` type.
    @_transparent
    public func advanced(by n: Int) -> Self {
        return Self(Builtin.gep_Word(
                        self._rawValue, n._builtinWordValue, Pointee.self))
    }
}

extension _Pointer /*: Hashable */ {
    // 直接地址值用作 hash 算法.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(UInt(bitPattern: self))
    }
    
    public func _rawHashValue(seed: Int) -> Int {
        return Hasher._hash(seed: seed, UInt(bitPattern: self))
    }
}

extension _Pointer /*: CustomDebugStringConvertible */ {
    public var debugDescription: String {
        return _rawPointerToString(_rawValue)
    }
}

extension _Pointer /*: CustomReflectable */ {
    public var customMirror: Mirror {
        let ptrValue = UInt64(
            bitPattern: Int64(Int(Builtin.ptrtoint_Word(_rawValue))))
        return Mirror(self, children: ["pointerValue": ptrValue])
    }
}

extension Int {
    // 就是拿到地址的实际值, 用 int 表示.
    public init<P: _Pointer>(bitPattern pointer: P?) {
        if let pointer = pointer {
            self = Int(Builtin.ptrtoint_Word(pointer._rawValue))
        } else {
            self = 0
        }
    }
}

extension UInt {
    public init<P: _Pointer>(bitPattern pointer: P?) {
        if let pointer = pointer {
            self = UInt(Builtin.ptrtoint_Word(pointer._rawValue))
        } else {
            self = 0
        }
    }
}

// _Pointer 的 +, - 操作符的定义.
extension Strideable where Self: _Pointer {
    public static func + (@_nonEphemeral lhs: Self, rhs: Self.Stride) -> Self {
        return lhs.advanced(by: rhs)
    }
    
    public static func + (lhs: Self.Stride, @_nonEphemeral rhs: Self) -> Self {
        return rhs.advanced(by: lhs)
    }
    
    public static func - (@_nonEphemeral lhs: Self, rhs: Self.Stride) -> Self {
        return lhs.advanced(by: -rhs)
    }
    
    public static func - (lhs: Self, rhs: Self) -> Self.Stride {
        return rhs.distance(to: lhs)
    }
    
    public static func += (lhs: inout Self, rhs: Self.Stride) {
        lhs = lhs.advanced(by: rhs)
    }
    
    public static func -= (lhs: inout Self, rhs: Self.Stride) {
        lhs = lhs.advanced(by: -rhs)
    }
}

/// Derive a pointer argument from a convertible pointer type.
@_transparent
public // COMPILER_INTRINSIC
func _convertPointerToPointerArgument<
    FromPointer: _Pointer,
    ToPointer: _Pointer
>(_ from: FromPointer) -> ToPointer {
    return ToPointer(from._rawValue)
}

/// Derive a pointer argument from the address of an inout parameter.
@_transparent
public // COMPILER_INTRINSIC
func _convertInOutToPointerArgument<
    ToPointer: _Pointer
>(_ from: Builtin.RawPointer) -> ToPointer {
    return ToPointer(from)
}

/// Derive a pointer argument from a value array parameter.
///
/// This always produces a non-null pointer, even if the array doesn't have any
/// storage.
@_transparent
public // COMPILER_INTRINSIC
func _convertConstArrayToPointerArgument<
    FromElement,
    ToPointer: _Pointer
>(_ arr: [FromElement]) -> (AnyObject?, ToPointer) {
    let (owner, opaquePointer) = arr._cPointerArgs()
    
    let validPointer: ToPointer
    if let addr = opaquePointer {
        validPointer = ToPointer(addr._rawValue)
    } else {
        let lastAlignedValue = ~(MemoryLayout<FromElement>.alignment - 1)
        let lastAlignedPointer = UnsafeRawPointer(bitPattern: lastAlignedValue)!
        validPointer = ToPointer(lastAlignedPointer._rawValue)
    }
    return (owner, validPointer)
}

/// Derive a pointer argument from an inout array parameter.
///
/// This always produces a non-null pointer, even if the array's length is 0.
@_transparent
public // COMPILER_INTRINSIC
func _convertMutableArrayToPointerArgument<
    FromElement,
    ToPointer: _Pointer
>(_ a: inout [FromElement]) -> (AnyObject?, ToPointer) {
    // TODO: Putting a canary at the end of the array in checked builds might
    // be a good idea
    
    // Call reserve to force contiguous storage.
    a.reserveCapacity(0)
    _debugPrecondition(a._baseAddressIfContiguous != nil || a.isEmpty)
    
    return _convertConstArrayToPointerArgument(a)
}

/// Derive a UTF-8 pointer argument from a value string parameter.
@_transparent
public // COMPILER_INTRINSIC
func _convertConstStringToUTF8PointerArgument<
    ToPointer: _Pointer
>(_ str: String) -> (AnyObject?, ToPointer) {
    let utf8 = Array(str.utf8CString)
    return _convertConstArrayToPointerArgument(utf8)
}
