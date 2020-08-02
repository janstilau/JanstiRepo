/// The absence of a value.
/// 对于 无 这种状态的表示. 非常重要的一个概念.
/// A type that represents either a wrapped value or `nil`, the absence of a
/// value.
///
/// You use the `Optional` type whenever you use optional values, even if you
/// never type the word `Optional`. Swift's type system usually shows the
/// wrapped type's name with a trailing question mark (`?`) instead of showing
/// the full type name.
/// For example, if a variable has the type `Int?`, that's
/// just another way of writing `Optional<Int>`. The shortened form is
/// preferred for ease of reading and writing code.
///
/// The types of `shortForm` and `longForm` in the following code sample are
/// the same:
///
///     Int? 就是 Optional<Int> 的简写形式.
///     let shortForm: Int? = Int("42")
///     let longForm: Optional<Int> = Int("42")
///
/// The `Optional` type is an enumeration with two cases. `Optional.none` is
/// equivalent to the `nil` literal. `Optional.some(Wrapped)` stores a wrapped
/// value. For example:
///
///     let number: Int? = Optional.some(42)
///     let noNumber: Int? = Optional.none
///     print(noNumber == nil)
///     // Prints "true"
///
/// 因为, Optioanl 本质上一个类型, 而编译器会对类型操作做出各种限制来, 所以, 如果不把 Wrapped 的值取出来的话, 是不能直接使用的.
///
/// You must unwrap the value of an `Optional` instance before you can use it
/// in many contexts. Because Swift provides several ways to safely unwrap
/// optional values, you can choose the one that helps you write clear,
/// concise code.
///
/// The following examples use this dictionary of image names and file paths:
///
///     let imagePaths = ["star": "/glyphs/star.png",
///                       "portrait": "/images/content/portrait.jpg",
///                       "spacer": "/images/shared/spacer.gif"]
///
/// Getting a dictionary's value using a key returns an optional value, so
/// `imagePaths["star"]` has type `Optional<String>` or, written in the
/// preferred manner, `String?`.
///
/// Optional Binding
/// ----------------
///
/// if let 是取出 optinal 的关联值, 到特定的变量上, 这是值拷贝的过程. 所以, 绑定后的值修改, 不会影响到关联值的内容.
/// To conditionally bind the wrapped value of an `Optional` instance to a new
/// variable, use one of the optional binding control structures, including
/// `if let`, `guard let`, and `switch`.
///
///     if let starPath = imagePaths["star"] {
///         print("The star image is at '\(starPath)'")
///     } else {
///         print("Couldn't find the star image")
///     }
///     // Prints "The star image is at '/glyphs/star.png'"
///
/// Optional Chaining
/// -----------------
///
/// To safely access the properties and methods of a wrapped instance, use the
/// postfix optional chaining operator (postfix `?`). The following example uses
/// optional chaining to access the `hasSuffix(_:)` method on a `String?`
/// instance.
///
///     这里, == 左边是一个 Optional, 右边是一个 bool. 根本不能进行比较, 编译器会把右边变为一个 Optional(true)
///     if imagePaths["star"]?.hasSuffix(".png") == true {
///         print("The star image is in PNG format")
///     }
///     // Prints "The star image is in PNG format"
///
/// Using the Nil-Coalescing Operator
/// ---------------------------------
///
/// Use the nil-coalescing operator (`??`) to supply a default value in case
/// the `Optional` instance is `nil`. Here a default path is supplied for an
/// image that is missing from `imagePaths`.
///
///     let defaultImagePath = "/images/default.png"
///     let heartPath = imagePaths["heart"] ?? defaultImagePath
///     print(heartPath)
///     // Prints "/images/default.png"
///
/// The `??` operator also works with another `Optional` instance on the
/// right-hand side. As a result, you can chain multiple `??` operators
/// together.
///
///     let shapePath = imagePaths["cir"] ?? imagePaths["squ"] ?? defaultImagePath
///     print(shapePath)
///     // Prints "/images/default.png"
///
/// Unconditional Unwrapping
/// ------------------------
///
/// When you're certain that an instance of `Optional` contains a value, you
/// can unconditionally unwrap the value by using the forced
/// unwrap operator (postfix `!`). For example, the result of the failable `Int`
/// initializer is unconditionally unwrapped in the example below.
///
///     let number = Int("42")!
///     print(number)
///     // Prints "42"
///
/// You can also perform unconditional optional chaining by using the postfix
/// `!` operator.
///
///     let isPNG = imagePaths["star"]!.hasSuffix(".png")
///     print(isPNG)
///     // Prints "true"
///
/// Unconditionally unwrapping a `nil` instance with `!` triggers a runtime
/// error.


