extension Unicode {
    public enum UTF8 {
        case _swift3Buffer(Unicode.UTF8.ForwardParser)
    }
}

/*
 UTF-8编码方式
 
 2^16 = 65536, 而现在 unicode 是 10 万多个字母, 所以 17 个字节就足够了. 但是 UTF 8 表示 17 个字节, 要用四个字节. 在转化的时候, 根据 unicode 编码的位置不同, 生成了不同长度的 uft8 编码.
 
 U+0000~U+007F 一个字节, 利用了 7 个 bit 位置
 0????????
 
 U+0080~U+07FF 两个字节, 利用了 11 个 bit 位置
 110????? 10??????
 
 U+0800~U+FFFF 三个字节, 利用了 16 个 bit 位置.
 1110???? 10?????? 10??????
 
 U+10000~U+10FFFF 四个字节, 利用了 21 个 bit 位置.
 11110??? 10?????? 10?????? 10??????
 
 当我们得到Unicode码后，我们先根据上面的这个表判断其所处的范围，然后将Unicode码转换为二进制表示，从后往前截取UTF-8编码中所留为之长度，从前往后依次填入对应位置，所即可得到UTF-8的编码
 U+0020，这个字符的小于0000 007F，所以只需要用1 Byte来进行编码。U+0020的二进制表示为0000(0)0000(0) 0010(2)0000(0)，那么从后往前截取7位得到010 0000，放入UTF-8编码方式中，得到的结果为00101111，转换为十六进制得到2F。因此存储在内存中的的顺序就是2F。
 U+A12B，这个字符大于0000 0800，小于0000 FFFF，因此需要用3 Byte来进行编码。U+A12B的二进制表示为1010(A)0001(1) 0010(2)1011(B)。，那么从后往前截取16位得到10100001 00101011（Unicode码本身），放入UTF-8编码中，得到的结果为11101010 10000100 10101011，转换十六进制得到EA84AB。因此，存储在内存中的顺序就是EA 84 AB。
 */

extension Unicode.UTF8 {
    // Unicode.Scalar 里面, 存储了一个 U32, 也就是四个字节的值.
    // 根据, Unicode 编码的大小, 获取需要多少个字节表示该字符. 里面的 magic number, 是 UTF 这套编码规则规定的.
    public static func width(_ x: Unicode.Scalar) -> Int {
        switch x.value {
        case 0..<0x80: return 1 // 000000 - 00007F
        case 0x80..<0x0800: return 2 // 000080 - 0007FF
        case 0x0800..<0x1_0000: return 3 // 010000 - 10FFFF
        default: return 4
        }
    }
}

extension Unicode.UTF8: _UnicodeEncoding {
    
    // UTF 8, 是按照字节为单位的.
    public typealias CodeUnit = UInt8
    public typealias EncodedScalar = _ValidUTF8Buffer
    
    public static var encodedReplacementCharacter: EncodedScalar {
        return EncodedScalar.encodedReplacementCharacter
    }
    
    // 按照 UTF 8 的标准, 最大的就是 7 位数字, 所以和 0b1000_0000 进行与操作, 一定是为 0.
    public static func _isScalar(_ x: CodeUnit) -> Bool {
        return isASCII(x)
    }
    public static func isASCII(_ x: CodeUnit) -> Bool {
        return x & 0b1000_0000 == 0
    }
    
    // 如果从 _ValidUTF8Buffer 中, 抽取出有效的 Unicode.Scalar
    // 这里, 其实就是 从 UTF8 编码, 到 Unicode 编码的反序列化的过程.
    // 根据长度, 分别取不同字节的数据, 最后进行相加凑走.
    public static func decode(_ source: EncodedScalar) -> Unicode.Scalar {
        switch source.count {
        case 1:
            return Unicode.Scalar(_unchecked: source._biasedBits &- 0x01)
        case 2:
            let bits = source._biasedBits &- 0x0101
            var value = (bits & 0b0_______________________11_1111__0000_0000) &>> 8
            value    |= (bits & 0b0________________________________0001_1111) &<< 6
            return Unicode.Scalar(_unchecked: value)
        case 3:
            let bits = source._biasedBits &- 0x010101
            var value = (bits & 0b0____________11_1111__0000_0000__0000_0000) &>> 16
            value    |= (bits & 0b0_______________________11_1111__0000_0000) &>> 2
            value    |= (bits & 0b0________________________________0000_1111) &<< 12
            return Unicode.Scalar(_unchecked: value)
        default:
            _internalInvariant(source.count == 4)
            let bits = source._biasedBits &- 0x01010101
            var value = (bits & 0b0_11_1111__0000_0000__0000_0000__0000_0000) &>> 24
            value    |= (bits & 0b0____________11_1111__0000_0000__0000_0000) &>> 10
            value    |= (bits & 0b0_______________________11_1111__0000_0000) &<< 4
            value    |= (bits & 0b0________________________________0000_0111) &<< 18
            return Unicode.Scalar(_unchecked: value)
        }
    }
    
