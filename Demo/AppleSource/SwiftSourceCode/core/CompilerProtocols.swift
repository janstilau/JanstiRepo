/// A type that can be converted to and from an associated raw value.

/// 实现了该协议, 也就代表着, 类型可以从当前值, 和原始值之间进行切换.
/// 其实这是一个非常常见的事情, 比例, NSDate, 仅仅是一个普普通通的时间戳的封装而已.
/// 实现了这个协议, 就是告诉外界, 自己的核心数据类型, 仅仅是一些简单的值, 但是自己提供了很多的方法, 让这个类型, 表示了一层类名代表的含义.
///
/// Enumerations with Raw Values
/// ============================
///
/// Option Sets
/// Option Sets 来做这种 或 的操作, 而 Enum, 每一个值, 都是确定的, 都是和一个 rawValue 进行绑定的.
///
/// ===========
public protocol RawRepresentable {
  
  associatedtype RawValue
  init?(rawValue: RawValue)
  /*
     一个计算属性
     实现类内部可以存储这个值, 也可以只是方法.
     对于 NSDate 这种, 根据不同的 rawValue 值, 进行值的表示的类型来说, rawValue 就是核心数据, 一定是存储起来的.
     */
  var rawValue: RawValue { get }
}

@inlinable // trivial-implementation
public func == <T: RawRepresentable>(lhs: T, rhs: T) -> Bool
  where T.RawValue: Equatable {
  return lhs.rawValue == rhs.rawValue
}

@inlinable // trivial-implementation
public func != <T: RawRepresentable>(lhs: T, rhs: T) -> Bool
  where T.RawValue: Equatable {
  return lhs.rawValue != rhs.rawValue
}

public func != <T: Equatable>(lhs: T, rhs: T) -> Bool
  where T: RawRepresentable, T.RawValue: Equatable {
  return lhs.rawValue != rhs.rawValue
}

extension RawRepresentable where RawValue: Hashable, Self: Hashable {
  @inlinable // trivial
  public var hashValue: Int {
    return rawValue.hashValue
  }

  @inlinable // trivial
  public func hash(into hasher: inout Hasher) {
    hasher.combine(rawValue)
  }

  @inlinable // trivial
  public func _rawHashValue(seed: Int) -> Int {
    var hasher = Hasher(_seed: seed)
    self.hash(into: &hasher)
    return hasher._finalize()
  }
}






/// A type that provides a collection of all of its values.
///
/// Types that conform to the `CaseIterable` protocol are typically
/// enumerations without associated values. When using a `CaseIterable` type,
/// you can access a collection of all of the type's cases by using the type's
/// `allCases` property.
///
/// For example, the `CompassDirection` enumeration declared in this example
/// conforms to `CaseIterable`. You access the number of cases and the cases
/// themselves through `CompassDirection.allCases`.
///
///     enum CompassDirection: CaseIterable {
///         case north, south, east, west
///     }
/// 
///     print("There are \(CompassDirection.allCases.count) directions.")
///     // Prints "There are 4 directions."
///     let caseList = CompassDirection.allCases
///                                    .map({ "\($0)" })
///                                    .joined(separator: ", ")
///     // caseList == "north, south, east, west"
///
/// Conforming to the CaseIterable Protocol
/// =======================================
///
/// The compiler can automatically provide an implementation of the
/// `CaseIterable` requirements for any enumeration without associated values
/// or `@available` attributes on its cases. The synthesized `allCases`
/// collection provides the cases in order of their declaration.
///
/// You can take advantage of this compiler support when defining your own
/// custom enumeration by declaring conformance to `CaseIterable` in the
/// enumeration's original declaration. The `CompassDirection` example above
/// demonstrates this automatic implementation.
public protocol CaseIterable {
  /// A type that can represent a collection of all values of this type.
  associatedtype AllCases: Collection
    where AllCases.Element == Self
  
  /// A collection of all values of this type.
  static var allCases: AllCases { get }
}