@frozen
public enum Optional<Wrapped>: ExpressibleByNilLiteral {
    case none
    case some(Wrapped)
    
    /// Creates an instance that stores the given value.
    /// 一般不会这么写,  这种调用, 只会是编译器调用.
    @_transparent
    public init(_ some: Wrapped) { self = .some(some) }
    
    /*
     方法的好处, 就是能够节省大量的重复代码, 如果想要使用 Swift 这门语言, 那么对于这门语言预定义的一些方法, 一定要熟悉这些东西到底是什么创作含义.
     如果传递进来的闭包, 是可能 throws 的, 那么在使用的时候, 一定要加上 try.
     */
    @inlinable
    publi
    /*
     这个方法的逻辑, 和上个方法的逻辑是完全一致的, 不过这里返回的类型, 变成了一个 Optional.
     */
    @inlinable
    public func flatMap<U>(
        _ transform: (Wrapped) throws -> U?
    ) rethrows -> U? {
        switch self {
        case .some(let y):
            return try transform(y)
        case .none:
            return .none
        }
    }
    @_transparent
    public init(nilLiteral: ()) {
        self = .none
    }
    
    @inlinable
    public var unsafelyUnwrapped: Wrapped {
        @inline(__always)
        get {
            if let x = self {
                return x
            }
            _debugPreconditionFailure("unsafelyUnwrapped of nil optional")
        }
    }
    
    /// - Returns: `unsafelyUnwrapped`.
    ///
    /// This version is for internal stdlib use; it avoids any checking
    /// overhead for users, even in Debug builds.
    @inlinable
    internal var _unsafelyUnwrappedUnchecked: Wrapped {
        @inline(__always)
        get {
            if let x = self {
                return x
            }
            _internalInvariantFailure("_unsafelyUnwrappedUnchecked of nil optional")
        }
    }
}

/*
 打印效果.
 */
extension Optional: CustomDebugStringConvertible {
    /// A textual representation of this instance, suitable for debugging.
    public var debugDescription: String {
        switch self {
        case .some(let value):
            var result = "Optional("
            debugPrint(value, terminator: "", to: &result)
            result += ")"
            return result
        case .none:
            return "nil"
        }
    }
}

extension Optional: CustomReflectable {
    public var customMirror: Mirror {
        switch self {
        case .some(let value):
            return Mirror(
                self,
                children: [ "some": value ],
                displayStyle: .optional)
        case .none:
            return Mirror(self, children: [:], displayStyle: .optional)
        }
    }
}

/*
 对于和 Option 的比较, 编译器会自动装包, 保证是两个 Optional 在进行比较.
 */
extension Optional: Equatable where Wrapped: Equatable {
    /*
     这里, 书里面的建议就是, switch 里面用元组的方式, 写出所有的可能的状态. 这比, 一个 case 下面, 又嵌套一个 switch 要清晰的多得多.
     */
    @inlinable
    public static func ==(lhs: Wrapped?, rhs: Wrapped?) -> Bool {
        switch (lhs, rhs) {
        case let (l?, r?): // 如果都有值, 那么就是比较值
            return l == r
        case (nil, nil): // 如果都是空, 那么就是显得更.
            return true
        default: // 如果一个为空, 另一个不为空, 就是不相等.
            return false
        }
    }
}

