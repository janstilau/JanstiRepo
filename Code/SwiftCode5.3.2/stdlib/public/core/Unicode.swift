import SwiftShims

// Conversions between different Unicode encodings.  Note that UTF-16 and
// UTF-32 decoding are *not* currently resilient to erroneous data.

/// The result of one Unicode decoding step.
///
/// Each `UnicodeDecodingResult` instance can represent a Unicode scalar value,
/// an indication that no more Unicode scalars are available, or an indication
/// of a decoding error.
@frozen
public enum UnicodeDecodingResult: Equatable {
    /// A decoded Unicode scalar value.
    case scalarValue(Unicode.Scalar)
    
    /// An indication that no more Unicode scalars are available in the input.
    case emptyInput
    
    /// An indication of a decoding error.
    case error
    
    @inlinable
    public static func == (
        lhs: UnicodeDecodingResult,
        rhs: UnicodeDecodingResult
    ) -> Bool {
        switch (lhs, rhs) {
        case (.scalarValue(let lhsScalar), .scalarValue(let rhsScalar)):
            return lhsScalar == rhsScalar
        case (.emptyInput, .emptyInput):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}

/// A Unicode encoding form that translates between Unicode scalar values and
/// form-specific code units.
///
/// The `UnicodeCodec` protocol declares methods that decode code unit
/// sequences into Unicode scalar values and encode Unicode scalar values
/// into code unit sequences. The standard library implements codecs for the
/// UTF-8, UTF-16, and UTF-32 encoding schemes as the `UTF8`, `UTF16`, and
/// `UTF32` types, respectively. Use the `Unicode.Scalar` type to work with
/// decoded Unicode scalar values.
public protocol UnicodeCodec: Unicode.Encoding {
    
    /// Creates an instance of the codec.
    init()
    
    /// Starts or continues decoding a code unit sequence into Unicode scalar
    /// values.
    ///
    /// To decode a code unit sequence completely, call this method repeatedly
    /// until it returns `UnicodeDecodingResult.emptyInput`. Checking that the
    /// iterator was exhausted is not sufficient, because the decoder can store
    /// buffered data from the input iterator.
    ///
    /// Because of buffering, it is impossible to find the corresponding position
    /// in the iterator for a given returned `Unicode.Scalar` or an error.
    ///
    /// The following example decodes the UTF-8 encoded bytes of a string into an
    /// array of `Unicode.Scalar` instances:
    ///
    ///     let str = "✨Unicode✨"
    ///     print(Array(str.utf8))
    ///     // Prints "[226, 156, 168, 85, 110, 105, 99, 111, 100, 101, 226, 156, 168]"
    ///
    ///     var bytesIterator = str.utf8.makeIterator()
    ///     var scalars: [Unicode.Scalar] = []
    ///     var utf8Decoder = UTF8()
    ///     Decode: while true {
    ///         switch utf8Decoder.decode(&bytesIterator) {
    ///         case .scalarValue(let v): scalars.append(v)
    ///         case .emptyInput: break Decode
    ///         case .error:
    ///             print("Decoding error")
    ///             break Decode
    ///         }
    ///     }
    ///     print(scalars)
    ///     // Prints "["\u{2728}", "U", "n", "i", "c", "o", "d", "e", "\u{2728}"]"
    ///
    /// - Parameter input: An iterator of code units to be decoded. `input` must be
    ///   the same iterator instance in repeated calls to this method. Do not
    ///   advance the iterator or any copies of the iterator outside this
    ///   method.
    /// - Returns: A `UnicodeDecodingResult` instance, representing the next
    ///   Unicode scalar, an indication of an error, or an indication that the
    ///   UTF sequence has been fully decoded.
    mutating func decode<I: IteratorProtocol>(
        _ input: inout I
    ) -> UnicodeDecodingResult where I.Element == CodeUnit
    
    /// Encodes a Unicode scalar as a series of code units by calling the given
    /// closure on each code unit.
    ///
    /// For example, the musical fermata symbol ("𝄐") is a single Unicode scalar
    /// value (`\u{1D110}`) but requires four code units for its UTF-8
    /// representation. The following code uses the `UTF8` codec to encode a
    /// fermata in UTF-8:
    ///
    ///     var bytes: [UTF8.CodeUnit] = []
    ///     UTF8.encode("𝄐", into: { bytes.append($0) })
    ///     print(bytes)
    ///     // Prints "[240, 157, 132, 144]"
    ///
    /// - Parameters:
    ///   - input: The Unicode scalar value to encode.
    ///   - processCodeUnit: A closure that processes one code unit argument at a
    ///     time.
    static func encode(
        _ input: Unicode.Scalar,
        into processCodeUnit: (CodeUnit) -> Void
    )
    
    /// Searches for the first occurrence of a `CodeUnit` that is equal to 0.
    ///
    /// Is an equivalent of `strlen` for C-strings.
    ///
    /// - Complexity: O(*n*)
    static func _nullCodeUnitOffset(in input: UnsafePointer<CodeUnit>) -> Int
}

/// A codec for translating between Unicode scalar values and UTF-8 code
/// units.
extension Unicode.UTF8: UnicodeCodec {
    /// Creates an instance of the UTF-8 codec.
    @inlinable
    public init() { self = ._swift3Buffer(ForwardParser()) }
    
    /// Starts or continues decoding a UTF-8 sequence.
    ///
    /// To decode a code unit sequence completely, call this method repeatedly
    /// until it returns `UnicodeDecodingResult.emptyInput`. Checking that the
    /// iterator was exhausted is not sufficient, because the decoder can store
    /// buffered data from the input iterator.
    ///
    /// Because of buffering, it is impossible to find the corresponding position
    /// in the iterator for a given returned `Unicode.Scalar` or an error.
    ///
    /// The following example decodes the UTF-8 encoded bytes of a string into an
    /// array of `Unicode.Scalar` instances. This is a demonstration only---if
    /// you need the Unicode scalar representation of a string, use its
    /// `unicodeScalars` view.
    ///
    ///     let str = "✨Unicode✨"
    ///     print(Array(str.utf8))
    ///     // Prints "[226, 156, 168, 85, 110, 105, 99, 111, 100, 101, 226, 156, 168]"
    ///
    ///     var bytesIterator = str.utf8.makeIterator()
    ///     var scalars: [Unicode.Scalar] = []
    ///     var utf8Decoder = UTF8()
    ///     Decode: while true {
    ///         switch utf8Decoder.decode(&bytesIterator) {
    ///         case .scalarValue(let v): scalars.append(v)
    ///         case .emptyInput: break Decode
    ///         case .error:
    ///             print("Decoding error")
    ///             break Decode
    ///         }
    ///     }
    ///     print(scalars)
    ///     // Prints "["\u{2728}", "U", "n", "i", "c", "o", "d", "e", "\u{2728}"]"
    ///
    /// - Parameter input: An iterator of code units to be decoded. `input` must be
    ///   the same iterator instance in repeated calls to this method. Do not
    ///   advance the iterator or any copies of the iterator outside this
    ///   method.
    /// - Returns: A `UnicodeDecodingResult` instance, representing the next
    ///   Unicode scalar, an indication of an error, or an indication that the
    ///   UTF sequence has been fully decoded.
    @inlinable
    @inline(__always)
    public mutating func decode<I: IteratorProtocol>(
        _ input: inout I
    ) -> UnicodeDecodingResult where I.Element == CodeUnit {
        guard case ._swift3Buffer(var parser) = self else {
            Builtin.unreachable()
        }
        defer { self = ._swift3Buffer(parser) }
        
        switch parser.parseScalar(from: &input) {
        case .valid(let s): return .scalarValue(UTF8.decode(s))
        case .error: return .error
        case .emptyInput: return .emptyInput
        }
    }
    
    /// Attempts to decode a single UTF-8 code unit sequence starting at the LSB
    /// of `buffer`.
    ///
    /// - Returns:
    ///   - result: The decoded code point if the code unit sequence is
    ///     well-formed; `nil` otherwise.
    ///   - length: The length of the code unit sequence in bytes if it is
    ///     well-formed; otherwise the *maximal subpart of the ill-formed
    ///     sequence* (Unicode 8.0.0, Ch 3.9, D93b), i.e. the number of leading
    ///     code units that were valid or 1 in case none were valid.  Unicode
    ///     recommends to skip these bytes and replace them by a single
    ///     replacement character (U+FFFD).
    ///
    /// - Requires: There is at least one used byte in `buffer`, and the unused
    ///   space in `buffer` is filled with some value not matching the UTF-8
    ///   continuation byte form (`0b10xxxxxx`).
    @inlinable
    public // @testable
    static func _decodeOne(_ buffer: UInt32) -> (result: UInt32?, length: UInt8) {
        // Note the buffer is read least significant byte first: [ #3 #2 #1 #0 ].
        
        if buffer & 0x80 == 0 { // 1-byte sequence (ASCII), buffer: [ ... ... ... CU0 ].
            let value = buffer & 0xff
            return (value, 1)
        }
        var p = ForwardParser()
        p._buffer._storage = buffer
        p._buffer._bitCount = 32
        var i = EmptyCollection<UInt8>().makeIterator()
        switch p.parseScalar(from: &i) {
        case .valid(let s):
            return (
                result: UTF8.decode(s).value,
                length: UInt8(truncatingIfNeeded: s.count))
        case .error(let l):
            return (result: nil, length: UInt8(truncatingIfNeeded: l))
        case .emptyInput: Builtin.unreachable()
        }
    }
    
    /// Encodes a Unicode scalar as a series of code units by calling the given
    /// closure on each code unit.
    ///
    /// For example, the musical fermata symbol ("𝄐") is a single Unicode scalar
    /// value (`\u{1D110}`) but requires four code units for its UTF-8
    /// representation. The following code encodes a fermata in UTF-8:
    ///
    ///     var bytes: [UTF8.CodeUnit] = []
    ///     UTF8.encode("𝄐", into: { bytes.append($0) })
    ///     print(bytes)
    ///     // Prints "[240, 157, 132, 144]"
    ///
    /// - Parameters:
    ///   - input: The Unicode scalar value to encode.
    ///   - processCodeUnit: A closure that processes one code unit argument at a
    ///     time.
    @inlinable
    @inline(__always)
    public static func encode(
        _ input: Unicode.Scalar,
        into processCodeUnit: (CodeUnit) -> Void
    ) {
        var s = encode(input)!._biasedBits
        processCodeUnit(UInt8(truncatingIfNeeded: s) &- 0x01)
        s &>>= 8
        if _fastPath(s == 0) { return }
        processCodeUnit(UInt8(truncatingIfNeeded: s) &- 0x01)
        s &>>= 8
        if _fastPath(s == 0) { return }
        processCodeUnit(UInt8(truncatingIfNeeded: s) &- 0x01)
        s &>>= 8
        if _fastPath(s == 0) { return }
        processCodeUnit(UInt8(truncatingIfNeeded: s) &- 0x01)
    }
    
    /// Returns a Boolean value indicating whether the specified code unit is a
    /// UTF-8 continuation byte.
    ///
    /// Continuation bytes take the form `0b10xxxxxx`. For example, a lowercase
    /// "e" with an acute accent above it (`"é"`) uses 2 bytes for its UTF-8
    /// representation: `0b11000011` (195) and `0b10101001` (169). The second
    /// byte is a continuation byte.
    ///
    ///     let eAcute = "é"
    ///     for codeUnit in eAcute.utf8 {
    ///         print(codeUnit, UTF8.isContinuation(codeUnit))
    ///     }
    ///     // Prints "195 false"
    ///     // Prints "169 true"
    ///
    /// - Parameter byte: A UTF-8 code unit.
    /// - Returns: `true` if `byte` is a continuation byte; otherwise, `false`.
    @inlinable
    public static func isContinuation(_ byte: CodeUnit) -> Bool {
        return byte & 0b11_00__0000 == 0b10_00__0000
    }
    
    @inlinable
    public static func _nullCodeUnitOffset(
        in input: UnsafePointer<CodeUnit>
    ) -> Int {
        return Int(_swift_stdlib_strlen_unsigned(input))
    }
    // Support parsing C strings as-if they are UTF8 strings.
    @inlinable
    public static func _nullCodeUnitOffset(
        in input: UnsafePointer<CChar>
    ) -> Int {
        return Int(_swift_stdlib_strlen(input))
    }
}

/// A codec for translating between Unicode scalar values and UTF-16 code
/// units.
extension Unicode.UTF16: UnicodeCodec {
    /// Creates an instance of the UTF-16 codec.
    @inlinable
    public init() { self = ._swift3Buffer(ForwardParser()) }
    
    /// Starts or continues decoding a UTF-16 sequence.
    ///
    /// To decode a code unit sequence completely, call this method repeatedly
    /// until it returns `UnicodeDecodingResult.emptyInput`. Checking that the
    /// iterator was exhausted is not sufficient, because the decoder can store
    /// buffered data from the input iterator.
    ///
    /// Because of buffering, it is impossible to find the corresponding position
    /// in the iterator for a given returned `Unicode.Scalar` or an error.
    ///
    /// The following example decodes the UTF-16 encoded bytes of a string into an
    /// array of `Unicode.Scalar` instances. This is a demonstration only---if
    /// you need the Unicode scalar representation of a string, use its
    /// `unicodeScalars` view.
    ///
    ///     let str = "✨Unicode✨"
    ///     print(Array(str.utf16))
    ///     // Prints "[10024, 85, 110, 105, 99, 111, 100, 101, 10024]"
    ///
    ///     var codeUnitIterator = str.utf16.makeIterator()
    ///     var scalars: [Unicode.Scalar] = []
    ///     var utf16Decoder = UTF16()
    ///     Decode: while true {
    ///         switch utf16Decoder.decode(&codeUnitIterator) {
    ///         case .scalarValue(let v): scalars.append(v)
    ///         case .emptyInput: break Decode
    ///         case .error:
    ///             print("Decoding error")
    ///             break Decode
    ///         }
    ///     }
    ///     print(scalars)
    ///     // Prints "["\u{2728}", "U", "n", "i", "c", "o", "d", "e", "\u{2728}"]"
    ///
    /// - Parameter input: An iterator of code units to be decoded. `input` must be
    ///   the same iterator instance in repeated calls to this method. Do not
    ///   advance the iterator or any copies of the iterator outside this
    ///   method.
    /// - Returns: A `UnicodeDecodingResult` instance, representing the next
    ///   Unicode scalar, an indication of an error, or an indication that the
    ///   UTF sequence has been fully decoded.
    @inlinable
    public mutating func decode<I: IteratorProtocol>(
        _ input: inout I
    ) -> UnicodeDecodingResult where I.Element == CodeUnit {
        guard case ._swift3Buffer(var parser) = self else {
            Builtin.unreachable()
        }
        defer { self = ._swift3Buffer(parser) }
        switch parser.parseScalar(from: &input) {
        case .valid(let s): return .scalarValue(UTF16.decode(s))
        case .error: return .error
        case .emptyInput: return .emptyInput
        }
    }
    
    /// Try to decode one Unicode scalar, and return the actual number of code
    /// units it spanned in the input.  This function may consume more code
    /// units than required for this scalar.
    @inlinable
    internal mutating func _decodeOne<I: IteratorProtocol>(
        _ input: inout I
    ) -> (UnicodeDecodingResult, Int) where I.Element == CodeUnit {
        let result = decode(&input)
        switch result {
        case .scalarValue(let us):
            return (result, UTF16.width(us))
            
        case .emptyInput:
            return (result, 0)
            
        case .error:
            return (result, 1)
        }
    }
    
    /// Encodes a Unicode scalar as a series of code units by calling the given
    /// closure on each code unit.
    ///
    /// For example, the musical fermata symbol ("𝄐") is a single Unicode scalar
    /// value (`\u{1D110}`) but requires two code units for its UTF-16
    /// representation. The following code encodes a fermata in UTF-16:
    ///
    ///     var codeUnits: [UTF16.CodeUnit] = []
    ///     UTF16.encode("𝄐", into: { codeUnits.append($0) })
    ///     print(codeUnits)
    ///     // Prints "[55348, 56592]"
    ///
    /// - Parameters:
    ///   - input: The Unicode scalar value to encode.
    ///   - processCodeUnit: A closure that processes one code unit argument at a
    ///     time.
    @inlinable
    public static func encode(
        _ input: Unicode.Scalar,
        into processCodeUnit: (CodeUnit) -> Void
    ) {
        var s = encode(input)!._storage
        processCodeUnit(UInt16(truncatingIfNeeded: s))
        s &>>= 16
        if _fastPath(s == 0) { return }
        processCodeUnit(UInt16(truncatingIfNeeded: s))
    }
}

/// A codec for translating between Unicode scalar values and UTF-32 code
/// units.
extension Unicode.UTF32: UnicodeCodec {
    /// Creates an instance of the UTF-32 codec.
    @inlinable
    public init() { self = ._swift3Codec }
    
    /// Starts or continues decoding a UTF-32 sequence.
    ///
    /// To decode a code unit sequence completely, call this method repeatedly
    /// until it returns `UnicodeDecodingResult.emptyInput`. Checking that the
    /// iterator was exhausted is not sufficient, because the decoder can store
    /// buffered data from the input iterator.
    ///
    /// Because of buffering, it is impossible to find the corresponding position
    /// in the iterator for a given returned `Unicode.Scalar` or an error.
    ///
    /// The following example decodes the UTF-16 encoded bytes of a string
    /// into an array of `Unicode.Scalar` instances. This is a demonstration
    /// only---if you need the Unicode scalar representation of a string, use
    /// its `unicodeScalars` view.
    ///
    ///     // UTF-32 representation of "✨Unicode✨"
    ///     let codeUnits: [UTF32.CodeUnit] =
    ///             [10024, 85, 110, 105, 99, 111, 100, 101, 10024]
    ///
    ///     var codeUnitIterator = codeUnits.makeIterator()
    ///     var scalars: [Unicode.Scalar] = []
    ///     var utf32Decoder = UTF32()
    ///     Decode: while true {
    ///         switch utf32Decoder.decode(&codeUnitIterator) {
    ///         case .scalarValue(let v): scalars.append(v)
    ///         case .emptyInput: break Decode
    ///         case .error:
    ///             print("Decoding error")
    ///             break Decode
    ///         }
    ///     }
    ///     print(scalars)
    ///     // Prints "["\u{2728}", "U", "n", "i", "c", "o", "d", "e", "\u{2728}"]"
    ///
    /// - Parameter input: An iterator of code units to be decoded. `input` must be
    ///   the same iterator instance in repeated calls to this method. Do not
    ///   advance the iterator or any copies of the iterator outside this
    ///   method.
    /// - Returns: A `UnicodeDecodingResult` instance, representing the next
    ///   Unicode scalar, an indication of an error, or an indication that the
    ///   UTF sequence has been fully decoded.
    @inlinable
    public mutating func decode<I: IteratorProtocol>(
        _ input: inout I
    ) -> UnicodeDecodingResult where I.Element == CodeUnit {
        var parser = ForwardParser()
        
        switch parser.parseScalar(from: &input) {
        case .valid(let s): return .scalarValue(UTF32.decode(s))
        case .error:      return .error
        case .emptyInput:   return .emptyInput
        }
    }
    
    /// Encodes a Unicode scalar as a UTF-32 code unit by calling the given
    /// closure.
    ///
    /// For example, like every Unicode scalar, the musical fermata symbol ("𝄐")
    /// can be represented in UTF-32 as a single code unit. The following code
    /// encodes a fermata in UTF-32:
    ///
    ///     var codeUnit: UTF32.CodeUnit = 0
    ///     UTF32.encode("𝄐", into: { codeUnit = $0 })
    ///     print(codeUnit)
    ///     // Prints "119056"
    ///
    /// - Parameters:
    ///   - input: The Unicode scalar value to encode.
    ///   - processCodeUnit: A closure that processes one code unit argument at a
    ///     time.
    @inlinable
    public static func encode(
        _ input: Unicode.Scalar,
        into processCodeUnit: (CodeUnit) -> Void
    ) {
        processCodeUnit(UInt32(input))
    }
}

/// Translates the given input from one Unicode encoding to another by calling
/// the given closure.
///
/// The following example transcodes the UTF-8 representation of the string
/// `"Fermata 𝄐"` into UTF-32.
///
///     let fermata = "Fermata 𝄐"
///     let bytes = fermata.utf8
///     print(Array(bytes))
///     // Prints "[70, 101, 114, 109, 97, 116, 97, 32, 240, 157, 132, 144]"
///
///     var codeUnits: [UTF32.CodeUnit] = []
///     let sink = { codeUnits.append($0) }
///     transcode(bytes.makeIterator(), from: UTF8.self, to: UTF32.self,
///               stoppingOnError: false, into: sink)
///     print(codeUnits)
///     // Prints "[70, 101, 114, 109, 97, 116, 97, 32, 119056]"
///
/// The `sink` closure is called with each resulting UTF-32 code unit as the
/// function iterates over its input.
///
/// - Parameters:
///   - input: An iterator of code units to be translated, encoded as
///     `inputEncoding`. If `stopOnError` is `false`, the entire iterator will
///     be exhausted. Otherwise, iteration will stop if an encoding error is
///     detected.
///   - inputEncoding: The Unicode encoding of `input`.
///   - outputEncoding: The destination Unicode encoding.
///   - stopOnError: Pass `true` to stop translation when an encoding error is
///     detected in `input`. Otherwise, a Unicode replacement character
///     (`"\u{FFFD}"`) is inserted for each detected error.
///   - processCodeUnit: A closure that processes one `outputEncoding` code
///     unit at a time.
/// - Returns: `true` if the translation detected encoding errors in `input`;
///   otherwise, `false`.
@inlinable
@inline(__always)
public func transcode<
    Input: IteratorProtocol,
    InputEncoding: Unicode.Encoding,
    OutputEncoding: Unicode.Encoding
>(
    _ input: Input,
    from inputEncoding: InputEncoding.Type,
    to outputEncoding: OutputEncoding.Type,
    stoppingOnError stopOnError: Bool,
    into processCodeUnit: (OutputEncoding.CodeUnit) -> Void
) -> Bool
where InputEncoding.CodeUnit == Input.Element {
    var input = input
    
    // NB.  It is not possible to optimize this routine to a memcpy if
    // InputEncoding == OutputEncoding.  The reason is that memcpy will not
    // substitute U+FFFD replacement characters for ill-formed sequences.
    
    var p = InputEncoding.ForwardParser()
    var hadError = false
    loop:
    while true {
        switch p.parseScalar(from: &input) {
        case .valid(let s):
            let t = OutputEncoding.transcode(s, from: inputEncoding)
            guard _fastPath(t != nil), let s = t else { break }
            s.forEach(processCodeUnit)
            continue loop
        case .emptyInput:
            return hadError
        case .error:
            if _slowPath(stopOnError) { return true }
            hadError = true
        }
        OutputEncoding.encodedReplacementCharacter.forEach(processCodeUnit)
    }
}

/// Instances of conforming types are used in internal `String`
/// representation.
public // @testable
protocol _StringElement {
    static func _toUTF16CodeUnit(_: Self) -> UTF16.CodeUnit
    
    static func _fromUTF16CodeUnit(_ utf16: UTF16.CodeUnit) -> Self
}

extension UTF16.CodeUnit: _StringElement {
    @inlinable
    public // @testable
    static func _toUTF16CodeUnit(_ x: UTF16.CodeUnit) -> UTF16.CodeUnit {
        return x
    }
    @inlinable
    public // @testable
    static func _fromUTF16CodeUnit(
        _ utf16: UTF16.CodeUnit
    ) -> UTF16.CodeUnit {
        return utf16
    }
}

extension UTF8.CodeUnit: _StringElement {
    @inlinable
    public // @testable
    static func _toUTF16CodeUnit(_ x: UTF8.CodeUnit) -> UTF16.CodeUnit {
        _internalInvariant(x <= 0x7f, "should only be doing this with ASCII")
        return UTF16.CodeUnit(truncatingIfNeeded: x)
    }
    @inlinable
    public // @testable
    static func _fromUTF16CodeUnit(
        _ utf16: UTF16.CodeUnit
    ) -> UTF8.CodeUnit {
        _internalInvariant(utf16 <= 0x7f, "should only be doing this with ASCII")
        return UTF8.CodeUnit(truncatingIfNeeded: utf16)
    }
}

// Unchecked init to avoid precondition branches in hot code paths where we
// already know the value is a valid unicode scalar.
extension Unicode.Scalar {
    /// Create an instance with numeric value `value`, bypassing the regular
    /// precondition checks for code point validity.
    @inlinable
    internal init(_unchecked value: UInt32) {
        _internalInvariant(value < 0xD800 || value > 0xDFFF,
                           "high- and low-surrogate code points are not valid Unicode scalar values")
        _internalInvariant(value <= 0x10FFFF, "value is outside of Unicode codespace")
        
        self._value = value
    }
}

extension UnicodeCodec {
    @inlinable
    public static func _nullCodeUnitOffset(
        in input: UnsafePointer<CodeUnit>
    ) -> Int {
        var length = 0
        while input[length] != 0 {
            length += 1
        }
        return length
    }
}

@available(*, unavailable, message: "use 'transcode(_:from:to:stoppingOnError:into:)'")
public func transcode<Input, InputEncoding, OutputEncoding>(
    _ inputEncoding: InputEncoding.Type, _ outputEncoding: OutputEncoding.Type,
    _ input: Input, _ output: (OutputEncoding.CodeUnit) -> Void,
    stopOnError: Bool
) -> Bool
where
    Input: IteratorProtocol,
    InputEncoding: UnicodeCodec,
    OutputEncoding: UnicodeCodec,
    InputEncoding.CodeUnit == Input.Element {
    Builtin.unreachable()
}

// Swift 里面, 命名空间是 enum NameSpace 这样的方式来进行的.
// 这样, 所有的数据, 在 extension Unicode 里面定义就可以了. 而因为是 Enum, 是没有数据部分的.
// https://zh.wikipedia.org/wiki/Unicode Unicode 维基百科
// http://www.ruanyifeng.com/blog/2007/10/ascii_unicode_and_utf-8.html 阮一峰整理的字符编码
public enum Unicode {}


/*
 可以想象，如果有一种编码，将世界上所有的符号都纳入其中。每一个符号都给予一个独一无二的编码，那么乱码问题就会消失。这就是 Unicode，就像它的名字都表示的，这是一种所有符号的编码。
 这里就有两个严重的问题，第一个问题是，如何才能区别 Unicode 和 ASCII ？计算机怎么知道三个字节表示一个符号，而不是分别表示三个符号呢？
 第二个问题是，我们已经知道，英文字母只用一个字节表示就够了，如果 Unicode 统一规定，每个符号用三个或四个字节表示，那么每个英文字母前都必然有二到三个字节是0，这对于存储来说是极大的浪费，文本文件的大小会因此大出二三倍，这是无法接受的。
 
 它们造成的结果是：1）出现了 Unicode 的多种存储方式，也就是说有许多种不同的二进制格式，可以用来表示 Unicode。2）Unicode 在很长一段时间内无法推广，直到互联网的出现。
 
 UTF-8 的编码规则很简单，只有二条：
 1）对于单字节的符号，字节的第一位设为0，后面7位为这个符号的 Unicode 码。因此对于英语字母，UTF-8 编码和 ASCII 码是相同的。
 2）对于n字节的符号（n > 1），第一个字节的前n位都设为1，第n + 1位设为0，后面字节的前两位一律设为10。剩下的没有提及的二进制位，全部为这个符号的 Unicode 码。
 严的 Unicode 是4E25（100111000100101），根据上表，可以发现4E25处在第三行的范围内（0000 0800 - 0000 FFFF），因此严的 UTF-8 编码需要三个字节，即格式是1110xxxx 10xxxxxx 10xxxxxx。然后，从严的最后一个二进制位开始，依次从后向前填入格式中的x，多出的位补0。这样就得到了，严的 UTF-8 编码是11100100 10111000 10100101，转换成十六进制就是E4B8A5。
 Unicode码范围
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

 
 UTF-16
 
 UTF-16最少也会用2 Byte来表示一个字符
 U+0000~U+FFFF
 2 Byte存储，编码后等于Unicode值

 U+10000~U+10FFFF
 4 Byte存储，现将Unicode值减去（0x10000），得到20bit长的值。
 再将Unicode分为高10位和低10位。
 UTF-16编码的高位是2 Byte，高10位Unicode范围为0-0x3FF，将Unicode值加上0XD800，得到高位代理（或称为前导代理，存储高位）；
 低位也是2 Byte，低十位Unicode范围一样为0~0x3FF，将Unicode值加上0xDC00,得到低位代理（或称为后尾代理，存储低位）
 
 https://zhuanlan.zhihu.com/p/27827951
 
 UTF16 要么是 4 个字节, 要么是 2 个字节. 如果是基本平面, 也就是 Unicode 编码比较小, 直接 2 个字节表示.
 如果 Unicode 编码比较大, 那么就前两个字节表示一部分, 后两个字节表示一部分. 前两个自己表示的那部分, 会落在基本平面的一个特殊的区域, 那个特殊区域是不表示字符的, 后两个字节也是同样的原理.
 当发现, 两个字节的数据, 是在这个特殊的区域, 就知道, 应该使用代理对来获取真正的 unicode 数据. 
 */

