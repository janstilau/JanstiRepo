
/*
 相比于, 内存不为 0x0000 就为 TRUE, 专门的创建一个类型, 表示判断, 意义要明显的多.
 可能对于习惯于上面内存表示判断的人, 这样的写法比较啰嗦, 但是不忘忘记当初自己习惯上面的写法, 花费了多少精力.
 */

/// A value type whose instances are either `true` or `false`.
///
/// `Bool` represents Boolean values in Swift. Create instances of `Bool` by
/// using one of the Boolean literals `true` or `false`, or by assigning the
/// result of a Boolean method or operation to a variable or constant.
///
///     var godotHasArrived = false
///
///     let numbers = 1...5
///     let containsTen = numbers.contains(10)
///     print(containsTen)
///     // Prints "false"
///
///     let (a, b) = (100, 101)
///     let aFirst = a < b
///     print(aFirst)
///     // Prints "true"
///
/// Swift uses only simple Boolean values in conditional contexts to help avoid
/// accidental programming errors and to help maintain the clarity of each
/// control statement. Unlike in other programming languages, in Swift, integers
/// and strings cannot be used where a Boolean value is required.
///
/// 编译的时候, 会有类型检查, 现在只有 Bool 类型的数据, 才能出现在条件表达式里面.
///
/// For example, the following code sample does not compile, because it
/// attempts to use the integer `i` in a logical context:
///
///     var i = 5
///     while i {
///         print(i)
///         i -= 1
///     }
///     // error: 'Int' is not convertible to 'Bool'
///
/// The correct approach in Swift is to compare the `i` value with zero in the
/// `while` statement.
///
///     while i != 0 {
///         print(i)
///         i -= 1
///     }
///
/// Using Imported Boolean values
/// =============================
///
/// The C `bool` and `Boolean` types and the Objective-C `BOOL` type are all
/// bridged into Swift as `Bool`. The single `Bool` type in Swift guarantees
/// that functions, methods, and properties imported from C and Objective-C
/// have a consistent type interface.

@frozen
public struct Bool {
  @usableFromInline
    /*
     作为一个值类型, 它是占据内存空间的, 只有 1 bit. 所以, 这个类型只会有两个居民存在.
     */
  internal var _value: Builtin.Int1

  /// Creates an instance initialized to `false`.
  ///
  /// Do not call this initializer directly. Instead, use the Boolean literal
  /// `false` to create a new `Bool` instance.
  @_transparent
  public init() {
    let zero: Int8 = 0
    self._value = Builtin.trunc_Int8_Int1(zero._value)
  }

  @usableFromInline @_transparent
  internal init(_ v: Builtin.Int1) { self._value = v }
  
  /// Creates an instance equal to the given Boolean value.
  ///
  /// - Parameter value: The Boolean value to copy.
  @inlinable
  public init(_ value: Bool) {
    self = value
  }

  /// Returns a random Boolean value, using the given generator as a source for
  /// randomness.
  ///
  /// This method returns `true` and `false` with equal probability. Use this
  /// method to generate a random Boolean value when you are using a custom
  /// random number generator.
  ///
  ///     let flippedHeads = Bool.random(using: &myGenerator)
  ///     if flippedHeads {
  ///         print("Heads, you win!")
  ///     } else {
  ///         print("Maybe another try?")
  ///     }
  ///
  /// - Note: The algorithm used to create random values may change in a future
  ///   version of Swift. If you're passing a generator that results in the
  ///   same sequence of Boolean values each time you run your program, that
  ///   sequence may change when your program is compiled using a different
  ///   version of Swift.
  ///
  /// - Parameter generator: The random number generator to use when creating
  ///   the new random value.
  /// - Returns: Either `true` or `false`, randomly chosen with equal
  ///   probability.
    /*
     RandomNumberGenerator 是一个协议, 它的 next 会返回一个UInt64.
     所以, Generator 到底生成一个什么样的数字, 完全可以外界进行控制.
     这里, 传递过来的是一个协议, 而不是实例. 面向抽象编程.
     */
  @inlinable
  public static func random<T: RandomNumberGenerator>(
    using generator: inout T
  ) -> Bool {
    return (generator.next() >> 17) & 1 == 0
  }
  