    // 如果, 把 Unicode, 序列化为 UTF8 的过程.
    public static func encode(
        _ source: Unicode.Scalar
    ) -> EncodedScalar? {
        var c = source.value
        if _fastPath(c < (1&<<7)) {
            return EncodedScalar(_containing: UInt8(c))
        }
        var o = c & 0b0__0011_1111
        c &>>= 6
        o &<<= 8
        if _fastPath(c < (1&<<5)) {
            return EncodedScalar(_biasedBits: (o | c) &+ 0b0__1000_0001__1100_0001)
        }
        o |= c & 0b0__0011_1111
        c &>>= 6
        o &<<= 8
        if _fastPath(c < (1&<<4)) {
            return EncodedScalar(
                _biasedBits: (o | c) &+ 0b0__1000_0001__1000_0001__1110_0001)
        }
        o |= c & 0b0__0011_1111
        c &>>= 6
        o &<<= 8
        return EncodedScalar(
            _biasedBits: (o | c ) &+ 0b0__1000_0001__1000_0001__1000_0001__1111_0001)
    }
    
    // 从一种编码方式, 转换到自己的 _ValidUTF8Buffer 形式.
    public static func transcode<FromEncoding: _UnicodeEncoding>(
        _ content: FromEncoding.EncodedScalar, from _: FromEncoding.Type
    ) -> EncodedScalar? {
        if _fastPath(FromEncoding.self == UTF16.self) {
            let c = _identityCast(content, to: UTF16.EncodedScalar.self)
            var u0 = UInt16(truncatingIfNeeded: c._storage)
            if _fastPath(u0 < 0x80) {
                return EncodedScalar(_containing: UInt8(truncatingIfNeeded: u0))
            }
            var r = UInt32(u0 & 0b0__11_1111)
            r &<<= 8
            u0 &>>= 6
            if _fastPath(u0 < (1&<<5)) {
                return EncodedScalar(
                    _biasedBits: (UInt32(u0) | r) &+ 0b0__1000_0001__1100_0001)
            }
            r |= UInt32(u0 & 0b0__11_1111)
            r &<<= 8
            if _fastPath(u0 & (0xF800 &>> 6) != (0xD800 &>> 6)) {
                u0 &>>= 6
                return EncodedScalar(
                    _biasedBits: (UInt32(u0) | r) &+ 0b0__1000_0001__1000_0001__1110_0001)
            }
        }
        else if _fastPath(FromEncoding.self == UTF8.self) {
            return _identityCast(content, to: UTF8.EncodedScalar.self)
        }
        return encode(FromEncoding.decode(content))
    }
    
    public struct ForwardParser {
        public typealias _Buffer = _UIntBuffer<UInt8>
        public init() { _buffer = _Buffer() }
        public var _buffer: _Buffer
    }
    
    public struct ReverseParser {
        public typealias _Buffer = _UIntBuffer<UInt8>
        public init() { _buffer = _Buffer() }
        public var _buffer: _Buffer
    }
}

extension UTF8.ReverseParser: Unicode.Parser, _UTFParser {
    public typealias Encoding = Unicode.UTF8
    public func _parseMultipleCodeUnits() -> (isValid: Bool, bitCount: UInt8) {
        _internalInvariant(_buffer._storage & 0x80 != 0) // this case handled elsewhere
        if _buffer._storage                & 0b0__1110_0000__1100_0000
            == 0b0__1100_0000__1000_0000 {
            // 2-byte sequence.  Top 4 bits of decoded result must be nonzero
            let top4Bits =  _buffer._storage & 0b0__0001_1110__0000_0000
            if _fastPath(top4Bits != 0) { return (true, 2*8) }
        }
        else if _buffer._storage     & 0b0__1111_0000__1100_0000__1100_0000
                    == 0b0__1110_0000__1000_0000__1000_0000 {
            // 3-byte sequence. The top 5 bits of the decoded result must be nonzero
            // and not a surrogate
            let top5Bits = _buffer._storage & 0b0__1111__0010_0000__0000_0000
            if _fastPath(
                top5Bits != 0 &&    top5Bits != 0b0__1101__0010_0000__0000_0000) {
                return (true, 3*8)
            }
        }
        else if _buffer._storage & 0b0__1111_1000__1100_0000__1100_0000__1100_0000
                    == 0b0__1111_0000__1000_0000__1000_0000__1000_0000 {
            // Make sure the top 5 bits of the decoded result would be in range
            let top5bits = _buffer._storage
                & 0b0__0111__0011_0000__0000_0000__0000_0000
            if _fastPath(
                top5bits != 0
                    && top5bits <=              0b0__0100__0000_0000__0000_0000__0000_0000
            ) { return (true, 4*8) }
        }
        return (false, _invalidLength() &* 8)
    }
    