/// A type that can be initialized using the nil literal, `nil`.
///
/// `nil` has a specific meaning in Swift---the absence of a value. Only the
/// `Optional` type conforms to `ExpressibleByNilLiteral`.
/// `ExpressibleByNilLiteral` conformance for types that use `nil` for other
/// purposes is discouraged.
public protocol ExpressibleByNilLiteral {
  /// Creates an instance initialized with `nil`.
  init(nilLiteral: ())
}

public protocol _ExpressibleByBuiltinIntegerLiteral {
  init(_builtinIntegerLiteral value: Builtin.IntLiteral)
}

/// A type that can be initialized with an integer literal.
///
/// The standard library integer and floating-point types, such as `Int` and
/// `Double`, conform to the `ExpressibleByIntegerLiteral` protocol. You can
/// initialize a variable or constant of any of these types by assigning an
/// integer literal.
///
///     // Type inferred as 'Int'
///     let cookieCount = 12
///
///     // An array of 'Int'
///     let chipsPerCookie = [21, 22, 25, 23, 24, 19]
///
///     // A floating-point value initialized using an integer literal
///     let redPercentage: Double = 1
///     // redPercentage == 1.0
///
/// Conforming to ExpressibleByIntegerLiteral
/// =========================================
///
/// To add `ExpressibleByIntegerLiteral` conformance to your custom type,
/// implement the required initializer.
public protocol ExpressibleByIntegerLiteral {
  /// A type that represents an integer literal.
  ///
  /// The standard library integer and floating-point types are all valid types
  /// for `IntegerLiteralType`.
  associatedtype IntegerLiteralType: _ExpressibleByBuiltinIntegerLiteral

  /// Creates an instance initialized to the specified integer value.
  ///
  /// Do not call this initializer directly. Instead, initialize a variable or
  /// constant using an integer literal. For example:
  ///
  ///     let x = 23
  ///
  /// In this example, the assignment to the `x` constant calls this integer
  /// literal initializer behind the scenes.
  ///
  /// - Parameter value: The value to create.
  init(integerLiteral value: IntegerLiteralType)
}

public protocol _ExpressibleByBuiltinFloatLiteral {
  init(_builtinFloatLiteral value: _MaxBuiltinFloatType)
}

/// A type that can be initialized with a floating-point literal.
///
/// The standard library floating-point types---`Float`, `Double`, and
/// `Float80` where available---all conform to the `ExpressibleByFloatLiteral`
/// protocol. You can initialize a variable or constant of any of these types
/// by assigning a floating-point literal.
///
///     // Type inferred as 'Double'
///     let threshold = 6.0
///
///     // An array of 'Double'
///     let measurements = [2.2, 4.1, 3.65, 4.2, 9.1]
///
/// Conforming to ExpressibleByFloatLiteral
/// =======================================
///
/// To add `ExpressibleByFloatLiteral` conformance to your custom type,
/// implement the required initializer.
public protocol ExpressibleByFloatLiteral {
  /// A type that represents a floating-point literal.
  ///
  /// Valid types for `FloatLiteralType` are `Float`, `Double`, and `Float80`
  /// where available.
  associatedtype FloatLiteralType: _ExpressibleByBuiltinFloatLiteral
  
  /// Creates an instance initialized to the specified floating-point value.
  ///
  /// Do not call this initializer directly. Instead, initialize a variable or
  /// constant using a floating-point literal. For example:
  ///
  ///     let x = 21.5
  ///
  /// In this example, the assignment to the `x` constant calls this
  /// floating-point literal initializer behind the scenes.
  ///
  /// - Parameter value: The value to create.
  init(floatLiteral value: FloatLiteralType)
}

public protocol _ExpressibleByBuiltinBooleanLiteral {
  init(_builtinBooleanLiteral value: Builtin.Int1)
}

