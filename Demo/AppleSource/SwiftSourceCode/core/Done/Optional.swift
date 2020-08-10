/*
 其实, 就是一个特殊的标记为. 我猜测, JS 里面的 Null, 也是一个特殊的标记位.
 Null, 代表一种类型, 无. 将无单独算作一种类型, 可以让含义更加的清晰.
 具体可以看 Swift 进阶里面, 对于 Optional 的讲解.
 */
///
///     Int? 就是 Optional<Int> 的简写形式.
///     let shortForm: Int? = Int("42")
///     let longForm: Optional<Int> = Int("42")
///
/// 因为, Optioanl 本质上一个类型, 而编译器会对类型操作做出各种限制来, 所以, 如果不把 Wrapped 的值取出来的话, 是不能直接使用的.
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
///     这里, == 左边是一个 Optional, 右边是一个 bool. 不同的类型, 之间是不能进行比较的
///     编译器会把右边变为一个 Optional(true), 这样就是 Optional 之间的比较了. 关于 Optional 的比较, 有着 == 操作符的重载.
///     if imagePaths["star"]?.hasSuffix(".png") == true {
///         print("The star image is in PNG format")
///     }
///     // Prints "The star image is in PNG format"
///

@frozen
public enum Optional<Wrapped>: ExpressibleByNilLiteral {
    
    /*
     Optional 就只有这两个值, 表示空的 none, 以及some, some 有着关联值, 也就可以在里面存放各种数据.
     */
    case none
    case some(Wrapped)
    
    @_transparent
    public init(_ some: Wrapped) { self = .some(some) }
    @_transparent
    public init(nilLiteral: ()) { self = .none }
    
    
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
 通过这种元组的方式, 避免了一个 switch 下套用另一个 switch.
 */
extension Optional: Equatable where Wrapped: Equatable {
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