    /// Returns the length of the invalid sequence that ends with the LSB of
    /// buffer.
    internal func _invalidLength() -> UInt8 {
        if _buffer._storage                 & 0b0__1111_0000__1100_0000
            == 0b0__1110_0000__1000_0000 {
            // 2-byte prefix of 3-byte sequence. The top 5 bits of the decoded result
            // must be nonzero and not a surrogate
            let top5Bits = _buffer._storage        & 0b0__1111__0010_0000
            if top5Bits != 0 &&          top5Bits != 0b0__1101__0010_0000 { return 2 }
        }
        else if _buffer._storage               & 0b1111_1000__1100_0000
                    == 0b1111_0000__1000_0000
        {
            // 2-byte prefix of 4-byte sequence
            // Make sure the top 5 bits of the decoded result would be in range
            let top5bits =        _buffer._storage & 0b0__0111__0011_0000
            if top5bits != 0 &&          top5bits <= 0b0__0100__0000_0000 { return 2 }
        }
        else if _buffer._storage & 0b0__1111_1000__1100_0000__1100_0000
                    == 0b0__1111_0000__1000_0000__1000_0000 {
            // 3-byte prefix of 4-byte sequence
            // Make sure the top 5 bits of the decoded result would be in range
            let top5bits = _buffer._storage & 0b0__0111__0011_0000__0000_0000
            if top5bits != 0 &&   top5bits <= 0b0__0100__0000_0000__0000_0000 {
                return 3
            }
        }
        return 1
    }
    
    @inline(__always)
    @inlinable
    public func _bufferedScalar(bitCount: UInt8) -> Encoding.EncodedScalar {
        let x = UInt32(truncatingIfNeeded: _buffer._storage.byteSwapped)
        let shift = 32 &- bitCount
        return Encoding.EncodedScalar(_biasedBits: (x &+ 0x01010101) &>> shift)
    }
}

extension Unicode.UTF8.ForwardParser: Unicode.Parser, _UTFParser {
    public typealias Encoding = Unicode.UTF8
    
    @inline(__always)
    @inlinable
    public func _parseMultipleCodeUnits() -> (isValid: Bool, bitCount: UInt8) {
        _internalInvariant(_buffer._storage & 0x80 != 0) // this case handled elsewhere
        
        if _buffer._storage & 0b0__1100_0000__1110_0000
            == 0b0__1000_0000__1100_0000 {
            // 2-byte sequence. At least one of the top 4 bits of the decoded result
            // must be nonzero.
            if _fastPath(_buffer._storage & 0b0_0001_1110 != 0) { return (true, 2*8) }
        }
        else if _buffer._storage         & 0b0__1100_0000__1100_0000__1111_0000
                    == 0b0__1000_0000__1000_0000__1110_0000 {
            // 3-byte sequence. The top 5 bits of the decoded result must be nonzero
            // and not a surrogate
            let top5Bits =          _buffer._storage & 0b0___0010_0000__0000_1111
            if _fastPath(top5Bits != 0 && top5Bits != 0b0___0010_0000__0000_1101) {
                return (true, 3*8)
            }
        }
        else if _buffer._storage & 0b0__1100_0000__1100_0000__1100_0000__1111_1000
                    == 0b0__1000_0000__1000_0000__1000_0000__1111_0000 {
            // 4-byte sequence.  The top 5 bits of the decoded result must be nonzero
            // and no greater than 0b0__0100_0000
            let top5bits = UInt16(_buffer._storage       & 0b0__0011_0000__0000_0111)
            if _fastPath(
                top5bits != 0
                    && top5bits.byteSwapped                   <= 0b0__0000_0100__0000_0000
            ) { return (true, 4*8) }
        }
        return (false, _invalidLength() &* 8)
    }
    
    /// Returns the length of the invalid sequence that starts with the LSB of
    /// buffer.
    @inline(never)
    @usableFromInline
    internal func _invalidLength() -> UInt8 {
        if _buffer._storage               & 0b0__1100_0000__1111_0000
            == 0b0__1000_0000__1110_0000 {
            // 2-byte prefix of 3-byte sequence. The top 5 bits of the decoded result
            // must be nonzero and not a surrogate
            let top5Bits = _buffer._storage & 0b0__0010_0000__0000_1111
            if top5Bits != 0 && top5Bits   != 0b0__0010_0000__0000_1101 { return 2 }
        }
        else if _buffer._storage                & 0b0__1100_0000__1111_1000
                    == 0b0__1000_0000__1111_0000
        {
            // Prefix of 4-byte sequence. The top 5 bits of the decoded result
            // must be nonzero and no greater than 0b0__0100_0000
            let top5bits = UInt16(_buffer._storage & 0b0__0011_0000__0000_0111)
            if top5bits != 0 && top5bits.byteSwapped <= 0b0__0000_0100__0000_0000 {
                return _buffer._storage   & 0b0__1100_0000__0000_0000__0000_0000
                    == 0b0__1000_0000__0000_0000__0000_0000 ? 3 : 2
            }
        }
        return 1
    }
    
    @inlinable
    public func _bufferedScalar(bitCount: UInt8) -> Encoding.EncodedScalar {
        let x = UInt32(_buffer._storage) &+ 0x01010101
        return _ValidUTF8Buffer(_biasedBits: x & ._lowBits(bitCount))
    }
}