/// A type that can be initialized with the Boolean literals `true` and
/// `false`.
///
/// `Bool`, `DarwinBoolean`, `ObjCBool`, and `WindowsBool` are treated as
/// Boolean values. Expanding this set to include types that represent more than
/// simple Boolean values is discouraged.
///
/// To add `ExpressibleByBooleanLiteral` conformance to your custom type,
/// implement the `init(booleanLiteral:)` initializer that creates an instance
/// of your type with the given Boolean value.
public protocol ExpressibleByBooleanLiteral {
  /// A type that represents a Boolean literal, such as `Bool`.
  associatedtype BooleanLiteralType: _ExpressibleByBuiltinBooleanLiteral

  /// Creates an instance initialized to the given Boolean value.
  ///
  /// Do not call this initializer directly. Instead, initialize a variable or
  /// constant using one of the Boolean literals `true` and `false`. For
  /// example:
  ///
  ///     let twasBrillig = true
  ///
  /// In this example, the assignment to the `twasBrillig` constant calls this
  /// Boolean literal initializer behind the scenes.
  ///
  /// - Parameter value: The value of the new instance.
  init(booleanLiteral value: BooleanLiteralType)
}

public protocol _ExpressibleByBuiltinUnicodeScalarLiteral {
  init(_builtinUnicodeScalarLiteral value: Builtin.Int32)
}

/// A type that can be initialized with a string literal containing a single
/// Unicode scalar value.
///
/// The `String`, `StaticString`, `Character`, and `Unicode.Scalar` types all
/// conform to the `ExpressibleByUnicodeScalarLiteral` protocol. You can
/// initialize a variable of any of these types using a string literal that
/// holds a single Unicode scalar.
///
///     let ñ: Unicode.Scalar = "ñ"
///     print(ñ)
///     // Prints "ñ"
///
/// Conforming to ExpressibleByUnicodeScalarLiteral
/// ===============================================
///
/// To add `ExpressibleByUnicodeScalarLiteral` conformance to your custom type,
/// implement the required initializer.
public protocol ExpressibleByUnicodeScalarLiteral {
  /// A type that represents a Unicode scalar literal.
  ///
  /// Valid types for `UnicodeScalarLiteralType` are `Unicode.Scalar`,
  /// `Character`, `String`, and `StaticString`.
  associatedtype UnicodeScalarLiteralType: _ExpressibleByBuiltinUnicodeScalarLiteral

  /// Creates an instance initialized to the given value.
  ///
  /// - Parameter value: The value of the new instance.
  init(unicodeScalarLiteral value: UnicodeScalarLiteralType)
}

public protocol _ExpressibleByBuiltinExtendedGraphemeClusterLiteral
  : _ExpressibleByBuiltinUnicodeScalarLiteral {

  init(
    _builtinExtendedGraphemeClusterLiteral start: Builtin.RawPointer,
    utf8CodeUnitCount: Builtin.Word,
    isASCII: Builtin.Int1)
}

/// A type that can be initialized with a string literal containing a single
/// extended grapheme cluster.
///
/// An *extended grapheme cluster* is a group of one or more Unicode scalar
/// values that approximates a single user-perceived character.  Many
/// individual characters, such as "é", "김", and "🇮🇳", can be made up of
/// multiple Unicode scalar values. These code points are combined by
/// Unicode's boundary algorithms into extended grapheme clusters.
///
/// The `String`, `StaticString`, and `Character` types conform to the
/// `ExpressibleByExtendedGraphemeClusterLiteral` protocol. You can initialize
/// a variable or constant of any of these types using a string literal that
/// holds a single character.
///
///     let snowflake: Character = "❄︎"
///     print(snowflake)
///     // Prints "❄︎"
///
/// Conforming to ExpressibleByExtendedGraphemeClusterLiteral
/// =========================================================
///
/// To add `ExpressibleByExtendedGraphemeClusterLiteral` conformance to your
/// custom type, implement the required initializer.
public protocol ExpressibleByExtendedGraphemeClusterLiteral
  : ExpressibleByUnicodeScalarLiteral {

  /// A type that represents an extended grapheme cluster literal.
  ///
  /// Valid types for `ExtendedGraphemeClusterLiteralType` are `Character`,
  /// `String`, and `StaticString`.
  associatedtype ExtendedGraphemeClusterLiteralType
    : _ExpressibleByBuiltinExtendedGraphemeClusterLiteral
  
  /// Creates an instance initialized to the given value.
  ///
  /// - Parameter value: The value of the new instance.
  init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType)
}

