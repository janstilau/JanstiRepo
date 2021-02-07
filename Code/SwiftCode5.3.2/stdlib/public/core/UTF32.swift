extension Unicode {
  @frozen
  public enum UTF32 {
  case _swift3Codec
  }
}

// UTF-32 使用四个字节来表示存储代码点：把代码点转换为 32 位二进制，位数不够的左边充 0。
// 所以, 这个就是 Unicode.Scalar 的存储形式.
extension Unicode.UTF32: Unicode.Encoding {
  public typealias CodeUnit = UInt32
  public typealias EncodedScalar = CollectionOfOne<UInt32>

  @inlinable
  internal static var _replacementCodeUnit: CodeUnit {
    @inline(__always) get { return 0xFFFD }
  }

  @inlinable
  public static var encodedReplacementCharacter: EncodedScalar {
    return EncodedScalar(_replacementCodeUnit)
  }

  @inlinable
  @inline(__always)
  public static func _isScalar(_ x: CodeUnit) -> Bool {
    return true
  }

  /// Returns whether the given code unit represents an ASCII scalar
  @_alwaysEmitIntoClient
  public static func isASCII(_ x: CodeUnit) -> Bool {
    return x <= 0x7F
  }

  @inlinable
  @inline(__always)
  public static func decode(_ source: EncodedScalar) -> Unicode.Scalar {
    return Unicode.Scalar(_unchecked: source.first!)
  }

  @inlinable
  @inline(__always)
  public static func encode(
    _ source: Unicode.Scalar
  ) -> EncodedScalar? {
    return EncodedScalar(source.value)
  }
  
  @frozen
  public struct Parser {
    @inlinable
    public init() { }
  }
  
  public typealias ForwardParser = Parser
  public typealias ReverseParser = Parser
}

extension UTF32.Parser: Unicode.Parser {
  public typealias Encoding = Unicode.UTF32

  /// Parses a single Unicode scalar value from `input`.
  @inlinable
  public mutating func parseScalar<I: IteratorProtocol>(
    from input: inout I
  ) -> Unicode.ParseResult<Encoding.EncodedScalar>
  where I.Element == Encoding.CodeUnit {
    let n = input.next()
    if _fastPath(n != nil), let x = n {
      // Check code unit is valid: not surrogate-reserved and within range.
      guard _fastPath((x &>> 11) != 0b1101_1 && x <= 0x10ffff)
      else { return .error(length: 1) }
      
      // x is a valid scalar.
      return .valid(UTF32.EncodedScalar(x))
    }
    return .emptyInput
  }
}
