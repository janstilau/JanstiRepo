/*
 @usableFromInline
 Apply this attribute to a function, method, computed property, subscript, initializer, or deinitializer declaration to allow that symbol to be used in inlinable code that’s defined in the same module as the declaration. The declaration must have the internal access level modifier. A structure or class marked usableFromInline can use only types that are public or usableFromInline for its properties. An enumeration marked usableFromInline can use only types that are public or usableFromInline for the raw values and associated values of its cases.

 Like the public access level modifier, this attribute exposes the declaration as part of the module’s public interface. Unlike public, the compiler doesn’t allow declarations marked with usableFromInline to be referenced by name in code outside the module, even though the declaration’s symbol is exported. However, code outside the module might still be able to interact with the declaration’s symbol by using runtime behavior.

 Declarations marked with the inlinable attribute are implicitly usable from inlinable code. Although either inlinable or usableFromInline can be applied to internal declarations, applying both attributes is an error.
 
 */

/// The C 'char' type.
///
/// This will be the same as either `CSignedChar` (in the common
/// case) or `CUnsignedChar`, depending on the platform.
public typealias CChar = Int8
public typealias CUnsignedChar = UInt8
public typealias CUnsignedShort = UInt16
public typealias CUnsignedInt = UInt32

#if os(Windows) && arch(x86_64)
public typealias CUnsignedLong = UInt32
#else
public typealias CUnsignedLong = UInt
#endif

public typealias CUnsignedLongLong = UInt64
public typealias CSignedChar = Int8
public typealias CShort = Int16
public typealias CInt = Int32
#if os(Windows) && arch(x86_64)
public typealias CLong = Int32
#else
public typealias CLong = Int
#endif

public typealias CLongLong = Int64
@available(macOS 10.16, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
public typealias CFloat16 = Float16
public typealias CFloat = Float
public typealias CDouble = Double

/// The C 'long double' type.
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
// On Darwin, long double is Float80 on x86, and Double otherwise.
#if arch(x86_64) || arch(i386)
public typealias CLongDouble = Float80
#else
public typealias CLongDouble = Double
#endif
#elseif os(Windows)
// On Windows, long double is always Double.
public typealias CLongDouble = Double
#elseif os(Linux)
// On Linux/x86, long double is Float80.
// TODO: Fill in definitions for additional architectures as needed. IIRC
// armv7 should map to Double, but arm64 and ppc64le should map to Float128,
// which we don't yet have in Swift.
#if arch(x86_64) || arch(i386)
public typealias CLongDouble = Float80
#endif
// TODO: Fill in definitions for other OSes.
#if arch(s390x)
// On s390x '-mlong-double-64' option with size of 64-bits makes the
// Long Double type equivalent to Double type.
public typealias CLongDouble = Double
#endif
#elseif os(Android)
// On Android, long double is Float128 for AAPCS64, which we don't have yet in
// Swift (SR-9072); and Double for ARMv7.
#if arch(arm)
public typealias CLongDouble = Double
#endif
#elseif os(OpenBSD)
public typealias CLongDouble = Float80
#endif

// FIXME: Is it actually UTF-32 on Darwin?
//
/// The C++ 'wchar_t' type.
public typealias CWideChar = Unicode.Scalar

// FIXME: Swift should probably have a UTF-16 type other than UInt16.
//
/// The C++11 'char16_t' type, which has UTF-16 encoding.
public typealias CChar16 = UInt16

/// The C++11 'char32_t' type, which has UTF-32 encoding.
public typealias CChar32 = Unicode.Scalar

/// The C '_Bool' and C++ 'bool' type.
public typealias CBool = Bool


// 这个类, 就是对于 void* 的封装.
public struct OpaquePointer {
    // 里面存了一下, void * 的地址.
    internal var _rawValue: Builtin.RawPointer
    
    internal init(_ v: Builtin.RawPointer) {
        self._rawValue = v
    }
    
    // 从 Int 值转化出一个 pointer 来
    public init?(bitPattern: Int) {
        if bitPattern == 0 { return nil }
        self._rawValue = Builtin.inttoptr_Word(bitPattern._builtinWordValue)
    }
    
    // 判断了一下, bitPattern 是否是有效值,
    public init?(bitPattern: UInt) {
        if bitPattern == 0 { return nil }
        self._rawValue = Builtin.inttoptr_Word(bitPattern._builtinWordValue)
    }
    
    // 几个不同类型 Pointer 的转化, 其实就是直接拿数据.
    public init<T>( _ from: UnsafePointer<T>) {
        self._rawValue = from._rawValue
    }
    
    // 增加了 optional 的处理.
    // unwrap 明确的暗示了, optinal 到底是什么
    public init?<T>(@_nonEphemeral _ from: UnsafePointer<T>?) {
        guard let unwrapped = from else { return nil }
        self.init(unwrapped)
    }
    
    public init<T>(@_nonEphemeral _ from: UnsafeMutablePointer<T>) {
        self._rawValue = from._rawValue
    }
    
    public init?<T>(@_nonEphemeral _ from: UnsafeMutablePointer<T>?) {
        guard let unwrapped = from else { return nil }
        self.init(unwrapped)
    }
}

// 相等性, 就是指针 int 值的比较
extension OpaquePointer: Equatable {
    public static func == (lhs: OpaquePointer, rhs: OpaquePointer) -> Bool {
        return Bool(Builtin.cmp_eq_RawPointer(lhs._rawValue, rhs._rawValue))
    }
}

// hash, 就是指针填入到 hash 中.
extension OpaquePointer: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(Int(Builtin.ptrtoint_Word(_rawValue)))
    }
}

