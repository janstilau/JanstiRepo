// Swift 里面的 char, 是以用户感知为基础的 user-perceived. one or more Unicode scalar values
//  Strings are collections of `Character` instances, so the number of visible characters is generally the most natural way to count the length of a string.

///     let greeting = "Hello! 🐥"
///     print("Length: \(greeting.count)")
///     Prints "Length: 8"


/// Because each character in a string can be made up of one or more Unicode
/// scalar values, the number of characters in a string may not match the
/// length of the Unicode scalar value representation or the length of the
/// string in a particular binary representation.


///     print("Unicode scalar value count: \(greeting.unicodeScalars.count)")
///     // Prints "Unicode scalar value count: 15"
// 从这里可以看出, 🐥 是好几个 unicode 字符的拼接.


///     print("UTF-8 representation count: \(greeting.utf8.count)")
///     // Prints "UTF-8 representation count: 18"


/// Every `Character` instance is composed of one or more Unicode scalar values
/// that are grouped together as an *extended grapheme cluster*. The way these
/// scalar values are grouped is defined by a canonical, localized, or
/// otherwise tailored Unicode segmentation algorithm.

public struct Character {
    internal var _str: String
    internal init(unchecked str: String) {
        self._str = str
    }
}

extension Character {
    public typealias UTF8View = String.UTF8View
    public var utf8: UTF8View { return _str.utf8 }
    
    public typealias UTF16View = String.UTF16View
    public var utf16: UTF16View { return _str.utf16 }
    
    public typealias UnicodeScalarView = String.UnicodeScalarView
    public var unicodeScalars: UnicodeScalarView { return _str.unicodeScalars }
}

extension Character :
    _ExpressibleByBuiltinExtendedGraphemeClusterLiteral,
    ExpressibleByExtendedGraphemeClusterLiteral
{
    /// Creates a character containing the given Unicode scalar value.
    ///
    /// - Parameter content: The Unicode scalar value to convert into a character.
    @inlinable @inline(__always)
    public init(_ content: Unicode.Scalar) {
        self.init(unchecked: String(content))
    }
    
    @inlinable @inline(__always)
    @_effects(readonly)
    public init(_builtinUnicodeScalarLiteral value: Builtin.Int32) {
        self.init(Unicode.Scalar(_builtinUnicodeScalarLiteral: value))
    }
    
    // Inlining ensures that the whole constructor can be folded away to a single
    // integer constant in case of small character literals.
    @inlinable @inline(__always)
    @_effects(readonly)
    public init(
        _builtinExtendedGraphemeClusterLiteral start: Builtin.RawPointer,
        utf8CodeUnitCount: Builtin.Word,
        isASCII: Builtin.Int1
    ) {
        self.init(unchecked: String(
                    _builtinExtendedGraphemeClusterLiteral: start,
                    utf8CodeUnitCount: utf8CodeUnitCount,
                    isASCII: isASCII))
    }
    
    /// Creates a character with the specified value.
    ///
    /// Do not call this initalizer directly. It is used by the compiler when
    /// you use a string literal to initialize a `Character` instance. For
    /// example:
    ///
    ///     let oBreve: Character = "o\u{306}"
    ///     print(oBreve)
    ///     // Prints "ŏ"
    ///
    /// The assignment to the `oBreve` constant calls this initializer behind the
    /// scenes.
    @inlinable @inline(__always)
    public init(extendedGraphemeClusterLiteral value: Character) {
        self.init(unchecked: value._str)
    }
    
    /// Creates a character from a single-character string.
    ///
    /// The following example creates a new character from the uppercase version
    /// of a string that only holds one character.
    ///
    ///     let a = "a"
    ///     let capitalA = Character(a.uppercased())
    ///
    /// - Parameter s: The single-character string to convert to a `Character`
    ///   instance. `s` must contain exactly one extended grapheme cluster.
    @inlinable @inline(__always)
    public init(_ s: String) {
        _precondition(!s.isEmpty,
                      "Can't form a Character from an empty String")
        _debugPrecondition(s.index(after: s.startIndex) == s.endIndex,
                           "Can't form a Character from a String containing more than one extended grapheme cluster")
        
        if _fastPath(s._guts._object.isPreferredRepresentation) {
            self.init(unchecked: s)
            return
        }
        self.init(unchecked: String._copying(s))
    }
}

extension Character: CustomStringConvertible {
    @inlinable
    public var description: String {
        return _str
    }
}

extension Character: LosslessStringConvertible { }

extension String {
    @inlinable @inline(__always)
    public init(_ c: Character) {
        self.init(c._str._guts)
    }
}

extension Character: Equatable {
    public static func == (lhs: Character, rhs: Character) -> Bool {
        return lhs._str == rhs._str
    }
}

extension Character: Comparable {
    public static func < (lhs: Character, rhs: Character) -> Bool {
        return lhs._str < rhs._str
    }
}

extension Character: Hashable {
    public func hash(into hasher: inout Hasher) {
        _str.hash(into: &hasher)
    }
}

extension Character {
    internal var _isSmall: Bool {
        return _str._guts.isSmall
    }
}