extension ExpressibleByExtendedGraphemeClusterLiteral
  where ExtendedGraphemeClusterLiteralType == UnicodeScalarLiteralType {

  @_transparent
  public init(unicodeScalarLiteral value: ExtendedGraphemeClusterLiteralType) {
    self.init(extendedGraphemeClusterLiteral: value)
  }
}

public protocol _ExpressibleByBuiltinStringLiteral
  : _ExpressibleByBuiltinExtendedGraphemeClusterLiteral {

  init(
    _builtinStringLiteral start: Builtin.RawPointer,
    utf8CodeUnitCount: Builtin.Word,
    isASCII: Builtin.Int1)
}

/// A type that can be initialized with a string literal.
///
/// The `String` and `StaticString` types conform to the
/// `ExpressibleByStringLiteral` protocol. You can initialize a variable or
/// constant of either of these types using a string literal of any length.
///
///     let picnicGuest = "Deserving porcupine"
///
/// Conforming to ExpressibleByStringLiteral
/// ========================================
///
/// To add `ExpressibleByStringLiteral` conformance to your custom type,
/// implement the required initializer.
public protocol ExpressibleByStringLiteral
  : ExpressibleByExtendedGraphemeClusterLiteral {
  
  /// A type that represents a string literal.
  ///
  /// Valid types for `StringLiteralType` are `String` and `StaticString`.
  associatedtype StringLiteralType: _ExpressibleByBuiltinStringLiteral
  
  /// Creates an instance initialized to the given string value.
  ///
  /// - Parameter value: The value of the new instance.
  init(stringLiteral value: StringLiteralType)
}

extension ExpressibleByStringLiteral
  where StringLiteralType == ExtendedGraphemeClusterLiteralType {

  @_transparent
  public init(extendedGraphemeClusterLiteral value: StringLiteralType) {
    self.init(stringLiteral: value)
  }
}

