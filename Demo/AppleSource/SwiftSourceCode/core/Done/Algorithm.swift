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

/// An enumeration of the elements of a sequence or collection.
///
/// `EnumeratedSequence` is a sequence of pairs (*n*, *x*), where *n*s are
/// consecutive `Int` values starting at zero, and *x*s are the elements of a
/// base sequence.
///
/// To create an instance of `EnumeratedSequence`, call `enumerated()` on a
/// sequence or collection. The following example enumerates the elements of
/// an array.
///
///     var s = ["foo", "bar"].enumerated()
///     for (n, x) in s {
///         print("\(n): \(x)")
///     }
///     // Prints "0: foo"
///     // Prints "1: bar"

/*
 这个类, 就是 Sequence 类的一层包装, 把每个返回来的数据, 增加了 index 值.
 所以, 这个类仅仅是在实现 next 的时候, 返回的值带有 index 了而已.

 为什么, 会有专门的函数来创建包装对象呢. 这是因为包装对象, 其实是抽象的实现.
 使用这个函数的人, 并不关心返回值的具体类型, 而是拿到返回值, 按照抽象限制的协议功能, 进行后续的处理逻辑.
 */

@frozen
public struct EnumeratedSequence<Base: Sequence> {
  @usableFromInline
  internal var _base: Base // 原始的 sequence 尽心进行了存储.

  /// Construct from a `Base` sequence.
  @inlinable
  internal init(_base: Base) {
    self._base = _base
  }
}

extension EnumeratedSequence {
  /// The iterator for `EnumeratedSequence`.
  ///
  /// An instance of this iterator wraps a base iterator and yields
  /// successive `Int` values, starting at zero, along with the elements of the
  /// underlying base iterator. The following example enumerates the elements of
  /// an array:
  ///
  ///     var iterator = ["foo", "bar"].enumerated().makeIterator()
  ///     iterator.next() // (0, "foo")
  ///     iterator.next() // (1, "bar")
  ///     iterator.next() // nil
  ///
  /// To create an instance, call
  /// `enumerated().makeIterator()` on a sequence or collection.
  @frozen
  public struct Iterator {
    @usableFromInline
    internal var _base: Base.Iterator
    @usableFromInline
    internal var _count: Int // 这就是为什么会有 index 的原因, interator 里面, 把迭代的过程记录了下来.

    /// Construct from a `Base` iterator.
    @inlinable
    internal init(_base: Base.Iterator) {
      self._base = _base
      self._count = 0
    }
  }
}

extension EnumeratedSequence.Iterator: IteratorProtocol, Sequence {
  /// The type of element returned by `next()`.
    /// 一个新的类型, 一个元组类型. EnumeratedSequence 的 element 就是这个元组类型.
  public typealias Element = (offset: Int, element: Base.Element)

  /// Advances to the next element and returns it, or `nil` if no next element
  /// exists.
  ///
  /// Once `nil` has been returned, all subsequent calls return `nil`.
  @inlinable
  public mutating func next() -> Element? {
    guard let b = _base.next() else { return nil }
    let result = (offset: _count, element: b)
    _count += 1 
    return result
  }
}

extension EnumeratedSequence: Sequence {
  /// Returns an iterator over the elements of this sequence.
  @inlinable
  public __consuming func makeIterator() -> Iterator {
    return Iterator(_base: _base.makeIterator())
  }
}

/*
 总体上代码没有多少行, 但是还是分为了四个扩展写的.
 */