extension OpaquePointer: CustomDebugStringConvertible {
    public var debugDescription: String {
        return _rawPointerToString(_rawValue)
    }
}

extension Int {
    /// Creates a new value with the bit pattern of the given pointer.
    ///
    /// The new value represents the address of the pointer passed as `pointer`.
    /// If `pointer` is `nil`, the result is `0`.
    ///
    /// - Parameter pointer: The pointer to use as the source for the new
    ///   integer.
    @inlinable // unsafe-performance
    public init(bitPattern pointer: OpaquePointer?) {
        self.init(bitPattern: UnsafeRawPointer(pointer))
    }
}

extension UInt {
    /// Creates a new value with the bit pattern of the given pointer.
    ///
    /// The new value represents the address of the pointer passed as `pointer`.
    /// If `pointer` is `nil`, the result is `0`.
    ///
    /// - Parameter pointer: The pointer to use as the source for the new
    ///   integer.
    @inlinable // unsafe-performance
    public init(bitPattern pointer: OpaquePointer?) {
        self.init(bitPattern: UnsafeRawPointer(pointer))
    }
}

/// A wrapper around a C `va_list` pointer.
#if arch(arm64) && !(os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(Windows))
@frozen
public struct CVaListPointer {
    @usableFromInline // unsafe-performance
    internal var _value: (__stack: UnsafeMutablePointer<Int>?,
                          __gr_top: UnsafeMutablePointer<Int>?,
                          __vr_top: UnsafeMutablePointer<Int>?,
                          __gr_off: Int32,
                          __vr_off: Int32)
    
    @inlinable // unsafe-performance
    public // @testable
    init(__stack: UnsafeMutablePointer<Int>?,
         __gr_top: UnsafeMutablePointer<Int>?,
         __vr_top: UnsafeMutablePointer<Int>?,
         __gr_off: Int32,
         __vr_off: Int32) {
        _value = (__stack, __gr_top, __vr_top, __gr_off, __vr_off)
    }
}

extension CVaListPointer: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "(\(_value.__stack.debugDescription), " +
            "\(_value.__gr_top.debugDescription), " +
            "\(_value.__vr_top.debugDescription), " +
            "\(_value.__gr_off), " +
            "\(_value.__vr_off))"
    }
}

#else

@frozen
public struct CVaListPointer {
    @usableFromInline // unsafe-performance
    internal var _value: UnsafeMutableRawPointer
    
    @inlinable // unsafe-performance
    public // @testable
    init(_fromUnsafeMutablePointer from: UnsafeMutableRawPointer) {
        _value = from
    }
}

extension CVaListPointer: CustomDebugStringConvertible {
    /// A textual representation of the pointer, suitable for debugging.
    public var debugDescription: String {
        return _value.debugDescription
    }
}

#endif

@inlinable
internal func _memcpy(
    dest destination: UnsafeMutableRawPointer,
    src: UnsafeRawPointer,
    size: UInt
) {
    let dest = destination._rawValue
    let src = src._rawValue
    let size = UInt64(size)._value
    Builtin.int_memcpy_RawPointer_RawPointer_Int64(
        dest, src, size,
        /*volatile:*/ false._value)
}

/// Copy `count` bytes of memory from `src` into `dest`.
///
/// The memory regions `source..<source + count` and
/// `dest..<dest + count` may overlap.
@inlinable
internal func _memmove(
    dest destination: UnsafeMutableRawPointer,
    src: UnsafeRawPointer,
    size: UInt
) {
    let dest = destination._rawValue
    let src = src._rawValue
    let size = UInt64(size)._value
    Builtin.int_memmove_RawPointer_RawPointer_Int64(
        dest, src, size,
        /*volatile:*/ false._value)
}
