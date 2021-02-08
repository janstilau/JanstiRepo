
// 其实, 从 Optinal 可以看出来, 枚举的关联值, 就是枚举的成员变量
public enum Optional<Wrapped>: ExpressibleByNilLiteral {
    case none
    case some(Wrapped)
    
    // 当编译器发现了 self = 12 的时候, 会自动把 12 包装一层, 变为 .some(12). 这是很自然的, 没有编译器优化, 每次都要包装, 太麻烦了.
    public init(_ some: Wrapped) { self = .some(some) }
    
    public func map<U>(
        _ transform: (Wrapped) throws -> U
    ) rethrows -> U? {
        switch self {
        case .some(let y):
            return .some(try transform(y))
        case .none:
            return .none
        }
    }
    
    // 到底, 使用 map, 还是 flatMap, 这是使用者要根据传入的 block 来决定的.
    // 如果 block 返回一个 Int?, 还使用 map, 那么返回值就是 Int?? 了
    public func flatMap<U>(
        _ transform: (Wrapped) throws -> U?
    ) rethrows -> U? {
        switch self {
        case .some(let y):
            return try transform(y) // 这里就是问题的关键, 这里没有再次装进 some 里面.
        case .none:
            return .none
        }
    }
    
    public init(nilLiteral: ()) {
        self = .none
    }
    
    // 强制解包类似的代码.
    public var unsafelyUnwrapped: Wrapped {
        @inline(__always)
        get {
            if let x = self {
                return x
            }
            // 强制解包崩溃的原因所在.
            _debugPreconditionFailure("unsafelyUnwrapped of nil optional")
        }
    }
    
    // 强制解包类似的代码.
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

// 首先, 必须自己包裹的数据可以判等.
// 然后先进行枚举 type 的判断, 如果是有值, 就是关联值的相等判断.
extension Optional: Equatable where Wrapped: Equatable {
    public static func ==(lhs: Wrapped?, rhs: Wrapped?) -> Bool {
        switch (lhs, rhs) {
        case let (l?, r?):
            return l == r
        case (nil, nil):
            return true
        default:
            return false
        }
    }
}

extension Optional: Hashable where Wrapped: Hashable {
    // 先 Hash type, 然后 hash value.
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
    public static func ~=(lhs: _OptionalNilComparisonType, rhs: Wrapped?) -> Bool {
        switch rhs {
        case .some:
            return false
        case .none:
            return true
        }
    }
    
    // 和 Nil 进行相等性判断.
    public static func ==(lhs: Wrapped?, rhs: _OptionalNilComparisonType) -> Bool {
        switch lhs {
        case .some:
            return false
        case .none:
            return true
        }
    }
    
    // 和 nil 进行不等性判断.
    public static func !=(lhs: Wrapped?, rhs: _OptionalNilComparisonType) -> Bool {
        switch lhs {
        case .some:
            return true
        case .none:
            return false
        }
    }
    
    /// Returns a Boolean value indicating whether the right-hand-side argument is
    /// `nil`.
    ///
    /// You can use this equal-to operator (`==`) to test whether an optional
    /// instance is `nil` even when the wrapped value's type does not conform to
    /// the `Equatable` protocol.
    ///
    /// The following example declares the `stream` variable as an optional
    /// instance of a hypothetical `DataStream` type. Although `DataStream` is not
    /// an `Equatable` type, this operator allows checking whether `stream` is
    /// `nil`.
    ///
    ///     var stream: DataStream? = nil
    ///     if nil == stream {
    ///         print("No data stream is configured.")
    ///     }
    ///     // Prints "No data stream is configured."
    ///
    /// - Parameters:
    ///   - lhs: A `nil` literal.
    ///   - rhs: A value to compare to `nil`.
    @_transparent
    public static func ==(lhs: _OptionalNilComparisonType, rhs: Wrapped?) -> Bool {
        switch rhs {
        case .some:
            return false
        case .none:
            return true
        }
    }
    