extension Optional: Hashable where Wrapped: Hashable {
    /// Hashes the essential components of this value by feeding them into the
    /// given hasher.
    ///
    /// - Parameter hasher: The hasher to use when combining the components
    ///   of this instance.
    @inlinable
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .none:
            hasher.combine(0 as UInt8)
        case .some(let wrapped):
            hasher.combine(1 as UInt8)
            hasher.combine(wrapped)
        }
    }
}

// Enable pattern matching against the nil literal, even if the element type
// isn't equatable.
@frozen
public struct _OptionalNilComparisonType: ExpressibleByNilLiteral {
    /// Create an instance initialized with `nil`.
    @_transparent
    public init(nilLiteral: ()) {
    }
}

extension Optional {
    /// Returns a Boolean value indicating whether an argument matches `nil`.
    ///
    /// You can use the pattern-matching operator (`~=`) to test whether an
    /// optional instance is `nil` even when the wrapped value's type does not
    /// conform to the `Equatable` protocol. The pattern-matching operator is used
    /// internally in `case` statements for pattern matching.
    ///
    /// The following example declares the `stream` variable as an optional
    /// instance of a hypothetical `DataStream` type, and then uses a `switch`
    /// statement to determine whether the stream is `nil` or has a configured
    /// value. When evaluating the `nil` case of the `switch` statement, this
    /// operator is called behind the scenes.
    ///
    ///     var stream: DataStream? = nil
    ///     switch stream {
    ///     case nil:
    ///         print("No data stream is configured.")
    ///     case let x?:
    ///         print("The data stream has \(x.availableBytes) bytes available.")
    ///     }
    ///     // Prints "No data stream is configured."
    ///
    /// - Note: To test whether an instance is `nil` in an `if` statement, use the
    ///   equal-to operator (`==`) instead of the pattern-matching operator. The
    ///   pattern-matching operator is primarily intended to enable `case`
    ///   statement pattern matching.
    ///
    /// - Parameters:
    ///   - lhs: A `nil` literal.
    ///   - rhs: A value to match against `nil`.
    @_transparent
    public static func ~=(lhs: _OptionalNilComparisonType, rhs: Wrapped?) -> Bool {
        switch rhs {
        case .some:
            return false
        case .none:
            return true
        }
    }
    
    /*
     Optional 之所以可以和 nil 进行比较, 就是因为重载了这个 == 操作符方法.
     */
    @_transparent
    public static func ==(lhs: Wrapped?, rhs: _OptionalNilComparisonType) -> Bool {
        switch lhs {
        case .some:
            return false
        case .none:
            return true
        }
    }
    
    @_transparent
    public static func !=(lhs: Wrapped?, rhs: _OptionalNilComparisonType) -> Bool {
        switch lhs {
        case .some:
            return true
        case .none:
            return false
        }
    }
    
    /*
     因为, 参数的位置原因, 这里要写同样的逻辑
     */
    @_transparent
    public static func ==(lhs: _OptionalNilComparisonType, rhs: Wrapped?) -> Bool {
        switch rhs {
        case .some:
            return false
        case .none:
            return true
        }
    }
    
    @_transparent
    public static func !=(lhs: _OptionalNilComparisonType, rhs: Wrapped?) -> Bool {
        switch rhs {
        case .some:
            return true
        case .none:
            return false
        }
    }
}

/*
 这里写的很清楚, 传过来的是一个自动闭包
 */
@_transparent
public func ?? <T>(optional: T?, defaultValue: @autoclosure () throws -> T)
    rethrows -> T {
        switch optional {
        case .some(let value):
            return value
        case .none:
            return try defaultValue()
        }
}

@_transparent
public func ?? <T>(optional: T?, defaultValue: @autoclosure () throws -> T?)
    rethrows -> T? {
        switch optional {
        case .some(let value):
            return value
        case .none:
            return try defaultValue()
        }
}
