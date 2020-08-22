/// When implementing a custom type that conforms to the `SetAlgebra` protocol,
/// you must implement the required initializers and methods. For the
/// inherited methods to work properly, conforming types must meet the
/// following axioms. Assume that `S` is a custom type that conforms to the
/// `SetAlgebra` protocol, `x` and `y` are instances of `S`, and `e` is of
/// type `S.Element`---the type that the set holds.
///
/// - `S() == []`
/// - `x.intersection(x) == x`
/// - `x.intersection([]) == []`
/// - `x.union(x) == x`
/// - `x.union([]) == x`
/// - `x.contains(e)` implies `x.union(y).contains(e)`
/// - `x.union(y).contains(e)` implies `x.contains(e) || y.contains(e)`
/// - `x.contains(e) && y.contains(e)` if and only if
///   `x.intersection(y).contains(e)`
/// - `x.isSubset(of: y)` implies `x.union(y) == y`
/// - `x.isSuperset(of: y)` implies `x.union(y) == x`
/// - `x.isSubset(of: y)` if and only if `y.isSuperset(of: x)`
/// - `x.isStrictSuperset(of: y)` if and only if
///   `x.isSuperset(of: y) && x != y`
/// - `x.isStrictSubset(of: y)` if and only if `x.isSubset(of: y) && x != y`
public protocol SetAlgebra: Equatable, ExpressibleByArrayLiteral {
  associatedtype Element
    
  init()
    
  func contains(_ member: Element) -> Bool
    
  __consuming func union(_ other: __owned Self) -> Self
  
  __consuming func intersection(_ other: Self) -> Self

  __consuming func symmetricDifference(_ other: __owned Self) -> Self

  @discardableResult
  mutating func insert(
    _ newMember: __owned Element
  ) -> (inserted: Bool, memberAfterInsert: Element)
  
  @discardableResult
  mutating func remove(_ member: Element) -> Element?

  @discardableResult
  mutating func update(with newMember: __owned Element) -> Element?
  
  mutating func formUnion(_ other: __owned Self)

  mutating func formIntersection(_ other: Self)

  mutating func formSymmetricDifference(_ other: __owned Self)

  __consuming func subtracting(_ other: Self) -> Self

  func isSubset(of other: Self) -> Bool

  func isDisjoint(with other: Self) -> Bool

  func isSuperset(of other: Self) -> Bool

  var isEmpty: Bool { get }
  
  init<S: Sequence>(_ sequence: __owned S) where S.Element == Element

  mutating func subtract(_ other: Self)
}

extension SetAlgebra {
  @inlinable // protocol-only
    /*
     通过一个序列, 进行初始化, 就是不断的进行 insert 的过程.
     */
  public init<S: Sequence>(_ sequence: __owned S)
    where S.Element == Element {
    self.init()
    for e in sequence { insert(e) }
  }

    /*
     以下, 各种的操作, 其实都是数学的概念.
     */
  @inlinable // protocol-only
  public mutating func subtract(_ other: Self) {
    self.formIntersection(self.symmetricDifference(other))
  }

  @inlinable // protocol-only
  public func isSubset(of other: Self) -> Bool {
    return self.intersection(other) == self
  }

  @inlinable // protocol-only
  public func isSuperset(of other: Self) -> Bool {
    return other.isSubset(of: self)
  }

  @inlinable // protocol-only
  public func isDisjoint(with other: Self) -> Bool {
    return self.intersection(other).isEmpty
  }

  @inlinable // protocol-only
  public func subtracting(_ other: Self) -> Self {
    return self.intersection(self.symmetricDifference(other))
  }

  @inlinable // protocol-only
  public var isEmpty: Bool {
    return self == Self()
  }

  @inlinable // protocol-only
  public func isStrictSuperset(of other: Self) -> Bool {
    return self.isSuperset(of: other) && self != other
  }

  @inlinable // protocol-only
  public func isStrictSubset(of other: Self) -> Bool {
    return other.isStrictSuperset(of: self)
  }
}

extension SetAlgebra where Element == ArrayLiteralElement {
    /*
     通过字面量, 进行初始化, 就是通过字面量, 先转化成为相应的序列, 然后调用通过序列进行初始化的函数
     */
  @inlinable // protocol-only
  public init(arrayLiteral: Element...) {
    self.init(arrayLiteral)
  }  
}