  /// Returns a random Boolean value.
  ///
  /// This method returns `true` and `false` with equal probability.
  ///
  ///     let flippedHeads = Bool.random()
  ///     if flippedHeads {
  ///         print("Heads, you win!")
  ///     } else {
  ///         print("Maybe another try?")
  ///     }
  ///
  /// This method is equivalent to calling `Bool.random(using:)`, passing in
  /// the system's default random generator.
  ///
  /// - Returns: Either `true` or `false`, randomly chosen with equal
  ///   probability.
    /*
     作为类的设计者, 应该提供一个最简便的方法, 给外界的使用者.
     应该提供一个最通用的方法, 给外界需要自定义的人.
     所以, 利用上面的全的方法, 这里提供一个简便的方法.
     */
  @inlinable
  public static func random() -> Bool {
    var g = SystemRandomNumberGenerator()
    return Bool.random(using: &g)
  }
}

extension Bool: _ExpressibleByBuiltinBooleanLiteral, ExpressibleByBooleanLiteral {
  @_transparent
  public init(_builtinBooleanLiteral value: Builtin.Int1) {
    self._value = value
  }

  /// Creates an instance initialized to the specified Boolean literal.
  ///
  /// Do not call this initializer directly. It is used by the compiler when
  /// you use a Boolean literal. Instead, create a new `Bool` instance by
  /// using one of the Boolean literals `true` or `false`.
  ///
  ///     var printedMessage = false
  ///
  ///     if !printedMessage {
  ///         print("You look nice today!")
  ///         printedMessage = true
  ///     }
  ///     // Prints "You look nice today!"
  ///
  /// In this example, both assignments to the `printedMessage` variable call
  /// this Boolean literal initializer behind the scenes.
  ///
  /// - Parameter value: The value of the new instance.
    
    /*
     struct Person:ExpressibleByBooleanLiteral {
         typealias BooleanLiteralType = Bool
         
         var name: String
         var age: Int
         init(name: String, age: Int) {
             self.name = name
             self.age = age
         }
         init(booleanLiteral boolValue: Bool) {
             if (boolValue) {
                 self.name = "Justin"
                 self.age = 23
             } else {
                 self.name = "Jansti"
                 self.age = 18
             }
         }
     }
     let cPerson:Person = true
     上面是一个例子, 可以编译通过并使用.

     如果, 一个自定义的类, 想要直接通过 Bool 值进行初始化, 那么需要显式地申明自己想要这份能力. 也就是 ExpressibleByBooleanLiteral 接口的实现.
     在这个接口里面, init(booleanLiteral boolValue: Bool) 需要被实现, 这个方法, 名字特殊, 有着 parameter label 进行限制.
     相比于, C++ 无缘无故的给你进行转换, 这种写法, 要安全的多. 而且好像只能是通过系统提供的字面量进行初始化
     */
  @_transparent
  public init(booleanLiteral value: Bool) {
    self = value
  }
}

/*
 字符串化.
 */
extension Bool: CustomStringConvertible {
  /// A textual representation of the Boolean value.
  @inlinable
  public var description: String {
    return self ? "true" : "false"
  }
}

extension Bool: Equatable {
  @_transparent
  public static func == (lhs: Bool, rhs: Bool) -> Bool {
    return Bool(Builtin.cmp_eq_Int1(lhs._value, rhs._value))
  }
}

extension Bool: Hashable {
  /// Hashes the essential components of this value by feeding them into the
  /// given hasher.
  ///
  /// - Parameter hasher: The hasher to use when combining the components
  ///   of this instance.
  @inlinable
    /*
     Swift 里面, 所有的 hash 函数, 都是通过 Hasher 来进行的.
     */
  public func hash(into hasher: inout Hasher) {
    hasher.combine((self ? 1 : 0) as UInt8)
  }
}

/*
 不太明白, 这个是怎么调用的. 不能直接写出 var aBoolValue:Bool? = "true" 这种调用来.
 */
extension Bool: LosslessStringConvertible {
  /// Creates a new Boolean value from the given string.
  ///
  /// If the `description` value is any string other than `"true"` or
  /// `"false"`, the result is `nil`. This initializer is case sensitive.
  ///
  /// - Parameter description: A string representation of the Boolean value.
  @inlinable
  public init?(_ description: String) {
    if description == "true" {
      self = true
    } else if description == "false" {
      self = false
    } else {
      return nil
    }
  }
}

//===----------------------------------------------------------------------===//
// Operators
//===----------------------------------------------------------------------===//
/*
 作为一个类型, 要考虑他相关的操作符. 也就是说, 需要显式地写出这个操作符的定义, 才能模拟出原有 C 风格的效果.
 */