/// A type that can be initialized using an array literal.
///
/// An array literal is a simple way of expressing a list of values. Simply
/// surround a comma-separated list of values, instances, or literals with
/// square brackets to create an array literal. You can use an array literal
/// anywhere an instance of an `ExpressibleByArrayLiteral` type is expected: as
/// a value assigned to a variable or constant, as a parameter to a method or
/// initializer, or even as the subject of a nonmutating operation like
/// `map(_:)` or `filter(_:)`.
///
/// Arrays, sets, and option sets all conform to `ExpressibleByArrayLiteral`, 
/// and your own custom types can as well. Here's an example of creating a set 
/// and an array using array literals:
///
///     let employeesSet: Set<String> = ["Amir", "Jihye", "Dave", "Alessia", "Dave"]
///     print(employeesSet)
///     // Prints "["Amir", "Dave", "Jihye", "Alessia"]"
///
///     let employeesArray: [String] = ["Amir", "Jihye", "Dave", "Alessia", "Dave"]
///     print(employeesArray)
///     // Prints "["Amir", "Jihye", "Dave", "Alessia", "Dave"]"
///
/// The `Set` and `Array` types each handle array literals in their own way to
/// create new instances. In this case, the newly created set drops the
/// duplicate value ("Dave") and doesn't maintain the order of the array
/// literal's elements. The new array, on the other hand, matches the order
/// and number of elements provided.
///
/// - Note: An array literal is not the same as an `Array` instance. You can't
///   initialize a type that conforms to `ExpressibleByArrayLiteral` simply by
///   assigning an existing array.
///
///       let anotherSet: Set = employeesArray
///       // error: cannot convert value of type '[String]' to specified type 'Set'
///
/// Type Inference of Array Literals
/// ================================
///
/// Whenever possible, Swift's compiler infers the full intended type of your
/// array literal. Because `Array` is the default type for an array literal,
/// without writing any other code, you can declare an array with a particular
/// element type by providing one or more values.
///
/// In this example, the compiler infers the full type of each array literal.
///
///     let integers = [1, 2, 3]
///     // 'integers' has type '[Int]'
///
///     let strings = ["a", "b", "c"]
///     // 'strings' has type '[String]'
///
/// An empty array literal alone doesn't provide enough information for the
/// compiler to infer the intended type of the `Array` instance. When using an
/// empty array literal, specify the type of the variable or constant.
///
///     var emptyArray: [Bool] = []
///     // 'emptyArray' has type '[Bool]'
///
/// Because many functions and initializers fully specify the types of their
/// parameters, you can often use an array literal with or without elements as
/// a parameter. For example, the `sum(_:)` function shown here takes an `Int`
/// array as a parameter:
///
///     func sum(values: [Int]) -> Int {
///         return values.reduce(0, +)
///     }
///
///     let sumOfFour = sum([5, 10, 15, 20])
///     // 'sumOfFour' == 50
///
///     let sumOfNone = sum([])
///     // 'sumOfNone' == 0
///
/// When you call a function that does not fully specify its parameters' types,
/// use the type-cast operator (`as`) to specify the type of an array literal.
/// For example, the `log(name:value:)` function shown here has an
/// unconstrained generic `value` parameter.
///
///     func log<T>(name name: String, value: T) {
///         print("\(name): \(value)")
///     }
///
///     log(name: "Four integers", value: [5, 10, 15, 20])
///     // Prints "Four integers: [5, 10, 15, 20]"
///
///     log(name: "Zero integers", value: [] as [Int])
///     // Prints "Zero integers: []"
///
/// Conforming to ExpressibleByArrayLiteral
/// =======================================
///
/// Add the capability to be initialized with an array literal to your own
/// custom types by declaring an `init(arrayLiteral:)` initializer. The
/// following example shows the array literal initializer for a hypothetical
/// `OrderedSet` type, which has setlike semantics but maintains the order of
/// its elements.
///
///     struct OrderedSet<Element: Hashable>: Collection, SetAlgebra {
///         // implementation details
///     }
///
///     extension OrderedSet: ExpressibleByArrayLiteral {
///         init(arrayLiteral: Element...) {
///             self.init()
///             for element in arrayLiteral {
///                 self.append(element)
///             }
///         }
///     }
public protocol ExpressibleByArrayLiteral {
  /// The type of the elements of an array literal.
  associatedtype ArrayLiteralElement
  /// Creates an instance initialized with the given elements.
  init(arrayLiteral elements: ArrayLiteralElement...)
}

/// A type that can be initialized using a dictionary literal.
///
/// A dictionary literal is a simple way of writing a list of key-value pairs.
/// You write each key-value pair with a colon (`:`) separating the key and
/// the value. The dictionary literal is made up of one or more key-value
/// pairs, separated by commas and surrounded with square brackets.
///
/// To declare a dictionary, assign a dictionary literal to a variable or
/// constant:
///
///     let countryCodes = ["BR": "Brazil", "GH": "Ghana",
///                         "JP": "Japan", "US": "United States"]
///     // 'countryCodes' has type [String: String]
///
///     print(countryCodes["BR"]!)
///     // Prints "Brazil"
///
/// When the context provides enough type information, you can use a special
/// form of the dictionary literal, square brackets surrounding a single
/// colon, to initialize an empty dictionary.
///
///     var frequencies: [String: Int] = [:]
///     print(frequencies.count)
///     // Prints "0"
///
/// - Note:
///   A dictionary literal is *not* the same as an instance of `Dictionary`.
///   You can't initialize a type that conforms to `ExpressibleByDictionaryLiteral`
///   simply by assigning an instance of `Dictionary`, `KeyValuePairs`, or similar.
///
/// Conforming to the ExpressibleByDictionaryLiteral Protocol
/// =========================================================
///
/// To add the capability to be initialized with a dictionary literal to your
/// own custom types, declare an `init(dictionaryLiteral:)` initializer. The
/// following example shows the dictionary literal initializer for a
/// hypothetical `CountedSet` type, which uses setlike semantics while keeping
/// track of the count for duplicate elements:
///
///     struct CountedSet<Element: Hashable>: Collection, SetAlgebra {
///         // implementation details
///
///         /// Updates the count stored in the set for the given element,
///         /// adding the element if necessary.
///         ///
///         /// - Parameter n: The new count for `element`. `n` must be greater
///         ///   than or equal to zero.
///         /// - Parameter element: The element to set the new count on.
///         mutating func updateCount(_ n: Int, for element: Element)
///     }
///
///     extension CountedSet: ExpressibleByDictionaryLiteral {
///         init(dictionaryLiteral elements: (Element, Int)...) {
///             self.init()
///             for (element, count) in elements {
///                 self.updateCount(count, for: element)
///             }
///         }
///     }
public protocol ExpressibleByDictionaryLiteral {
  /// The key type of a dictionary literal.
  associatedtype Key
  /// The value type of a dictionary literal.
  associatedtype Value
  /// Creates an instance initialized with the given key-value pairs.
  init(dictionaryLiteral elements: (Key, Value)...)
}

