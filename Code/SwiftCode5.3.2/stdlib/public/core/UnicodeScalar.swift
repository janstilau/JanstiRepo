extension Unicode {
    // 实际上, 它里面的数据, 就是一个 4 字节的值.
    // 实际上, 现在的 Unicode 字符只有 10 W 多个, 也就是 17 个 bit, 3 个字节就能显示出来.
    // 但是, 因为内存对齐的原因, 在计算机里面, 是使用 4 个字节表示.
    // 传输, 或者存储的时候, 要变化成为 UTF8, UTF32 等表示, 但是作为机器内存来说, 32 bit 能够直接的查询出数据来, 使用起来更加方便.
    // 可以认为, Scalar 到 UTF8, UTF16 是 Unicode 的一种序列化, 反序列化的方案.
    public struct Scalar {
        internal init(_value: UInt32) {
            self._value = _value
        }
        internal var _value: UInt32
    }
}

extension Unicode.Scalar :
    _ExpressibleByBuiltinUnicodeScalarLiteral,
    ExpressibleByUnicodeScalarLiteral {
    // 实际上, 就是存储一个 Int32 的值.
    public var value: UInt32 { return _value }
    public init(_builtinUnicodeScalarLiteral value: Builtin.Int32) {
        self._value = UInt32(value)
    }
    // 拷贝构造函数
    public init(unicodeScalarLiteral value: Unicode.Scalar) {
        self = value
    }
    
    //从U+D800到U+DFFF之间的码位区段是永久保留不映射到Unicode字符。UTF-16就利用保留下来的0xD800-0xDFFF区块的码位来对辅助平面的字符的码位进行编码。
    // 所以, 不是所有的 UInt32 都是 Unicode 的有效值, 这里根据 Unicode 的规定, 做了无效值的筛选工作.
    public init?(_ v: UInt32) {
        if (v < 0xD800 || v > 0xDFFF) && v <= 0x10FFFF {
            self._value = v
            return
        }
        return nil
    }
    
    public init?(_ v: UInt16) {
        self.init(UInt32(v))
    }
    
    public init(_ v: UInt8) {
        self._value = UInt32(v)
    }
    
    public init(_ v: Unicode.Scalar) {
        self = v
    }
    
    public func escaped(asASCII forceASCII: Bool) -> String {
        // 一个字节, 如何表现出来.
        func lowNibbleAsHex(_ v: UInt32) -> String {
            let nibble = v & 15 // 15 0xFF
            if nibble < 10 {
                return String(Unicode.Scalar(nibble+48)!)    // 48 = '0'
            } else {
                return String(Unicode.Scalar(nibble-10+65)!) // 65 = 'A'
            }
        }
        
        // 一些特殊字符, 直接转化为特定的字符串.
        if self == "\\" {
            return "\\\\"
        } else if self == "\'" {
            return "\\\'"
        } else if self == "\"" {
            return "\\\""
        } else if _isPrintableASCII {
            return String(self)
        } else if self == "\0" {
            return "\\0"
        } else if self == "\n" {
            return "\\n"
        } else if self == "\r" {
            return "\\r"
        } else if self == "\t" {
            return "\\t"
        } else if UInt32(self) < 128 {
            // 单字节的, 不可打印的字符, 4 位 4 位的打印. 使用 \u{} 的形式.
            return "\\u{"
                + lowNibbleAsHex(UInt32(self) >> 4)
                + lowNibbleAsHex(UInt32(self)) + "}"
        } else if !forceASCII {
            return String(self)
        } else if UInt32(self) <= 0xFFFF {
            // 两个字节的
            var result = "\\u{"
            result += lowNibbleAsHex(UInt32(self) >> 12)
            result += lowNibbleAsHex(UInt32(self) >> 8)
            result += lowNibbleAsHex(UInt32(self) >> 4)
            result += lowNibbleAsHex(UInt32(self))
            result += "}"
            return result
        } else {
            // 四个字节的
            var result = "\\u{"
            result += lowNibbleAsHex(UInt32(self) >> 28)
            result += lowNibbleAsHex(UInt32(self) >> 24)
            
            result += lowNibbleAsHex(UInt32(self) >> 20)
            result += lowNibbleAsHex(UInt32(self) >> 16)
            
            result += lowNibbleAsHex(UInt32(self) >> 12)
            result += lowNibbleAsHex(UInt32(self) >> 8)
            
            result += lowNibbleAsHex(UInt32(self) >> 4)
            result += lowNibbleAsHex(UInt32(self))
            result += "}"
            return result
        }
    }
    
    
    public var isASCII: Bool {
        return value <= 127
    }
    
    // isASCII 里面, 可打印字符是有着明显的范围的.
    internal var _isPrintableASCII: Bool {
        return (self >= Unicode.Scalar(0o040) && self <= Unicode.Scalar(0o176))
    }
}

extension Unicode.Scalar: LosslessStringConvertible {
    @inlinable
    public init?(_ description: String) {
        let scalars = description.unicodeScalars
        guard let v = scalars.first, scalars.count == 1 else {
            return nil
        }
        self = v
    }
}

extension Unicode.Scalar: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.value)
    }
}

extension Unicode.Scalar {
    public init?(_ v: Int) {
        if let us = Unicode.Scalar(UInt32(v)) {
            self = us
        } else {
            return nil
        }
    }
}

