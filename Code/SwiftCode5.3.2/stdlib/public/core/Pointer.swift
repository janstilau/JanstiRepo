
// 实际上, _Pointer 就是对于系统原始指针的一层封装. 并且, 里面Pointee规范了指向的类型.
public protocol _Pointer
: Hashable, Strideable, CustomDebugStringConvertible, CustomReflectable {
    typealias Distance = Int
    
    associatedtype Pointee
    
    // 本质上, 就是对于 void * 的封装.
    var _rawValue: Builtin.RawPointer { get }
    init(_ _rawValue: Builtin.RawPointer)
}

extension _Pointer {
    public init(_ from: OpaquePointer) {
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
    public init(_ other: Self) {
        self.init(other._rawValue)
    }
    
    public init?(@_nonEphemeral _ other: Self?) {
        guard let unwrapped = other else { return nil }
        self.init(unwrapped._rawValue)
    }
}

// 比较, 就是地址的比较
extension _Pointer /*: Equatable */ {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return Bool(Builtin.cmp_eq_RawPointer(lhs._rawValue, rhs._rawValue))
    }
}

// 比较, 就是地址的比较
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
        let ptrDistance = Int(Builtin.sub_Word(Builtin.ptrtoint_Word(end._rawValue),
                                               Builtin.ptrtoint_Word(_rawValue)))
        let stride = MemoryLayout<Pointee>.stride
        return ptrDistance/stride
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
                        self._rawValue,
                        n._builtinWordValue,
                        Pointee.self))
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

// _Pointer 的 +, - 操作符的定义
// Strideable 的 protocol, 对于 pointer 的相关操作, 写到了 pointer 的实现文件里面
// 代码的组织方式, 更加的合理.
// 用 C++ 考虑, namespace 让 Strideable 的职责, 可以转移到更加合理的地方.
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
