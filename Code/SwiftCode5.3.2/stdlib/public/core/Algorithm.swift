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