// Scalar, 也就是 UInt 32 到各个 UInt 的转换.
// 虽然我们知道, Scalar 里面是一个 UInt32, 但是不应该把这个值暴露出来. 所以, 对应的转化函数, 一个个都要写出来.
extension UInt8 {
    public init(ascii v: Unicode.Scalar) {
        self = UInt8(v.value)
    }
}
extension UInt32 {
    public init(_ v: Unicode.Scalar) {
        self = v.value
    }
}
extension UInt64 {
    public init(_ v: Unicode.Scalar) {
        self = UInt64(v.value)
    }
}

extension Unicode.Scalar: Equatable {
    public static func == (lhs: Unicode.Scalar, rhs: Unicode.Scalar) -> Bool {
        return lhs.value == rhs.value
    }
}

extension Unicode.Scalar: Comparable {
    public static func < (lhs: Unicode.Scalar, rhs: Unicode.Scalar) -> Bool {
        return lhs.value < rhs.value
    }
}











extension Unicode.Scalar {
    public struct UTF16View {
        internal init(value: Unicode.Scalar) {
            self.value = value
        }
        internal var value: Unicode.Scalar
    }
    
    public var utf16: UTF16View {
        return UTF16View(value: self)
    }
}

extension Unicode.Scalar.UTF16View: RandomAccessCollection {
    
    public typealias Indices = Range<Int>
    
    /// The position of the first code unit.
    @inlinable
    public var startIndex: Int {
        return 0
    }
    
    /// The "past the end" position---that is, the position one
    /// greater than the last valid subscript argument.
    ///
    /// If the collection is empty, `endIndex` is equal to `startIndex`.
    @inlinable
    public var endIndex: Int {
        return 0 + UTF16.width(value)
    }
    
    /// Accesses the code unit at the specified position.
    ///
    /// - Parameter position: The position of the element to access. `position`
    ///   must be a valid index of the collection that is not equal to the
    ///   `endIndex` property.
    @inlinable
    public subscript(position: Int) -> UTF16.CodeUnit {
        if position == 1 { return UTF16.trailSurrogate(value) }
        if endIndex == 1 { return UTF16.CodeUnit(value.value) }
        return UTF16.leadSurrogate(value)
    }
}

extension Unicode.Scalar {
    public struct UTF8View {
        internal init(value: Unicode.Scalar) {
            self.value = value
        }
        internal var value: Unicode.Scalar
    }
    
    public var utf8: UTF8View { return UTF8View(value: self) }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Unicode.Scalar.UTF8View: RandomAccessCollection {
    public typealias Indices = Range<Int>
    
    /// The position of the first code unit.
    @inlinable
    public var startIndex: Int { return 0 }
    
    /// The "past the end" position---that is, the position one
    /// greater than the last valid subscript argument.
    ///
    /// If the collection is empty, `endIndex` is equal to `startIndex`.
    @inlinable
    public var endIndex: Int { return 0 + UTF8.width(value) }
    
    /// Accesses the code unit at the specified position.
    ///
    /// - Parameter position: The position of the element to access. `position`
    ///   must be a valid index of the collection that is not equal to the
    ///   `endIndex` property.
    @inlinable
    public subscript(position: Int) -> UTF8.CodeUnit {
        _precondition(position >= startIndex && position < endIndex,
                      "Unicode.Scalar.UTF8View index is out of bounds")
        return value.withUTF8CodeUnits { $0[position] }
    }
}

extension Unicode.Scalar {
    internal static var _replacementCharacter: Unicode.Scalar {
        return Unicode.Scalar(_value: UTF32._replacementCodeUnit)
    }
}

extension Unicode.Scalar {
    /// Creates an instance of the NUL scalar value.
    @available(*, unavailable, message: "use 'Unicode.Scalar(0)'")
    public init() {
        Builtin.unreachable()
    }
}

// Access the underlying code units
extension Unicode.Scalar {
    // Access the scalar as encoded in UTF-16
    internal func withUTF16CodeUnits<Result>(
        _ body: (UnsafeBufferPointer<UInt16>) throws -> Result
    ) rethrows -> Result {
        var codeUnits: (UInt16, UInt16) = (self.utf16[0], 0)
        let utf16Count = self.utf16.count
        if utf16Count > 1 {
            _internalInvariant(utf16Count == 2)
            codeUnits.1 = self.utf16[1]
        }
        return try Swift.withUnsafePointer(to: &codeUnits) {
            return try $0.withMemoryRebound(to: UInt16.self, capacity: 2) {
                return try body(UnsafeBufferPointer(start: $0, count: utf16Count))
            }
        }
    }
    
    internal func withUTF8CodeUnits<Result>(
        _ body: (UnsafeBufferPointer<UInt8>) throws -> Result
    ) rethrows -> Result {
        // 首先, 调用 UTF8.encode, 将自己变为 UTF8 的编码格式.
        let encodedScalar = UTF8.encode(self)!
        var (codeUnits, utf8Count) = encodedScalar._bytes
        
        // The first code unit is in the least significant byte of codeUnits.
        // codeUnits 为 UInt 64
        codeUnits = codeUnits.littleEndian
        // withUnsafePointer 的作用是, 将 to 参数进行取地址, 然后将该地址交给闭包.
        return try Swift.withUnsafePointer(to: &codeUnits) {
            return try $0.withMemoryRebound(to: UInt8.self, capacity: 4) {
                return try body(UnsafeBufferPointer(start: $0, count: utf8Count))
            }
        }
    }
}