    /// Returns a Boolean value indicating whether the right-hand-side argument is
    /// not `nil`.
    ///
    /// You can use this not-equal-to operator (`!=`) to test whether an optional
    /// instance is not `nil` even when the wrapped value's type does not conform
    /// to the `Equatable` protocol.
    ///
    /// The following example declares the `stream` variable as an optional
    /// instance of a hypothetical `DataStream` type. Although `DataStream` is not
    /// an `Equatable` type, this operator allows checking whether `stream` wraps
    /// a value and is therefore not `nil`.
    ///
    ///     var stream: DataStream? = fetchDataStream()
    ///     if nil != stream {
    ///         print("The data stream has been configured.")
    ///     }
    ///     // Prints "The data stream has been configured."
    ///
    /// - Parameters:
    ///   - lhs: A `nil` literal.
    ///   - rhs: A value to compare to `nil`.
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

/// Performs a nil-coalescing operation, returning the wrapped value of an
/// `Optional` instance or a default value.
///
/// A nil-coalescing operation unwraps the left-hand side if it has a value, or
/// it returns the right-hand side as a default. The result of this operation
/// will have the non-optional type of the left-hand side's `Wrapped` type.
///
/// This operator uses short-circuit evaluation: `optional` is checked first,
/// and `defaultValue` is evaluated only if `optional` is `nil`. For example:
///
///     func getDefault() -> Int {
///         print("Calculating default...")
///         return 42
///     }
///
///     let goodNumber = Int("100") ?? getDefault()
///     // goodNumber == 100
///
///     let notSoGoodNumber = Int("invalid-input") ?? getDefault()
///     // Prints "Calculating default..."
///     // notSoGoodNumber == 42
///
/// In this example, `goodNumber` is assigned a value of `100` because
/// `Int("100")` succeeded in returning a non-`nil` result. When
/// `notSoGoodNumber` is initialized, `Int("invalid-input")` fails and returns
/// `nil`, and so the `getDefault()` method is called to supply a default
/// value.
///
/// - Parameters:
///   - optional: An optional value.
///   - defaultValue: A value to use as a default. `defaultValue` is the same
///     type as the `Wrapped` type of `optional`.
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

/// Performs a nil-coalescing operation, returning the wrapped value of an
/// `Optional` instance or a default `Optional` value.
///
/// A nil-coalescing operation unwraps the left-hand side if it has a value, or
/// returns the right-hand side as a default. The result of this operation
/// will be the same type as its arguments.
///
/// This operator uses short-circuit evaluation: `optional` is checked first,
/// and `defaultValue` is evaluated only if `optional` is `nil`. For example:
///
///     let goodNumber = Int("100") ?? Int("42")
///     print(goodNumber)
///     // Prints "Optional(100)"
///
///     let notSoGoodNumber = Int("invalid-input") ?? Int("42")
///     print(notSoGoodNumber)
///     // Prints "Optional(42)"
///
/// In this example, `goodNumber` is assigned a value of `100` because
/// `Int("100")` succeeds in returning a non-`nil` result. When
/// `notSoGoodNumber` is initialized, `Int("invalid-input")` fails and returns
/// `nil`, and so `Int("42")` is called to supply a default value.
///
/// Because the result of this nil-coalescing operation is itself an optional
/// value, you can chain default values by using `??` multiple times. The
/// first optional value that isn't `nil` stops the chain and becomes the
/// result of the whole expression. The next example tries to find the correct
/// text for a greeting in two separate dictionaries before falling back to a
/// static default.
///
///     let greeting = userPrefs[greetingKey] ??
///         defaults[greetingKey] ?? "Greetings!"
///
/// If `userPrefs[greetingKey]` has a value, that value is assigned to
/// `greeting`. If not, any value in `defaults[greetingKey]` will succeed, and
/// if not that, `greeting` will be set to the non-optional default value,
/// `"Greetings!"`.
///
/// - Parameters:
///   - optional: An optional value.
///   - defaultValue: A value to use as a default. `defaultValue` and
///     `optional` have the same type.
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

//===----------------------------------------------------------------------===//
// Bridging
//===----------------------------------------------------------------------===//

#if _runtime(_ObjC)
extension Optional: _ObjectiveCBridgeable {
    // The object that represents `none` for an Optional of this type.
    internal static var _nilSentinel: AnyObject {
        @_silgen_name("_swift_Foundation_getOptionalNilSentinelObject")
        get
    }
    
    public func _bridgeToObjectiveC() -> AnyObject {
        // Bridge a wrapped value by unwrapping.
        if let value = self {
            return _bridgeAnythingToObjectiveC(value)
        }
        // Bridge nil using a sentinel.
        return type(of: self)._nilSentinel
    }
    
    public static func _forceBridgeFromObjectiveC(
        _ source: AnyObject,
        result: inout Optional<Wrapped>?
    ) {
        // Map the nil sentinel back to .none.
        // NB that the signature of _forceBridgeFromObjectiveC adds another level
        // of optionality, so we need to wrap the immediate result of the conversion
        // in `.some`.
        if source === _nilSentinel {
            result = .some(.none)
            return
        }
        // Otherwise, force-bridge the underlying value.
        let unwrappedResult = source as! Wrapped
        result = .some(.some(unwrappedResult))
    }
    
    public static func _conditionallyBridgeFromObjectiveC(
        _ source: AnyObject,
        result: inout Optional<Wrapped>?
    ) -> Bool {
        // Map the nil sentinel back to .none.
        // NB that the signature of _forceBridgeFromObjectiveC adds another level
        // of optionality, so we need to wrap the immediate result of the conversion
        // in `.some` to indicate success of the bridging operation, with a nil
        // result.
        if source === _nilSentinel {
            result = .some(.none)
            return true
        }
        // Otherwise, try to bridge the underlying value.
        if let unwrappedResult = source as? Wrapped {
            result = .some(.some(unwrappedResult))
            return true
        } else {
            result = .none
            return false
        }
    }
    
    @_effects(readonly)
    public static func _unconditionallyBridgeFromObjectiveC(_ source: AnyObject?)
    -> Optional<Wrapped> {
        if let nonnullSource = source {
            // Map the nil sentinel back to none.
            if nonnullSource === _nilSentinel {
                return .none
            } else {
                return .some(nonnullSource as! Wrapped)
            }
        } else {
            // If we unexpectedly got nil, just map it to `none` too.
            return .none
        }
    }
}
#endif
