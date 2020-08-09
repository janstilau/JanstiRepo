/// A type that can be compared using the relational operators `<`, `<=`, `>=`,
/// and `>`.
/// 如果, 你想要实现一个有序的概念, 那么就应该让里面的元素, 实现 compareable 协议.

/// The `Comparable` protocol is used for types that have an inherent order,
/// such as numbers and strings. Many types in the standard library already
/// conform to the `Comparable` protocol.
/// Add `Comparable` conformance to your own custom types when you want to be able to compare instances using
/// relational operators or use standard library methods that are designed for
/// `Comparable` types.
///
/// 算法是固定的行为, 如果能够保证操作的对象, 符合某种抽象了, 算法就能正常的运转. 限制元素符合协议, 就是保证元素符合某种抽象.
/// You can use special versions of some sequence and collection operations
/// when working with a `Comparable` type. For example, if your array's
/// elements conform to `Comparable`, you can call the `sort()` method without
/// using arguments to sort the elements of your array in ascending order.
///
///     var measurements = [1.1, 1.5, 2.9, 1.2, 1.5, 1.3, 1.2]
///     measurements.sort()
///     print(measurements)
///     // Prints "[1.1, 1.2, 1.2, 1.3, 1.5, 1.5, 2.9]"
/*
 因为, > 的实现, 可以根据 ==, < 的实现推导出来, 所以这个协议的 primitive method 没有包含 > 的声明.
 这也就是 protocol 的设计原则, 能够使用已有方法的, 就用已有的方法. 给实现类的约束越小越好.
 */

/// 和 C++ 不同, swift 中的操作符重载, 只有一种方式, 就是 static 方法, 两个参数. 可以认为是 C++ 原来写法的优化.
/// To add `Comparable` conformance to your custom types, define the `<` and
/// `==` operators as static methods of your types. The `==` operator is a
/// requirement of the `Equatable` protocol, which `Comparable` extends---see
/// that protocol's documentation for more information about equality in
/// Swift. Because default implementations of the remainder of the relational
/// operators are provided by the standard library, you'll be able to use
/// `!=`, `>`, `<=`, and `>=` with instances of your type without any further
/// code.
///
/// - Note: A conforming type may contain a subset of values which are treated
///   as exceptional---that is, values that are outside the domain of
///   meaningful arguments for the purposes of the `Comparable` protocol. For
///   example, the special "not a number" value for floating-point types
///   (`FloatingPoint.nan`) compares as neither less than, greater than, nor
///   equal to any normal floating-point value. Exceptional values need not
///   take part in the strict total order.

public protocol Comparable: Equatable {
  /// Returns a Boolean value indicating whether the value of the first
  /// argument is less than that of the second argument.
  ///
  /// - Parameters:
  ///   - lhs: A value to compare.
  ///   - rhs: Another value to compare.
    /*
     因为, == 是 Equatable 提出的限制, 所以这里说 < 是唯一的 comparable 的限制.
     */
  static func < (lhs: Self, rhs: Self) -> Bool

  /// Returns a Boolean value indicating whether the value of the first
  /// argument is less than or equal to that of the second argument.
  ///
  /// - Parameters:
  ///   - lhs: A value to compare.
  ///   - rhs: Another value to compare.
  static func <= (lhs: Self, rhs: Self) -> Bool

  /// Returns a Boolean value indicating whether the value of the first
  /// argument is greater than or equal to that of the second argument.
  ///
  /// - Parameters:
  ///   - lhs: A value to compare.
  ///   - rhs: Another value to compare.
  static func >= (lhs: Self, rhs: Self) -> Bool

  /// Returns a Boolean value indicating whether the value of the first
  /// argument is greater than that of the second argument.
  ///
  /// - Parameters:
  ///   - lhs: A value to compare.
  ///   - rhs: Another value to compare.
  static func > (lhs: Self, rhs: Self) -> Bool
}

/*
 可以看到, 下面的操作, 都是根据 primitive 翻转得到的.
 */

extension Comparable {
  @inlinable
  public static func > (lhs: Self, rhs: Self) -> Bool {
    return rhs < lhs
  }

  @inlinable
  public static func <= (lhs: Self, rhs: Self) -> Bool {
    return !(rhs < lhs)
  }
  @inlinable
  public static func >= (lhs: Self, rhs: Self) -> Bool {
    return !(lhs < rhs)
  }
}