extension Bool {
  /// Performs a logical NOT operation on a Boolean value.
  ///
  /// The logical NOT operator (`!`) inverts a Boolean value. If the value is
  /// `true`, the result of the operation is `false`; if the value is `false`,
  /// the result is `true`.
  ///
  ///     var printedMessage = false
  ///
  ///     if !printedMessage {
  ///         print("You look nice today!")
  ///         printedMessage = true
  ///     }
  ///     // Prints "You look nice today!"
  ///
  /// - Parameter a: The Boolean value to negate.
  @_transparent
  public static prefix func ! (a: Bool) -> Bool {
    return Bool(Builtin.xor_Int1(a._value, true._value))
  }
}

/*
 模拟 C 分割的操作符, 注意, Swift 里面, 所有带有短路效果的操作符, 后面的参数都是自动闭包.
 */
extension Bool {
  /// Performs a logical AND operation on two Boolean values.
  ///
  /// The logical AND operator (`&&`) combines two Boolean values and returns
  /// `true` if both of the values are `true`. If either of the values is
  /// `false`, the operator returns `false`.
  ///
  /// This operator uses short-circuit evaluation: The left-hand side (`lhs`) is
  /// evaluated first, and the right-hand side (`rhs`) is evaluated only if
  /// `lhs` evaluates to `true`. For example:
  ///
  ///     let measurements = [7.44, 6.51, 4.74, 5.88, 6.27, 6.12, 7.76]
  ///     let sum = measurements.reduce(0, combine: +)
  ///
  ///     if measurements.count > 0 && sum / Double(measurements.count) < 6.5 {
  ///         print("Average measurement is less than 6.5")
  ///     }
  ///     // Prints "Average measurement is less than 6.5"
  ///
  /// In this example, `lhs` tests whether `measurements.count` is greater than
  /// zero. Evaluation of the `&&` operator is one of the following:
  ///
  /// - When `measurements.count` is equal to zero, `lhs` evaluates to `false`
  ///   and `rhs` is not evaluated, preventing a divide-by-zero error in the
  ///   expression `sum / Double(measurements.count)`. The result of the
  ///   operation is `false`.
  /// - When `measurements.count` is greater than zero, `lhs` evaluates to
  ///   `true` and `rhs` is evaluated. The result of evaluating `rhs` is the
  ///   result of the `&&` operation.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side of the operation.
  ///   - rhs: The right-hand side of the operation.
  @_transparent
  @inline(__always)
  public static func && (lhs: Bool, rhs: @autoclosure () throws -> Bool) rethrows
      -> Bool {
    return lhs ? try rhs() : false
  }

  /// Performs a logical OR operation on two Boolean values.
  ///
  /// The logical OR operator (`||`) combines two Boolean values and returns
  /// `true` if at least one of the values is `true`. If both values are
  /// `false`, the operator returns `false`.
  ///
  /// This operator uses short-circuit evaluation: The left-hand side (`lhs`) is
  /// evaluated first, and the right-hand side (`rhs`) is evaluated only if
  /// `lhs` evaluates to `false`. For example:
  ///
  ///     let majorErrors: Set = ["No first name", "No last name", ...]
  ///     let error = ""
  ///
  ///     if error.isEmpty || !majorErrors.contains(error) {
  ///         print("No major errors detected")
  ///     } else {
  ///         print("Major error: \(error)")
  ///     }
  ///     // Prints "No major errors detected"
  ///
  /// In this example, `lhs` tests whether `error` is an empty string.
  /// Evaluation of the `||` operator is one of the following:
  ///
  /// - When `error` is an empty string, `lhs` evaluates to `true` and `rhs` is
  ///   not evaluated, skipping the call to `majorErrors.contains(_:)`. The
  ///   result of the operation is `true`.
  /// - When `error` is not an empty string, `lhs` evaluates to `false` and
  ///   `rhs` is evaluated. The result of evaluating `rhs` is the result of the
  ///   `||` operation.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side of the operation.
  ///   - rhs: The right-hand side of the operation.
  @_transparent
  @inline(__always)
  public static func || (lhs: Bool, rhs: @autoclosure () throws -> Bool) rethrows
      -> Bool {
    return lhs ? true : try rhs()
  }
}

/*
 专门的写出这个函数来, 要比 boolValue = !boolValue 要显式的多.
 */
extension Bool {
  /// Toggles the Boolean variable's value.
  ///
  /// Use this method to toggle a Boolean value from `true` to `false` or from
  /// `false` to `true`.
  ///
  ///     var bools = [true, false]
  ///
  ///     bools[0].toggle()
  ///     // bools == [false, false]
  @inlinable
  public mutating func toggle() {
    self = !self
  }
}
