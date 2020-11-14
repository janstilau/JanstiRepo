
/*
 其实, 这个 struct 就是一个盒子, 这个盒子里面, 是引用对象的原始指针.
 */
@frozen
public struct ObjectIdentifier {
  @usableFromInline
  internal let _value: Builtin.RawPointer
  @inlinable // trivial-implementation
  public init(_ x: AnyObject) {
    self._value = Builtin.bridgeToRawPointer(x)
  }

  @inlinable // trivial-implementation
  public init(_ x: Any.Type) {
    self._value = unsafeBitCast(x, to: Builtin.RawPointer.self)
  }
}

/*
 直接比较的就是指针是否相同.
 */
extension ObjectIdentifier: Equatable {
  @inlinable // trivial-implementation
  public static func == (x: ObjectIdentifier, y: ObjectIdentifier) -> Bool {
    return Bool(Builtin.cmp_eq_RawPointer(x._value, y._value))
  }
}

/*
 直接比较的, 就是存储的指针的位置.
 */
extension ObjectIdentifier: Comparable {
  @inlinable // trivial-implementation
  public static func < (lhs: ObjectIdentifier, rhs: ObjectIdentifier) -> Bool {
    return UInt(bitPattern: lhs) < UInt(bitPattern: rhs)
  }
}

/*
 直接用的指针, 变换成为的 Int 值, 当做 hash 值.
 */
extension ObjectIdentifier: Hashable {
  @inlinable
  public func hash(into hasher: inout Hasher) {
    hasher.combine(Int(Builtin.ptrtoint_Word(_value)))
  }
}

extension UInt {
  /// Creates an integer that captures the full value of the given object
  /// identifier.
  @inlinable // trivial-implementation
  public init(bitPattern objectID: ObjectIdentifier) {
    self.init(Builtin.ptrtoint_Word(objectID._value))
  }
}

extension Int {
  /// Creates an integer that captures the full value of the given object
  /// identifier.
  @inlinable // trivial-implementation
  public init(bitPattern objectID: ObjectIdentifier) {
    self.init(bitPattern: UInt(bitPattern: objectID))
  }
}
