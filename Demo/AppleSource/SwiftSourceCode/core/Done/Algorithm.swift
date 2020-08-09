/*
 这个类里面, 提供的算法其实很少.
 */

/// Returns the lesser of two comparable values.
///
/// - Parameters:
///   - x: A value to compare.
///   - y: Another value to compare.
/// - Returns: The lesser of `x` and `y`. If `x` is equal to `y`, returns `x`.
@inlinable // protocol-only, swift 里面, 也有 inline 的提示.
public func min<T: Comparable>(_ x: T, _ y: T) -> T {
  // In case `x == y` we pick `x`.
  // This preserves any pre-existing order in case `T` has identity,
  // which is important for e.g. the stability of sorting algorithms.
  // `(min(x, y), max(x, y))` should return `(x, y)` in case `x == y`.
  return y < x ? y : x
}

/// Returns the least argument passed.
///
/// - Parameters:
///   - x: A value to compare.
///   - y: Another value to compare.
///   - z: A third value to compare.
///   - rest: Zero or more additional values.
/// - Returns: The least of all the arguments. If there are multiple equal
///   least arguments, the result is the first one.
/// 提供了一个, 可以有着任意参数的 min 算法.
@inlinable // protocol-only
public func min<T: Comparable>(_ x: T, _ y: T, _ z: T, _ rest: T...) -> T {
  var minValue = min(min(x, y), z)
  // In case `value == minValue`, we pick `minValue`. See min(_:_:).
  for value in rest where value < minValue {
    minValue = value
  }
  return minValue
}

/// Returns the greater of two comparable values.
///
/// - Parameters:
///   - x: A value to compare.
///   - y: Another value to compare.
/// - Returns: The greater of `x` and `y`. If `x` is equal to `y`, returns `y`.
@inlinable // protocol-only
public func max<T: Comparable>(_ x: T, _ y: T) -> T {
  // In case `x == y`, we pick `y`. See min(_:_:).
  return y >= x ? y : x
}

/// Returns the greatest argument passed.
///
/// - Parameters:
///   - x: A value to compare.
///   - y: Another value to compare.
///   - z: A third value to compare.
///   - rest: Zero or more additional values.
/// - Returns: The greatest of all the arguments. If there are multiple equal
///   greatest arguments, the result is the last one.
@inlinable // protocol-only
public func max<T: Comparable>(_ x: T, _ y: T, _ z: T, _ rest: T...) -> T {
  var maxValue = max(max(x, y), z)
  // In case `value == maxValue`, we pick `value`. See min(_:_:).
  for value in rest where value >= maxValue {
    maxValue = value
  }
  return maxValue
}