/// A type that can be initialized by string interpolation with a string
/// literal that includes expressions.
///
/// Use string interpolation to include one or more expressions in a string
/// literal, wrapped in a set of parentheses and prefixed by a backslash. For
/// example:
///
///     let price = 2
///     let number = 3
///     let message = "One cookie: $\(price), \(number) cookies: $\(price * number)."
///     print(message)
///     // Prints "One cookie: $2, 3 cookies: $6."
/// 
/// Extending the Default Interpolation Behavior
/// ============================================
/// 
/// Add new interpolation behavior to existing types by extending
/// `DefaultStringInterpolation`, the type that implements interpolation for
/// types like `String` and `Substring`, to add an overload of
/// `appendInterpolation(_:)` with their new behavior.
///
/// For more information, see the `DefaultStringInterpolation` and
/// `StringInterpolationProtocol` documentation.
/// 
/// Creating a Type That Supports the Default String Interpolation
/// ==============================================================
/// 
/// To create a new type that supports string literals and interpolation, but
/// that doesn't need any custom behavior, conform the type to
/// `ExpressibleByStringInterpolation` and implement the
/// `init(stringLiteral: String)` initializer declared by the
/// `ExpressibleByStringLiteral` protocol. Swift will automatically use
/// `DefaultStringInterpolation` as the interpolation type and provide an
/// implementation for `init(stringInterpolation:)` that passes the
/// interpolated literal's contents to `init(stringLiteral:)`, so you don't
/// need to implement anything specific to this protocol.
///
/// Creating a Type That Supports Custom String Interpolation
/// =========================================================
///
/// If you want a conforming type to differentiate between literal and
/// interpolated segments, restrict the types that can be interpolated,
/// support different interpolators from the ones on `String`, or avoid
/// constructing a `String` containing the data, the type must specify a custom
/// `StringInterpolation` associated type. This type must conform to
/// `StringInterpolationProtocol` and have a matching `StringLiteralType`.
///
/// For more information, see the `StringInterpolationProtocol` documentation.
public protocol ExpressibleByStringInterpolation
  : ExpressibleByStringLiteral {
  
  /// The type each segment of a string literal containing interpolations
  /// should be appended to.
  ///
  /// The `StringLiteralType` of an interpolation type must match the
  /// `StringLiteralType` of the conforming type.
  associatedtype StringInterpolation: StringInterpolationProtocol
    = DefaultStringInterpolation
    where StringInterpolation.StringLiteralType == StringLiteralType

  /// Creates an instance from a string interpolation.
  /// 
  /// Most `StringInterpolation` types will store information about the
  /// literals and interpolations appended to them in one or more properties.
  /// `init(stringInterpolation:)` should use these properties to initialize
  /// the instance.
  /// 
  /// - Parameter stringInterpolation: An instance of `StringInterpolation`
  ///             which has had each segment of the string literal appended
  ///             to it.
  init(stringInterpolation: StringInterpolation)
}

