
// 在 Body 完成之前, x 不会被释放.
public func withExtendedLifetime<T, Result>(
    _ x: T,
    _ body: () throws -> Result
) rethrows -> Result {
  defer { _fixLifetime(x) }
  return try body()
}

// 增加了一个Block 的参数
public func withExtendedLifetime<T, Result>(
    _ x: T,
    _ body: (T) throws -> Result
) rethrows -> Result {
  defer { _fixLifetime(x) }
  return try body(x)
}

public func _fixLifetime<T>(_ x: T) {
  Builtin.fixLifetime(x)
}

public func withUnsafeMutablePointer<T, Result>(
  to value: inout T, _ body: (UnsafeMutablePointer<T>) throws -> Result) rethrows -> Result
{
    // Builtin.addressof 这种 API, 外界是使用不了的.
    // 在系统库里面, 先拿到一个 value 的地址, 然后构建成 UnsafeMutablePointer , 然后交给 body 进行处理.
    return try body(UnsafeMutablePointer<T>(Builtin.addressof(&value)))
}

public func withUnsafePointer<T, Result>(
  to value: T,
  _ body: (UnsafePointer<T>) throws -> Result
) rethrows -> Result
{
  return try body(UnsafePointer<T>(Builtin.addressOfBorrow(value)))
}

/// Invokes the given closure with a pointer to the given argument.
///
/// The `withUnsafePointer(to:_:)` function is useful for calling Objective-C
/// APIs that take in parameters by const pointer.
///
/// The pointer argument to `body` is valid only during the execution of
/// `withUnsafePointer(to:_:)`. Do not store or return the pointer for later
/// use.
///
/// - Parameters:
///   - value: An instance to temporarily use via pointer. Note that the `inout`
///     exclusivity rules mean that, like any other `inout` argument, `value`
///     cannot be directly accessed by other code for the duration of `body`.
///     Access must only occur through the pointer argument to `body` until
///     `body` returns.
///   - body: A closure that takes a pointer to `value` as its sole argument. If
///     the closure has a return value, that value is also used as the return
///     value of the `withUnsafePointer(to:_:)` function. The pointer argument
///     is valid only for the duration of the function's execution.
///     It is undefined behavior to try to mutate through the pointer argument
///     by converting it to `UnsafeMutablePointer` or any other mutable pointer
///     type. If you need to mutate the argument through the pointer, use
///     `withUnsafeMutablePointer(to:_:)` instead.
/// - Returns: The return value, if any, of the `body` closure.
@inlinable
public func withUnsafePointer<T, Result>(
  to value: inout T,
  _ body: (UnsafePointer<T>) throws -> Result
) rethrows -> Result
{
  return try body(UnsafePointer<T>(Builtin.addressof(&value)))
}

extension String {
  /// Calls the given closure with a pointer to the contents of the string,
  /// represented as a null-terminated sequence of UTF-8 code units.
  ///
  /// The pointer passed as an argument to `body` is valid only during the
  /// execution of `withCString(_:)`. Do not store or return the pointer for
  /// later use.
  ///
  /// - Parameter body: A closure with a pointer parameter that points to a
  ///   null-terminated sequence of UTF-8 code units. If `body` has a return
  ///   value, that value is also used as the return value for the
  ///   `withCString(_:)` method. The pointer argument is valid only for the
  ///   duration of the method's execution.
  /// - Returns: The return value, if any, of the `body` closure parameter.
  @inlinable // fast-path: already C-string compatible
  public func withCString<Result>(
    _ body: (UnsafePointer<Int8>) throws -> Result
  ) rethrows -> Result {
    return try _guts.withCString(body)
  }
}


