// 很多算法, 在 C++ 里面, 是泛型实现的.
// C++ 里面, 是依靠着编译器来做的校验, 在 Swift 里面, 是依靠着协议.
public func min<T: Comparable>(_ x: T, _ y: T) -> T {
  return y < x ? y : x
}

// T... 这种, 自己写函数的时候, 经常忘记的特性, 可以多尝试一下.
@inlinable // protocol-only
public func min<T: Comparable>(_ x: T, _ y: T, _ z: T, _ rest: T...) -> T {
  var minValue = min(min(x, y), z)
  // In case `value == minValue`, we pick `minValue`. See min(_:_:).
  for value in rest where value < minValue {
    minValue = value
  }
  return minValue
}

@inlinable // protocol-only
public func max<T: Comparable>(_ x: T, _ y: T) -> T {
  return y >= x ? y : x
}

@inlinable // protocol-only
public func max<T: Comparable>(_ x: T, _ y: T, _ z: T, _ rest: T...) -> T {
  var maxValue = max(max(x, y), z)
  for value in rest where value >= maxValue {
    maxValue = value
  }
  return maxValue
}


// 从数据层面上来, 这个类仅仅是存了一下原来的 sequence.
@frozen
public struct EnumeratedSequence<Base: Sequence> {
  @usableFromInline
  internal var _base: Base
  @inlinable
  internal init(_base: Base) {
    self._base = _base
  }
}

extension EnumeratedSequence {
  @frozen
  public struct Iterator {
    @usableFromInline
    internal var _base: Base.Iterator
    @usableFromInline
    internal var _count: Int

    /// Construct from a `Base` iterator.
    @inlinable
    internal init(_base: Base.Iterator) {
      self._base = _base
      self._count = 0
    }
  }
}

// 但是在迭代的时候, 包装类的迭代器, 存储了一下 index 的位置, 也就是 offset 的值.
// 真正的原始数据, 还是通过 base sequence 来进行获取, 但是返回的 next 数据, 是 offset, ele 的元组
extension EnumeratedSequence.Iterator: IteratorProtocol, Sequence {
  /// The type of element returned by `next()`.
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