extension ExpressibleByStringInterpolation
  where StringInterpolation == DefaultStringInterpolation {
  
  /// Creates a new instance from an interpolated string literal.
  /// 
  /// Don't call this initializer directly. It's used by the compiler when
  /// you create a string using string interpolation. Instead, use string
  /// interpolation to create a new string by including values, literals,
  /// variables, or expressions enclosed in parentheses, prefixed by a
  /// backslash (`\(`...`)`).
  ///
  ///     let price = 2
  ///     let number = 3
  ///     let message = """
  ///                   If one cookie costs \(price) dollars, \
  ///                   \(number) cookies cost \(price * number) dollars.
  ///                   """
  ///     // message == "If one cookie costs 2 dollars, 3 cookies cost 6 dollars."
  public init(stringInterpolation: DefaultStringInterpolation) {
    self.init(stringLiteral: stringInterpolation.make())
  }
}

/// Represents the contents of a string literal with interpolations while it's
/// being built up.
/// 
/// Each `ExpressibleByStringInterpolation` type has an associated
/// `StringInterpolation` type which conforms to `StringInterpolationProtocol`.
/// Swift converts an expression like `"The time is \(time)." as MyString` into
/// a series of statements similar to:
/// 
///     var interpolation = MyString.StringInterpolation(literalCapacity: 13, 
///                                                      interpolationCount: 1)
/// 
///     interpolation.appendLiteral("The time is ")
///     interpolation.appendInterpolation(time)
///     interpolation.appendLiteral(".")
///
///     MyString(stringInterpolation: interpolation)
/// 
/// The `StringInterpolation` type is responsible for collecting the segments
/// passed to its `appendLiteral(_:)` and `appendInterpolation` methods and
/// assembling them into a whole, converting as necessary. Once all of the
/// segments are appended, the interpolation is passed to an
/// `init(stringInterpolation:)` initializer on the type being created, which
/// must extract the accumulated data from the `StringInterpolation`.
/// 
/// In simple cases, you can use `DefaultStringInterpolation` as the
/// interpolation type for types that conform to the
/// `ExpressibleByStringLiteral` protocol. To use the default interpolation,
/// conform a type to `ExpressibleByStringInterpolation` and implement
/// `init(stringLiteral: String)`. Values in interpolations are converted to
/// strings, and then passed to that initializer just like any other string
/// literal.
/// 
/// Handling String Interpolations
/// ==============================
///
/// With a custom interpolation type, each interpolated segment is translated
/// into a call to a special `appendInterpolation` method. The contents of
/// the interpolation's parentheses are treated as the call's argument list.
/// That argument list can include multiple arguments and argument labels.
///
/// The following examples show how string interpolations are translated into
/// calls to `appendInterpolation`:
///
/// - `\(x)` translates to `appendInterpolation(x)`
/// - `\(x, y)` translates to `appendInterpolation(x, y)`
/// - `\(foo: x)` translates to `appendInterpolation(foo: x)`
/// - `\(x, foo: y)` translates to `appendInterpolation(x, foo: y)`
///
/// The `appendInterpolation` methods in your custom type must be mutating
/// instance methods that return `Void`. This code shows a custom interpolation
/// type's declaration of an `appendInterpolation` method that provides special
/// validation for user input:
///
///     extension MyString.StringInterpolation {
///         mutating func appendInterpolation(validating input: String) {
///             // Perform validation of `input` and store for later use
///         }
///     }
///
/// To use this interpolation method, create a string literal with an
/// interpolation using the `validating` parameter label.
///
///     let userInput = readLine() ?? ""
///     let myString = "The user typed '\(validating: userInput)'." as MyString
///
/// `appendInterpolation` methods support virtually all features of methods:
/// they can have any number of parameters, can specify labels for any or all
/// of their parameters, can provide default values, can have variadic
/// parameters, and can have parameters with generic types. Most importantly,
/// they can be overloaded, so a type that conforms to
/// `StringInterpolationProtocol` can provide several different
/// `appendInterpolation` methods with different behaviors. An
/// `appendInterpolation` method can also throw; when a user writes a literal
/// with one of these interpolations, they must mark the string literal with
/// `try` or one of its variants.
public protocol StringInterpolationProtocol {
  /// The type that should be used for literal segments.
  associatedtype StringLiteralType: _ExpressibleByBuiltinStringLiteral

  /// Creates an empty instance ready to be filled with string literal content.
  /// 
  /// Don't call this initializer directly. Instead, initialize a variable or
  /// constant using a string literal with interpolated expressions.
  /// 
  /// Swift passes this initializer a pair of arguments specifying the size of
  /// the literal segments and the number of interpolated segments. Use this
  /// information to estimate the amount of storage you will need.
  /// 
  /// - Parameter literalCapacity: The approximate size of all literal segments
  ///   combined. This is meant to be passed to `String.reserveCapacity(_:)`;
  ///   it may be slightly larger or smaller than the sum of the counts of each
  ///   literal segment.
  /// - Parameter interpolationCount: The number of interpolations which will be
  ///   appended. Use this value to estimate how much additional capacity will
  ///   be needed for the interpolated segments.
  init(literalCapacity: Int, interpolationCount: Int)

  /// Appends a literal segment to the interpolation.
  /// 
  /// Don't call this method directly. Instead, initialize a variable or
  /// constant using a string literal with interpolated expressions.
  /// 
  /// Interpolated expressions don't pass through this method; instead, Swift
  /// selects an overload of `appendInterpolation`. For more information, see
  /// the top-level `StringInterpolationProtocol` documentation.
  /// 
  /// - Parameter literal: A string literal containing the characters
  ///   that appear next in the string literal.
  mutating func appendLiteral(_ literal: StringLiteralType)

  // Informal requirement: Any desired appendInterpolation overloads, e.g.:
  // 
  //   mutating func appendInterpolation<T>(_: T)
  //   mutating func appendInterpolation(_: Int, radix: Int)
  //   mutating func appendInterpolation<T: Encodable>(json: T) throws
}

/// A type that can be initialized using a color literal (e.g.
/// `#colorLiteral(red: 1, green: 0, blue: 0, alpha: 1)`).
public protocol _ExpressibleByColorLiteral {
  /// Creates an instance initialized with the given properties of a color
  /// literal.
  ///
  /// Do not call this initializer directly. Instead, initialize a variable or
  /// constant using a color literal.
  init(_colorLiteralRed red: Float, green: Float, blue: Float, alpha: Float)
}

/// A type that can be initialized using an image literal (e.g.
/// `#imageLiteral(resourceName: "hi.png")`).
public protocol _ExpressibleByImageLiteral {
  /// Creates an instance initialized with the given resource name.
  ///
  /// Do not call this initializer directly. Instead, initialize a variable or
  /// constant using an image literal.
  init(imageLiteralResourceName path: String)
}

/// A type that can be initialized using a file reference literal (e.g.
/// `#fileLiteral(resourceName: "resource.txt")`).
public protocol _ExpressibleByFileReferenceLiteral {
  /// Creates an instance initialized with the given resource name.
  ///
  /// Do not call this initializer directly. Instead, initialize a variable or
  /// constant using a file reference literal.
  init(fileReferenceLiteralResourceName path: String)
}

/// A container is destructor safe if whether
/// it may store to memory on
/// destruction only depends on its type parameters destructors.
/// For example, whether `Array<Element>` may store to memory on destruction
/// depends only on `Element`.
/// If `Element` is an `Int` we know the `Array<Int>` does not store to memory
/// during destruction. If `Element` is an arbitrary class
/// `Array<MemoryUnsafeDestructorClass>` then the compiler will deduce may
/// store to memory on destruction because `MemoryUnsafeDestructorClass`'s
/// destructor may store to memory on destruction.
/// If in this example during `Array`'s destructor we would call a method on any
/// type parameter - say `Element.extraCleanup()` - that could store to memory,
/// then Array would no longer be a _DestructorSafeContainer.
public protocol _DestructorSafeContainer {
}
