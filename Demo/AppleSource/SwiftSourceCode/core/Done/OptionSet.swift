/*
 OptionSet 这个协议, 就是专门用来表示, 可以进行 | 操作的类型.
 这种形式的数据, 从 enum 里面完全抽离出来, 通过类的 static 属性, 来获取相应的值.
 值可以通过 SetAlgebra 的方法, 进行组合操作.
 */

public protocol OptionSet: SetAlgebra, RawRepresentable {
  associatedtype Element = Self
  init(rawValue: RawValue)
}

extension OptionSet {
  @inlinable // generic-performance
  public func union(_ other: Self) -> Self {
    var r: Self = Self(rawValue: self.rawValue)
    r.formUnion(other)
    return r
  }
  
  @inlinable // generic-performance
  public func intersection(_ other: Self) -> Self {
    var r = Self(rawValue: self.rawValue)
    r.formIntersection(other)
    return r
  }
  
  @inlinable // generic-performance
  public func symmetricDifference(_ other: Self) -> Self {
    var r = Self(rawValue: self.rawValue)
    r.formSymmetricDifference(other)
    return r
  }
}

extension OptionSet where Element == Self {
  @inlinable // generic-performance
  public func contains(_ member: Self) -> Bool {
    return self.isSuperset(of: member)
  }
  
  /// Adds the given element to the option set if it is not already a member.
  ///
  /// In the following example, the `.secondDay` shipping option is added to
  /// the `freeOptions` option set if `purchasePrice` is greater than 50.0. For
  /// the `ShippingOptions` declaration, see the `OptionSet` protocol
  /// discussion.
  ///
  ///     let purchasePrice = 87.55
  ///
  ///     var freeOptions: ShippingOptions = [.standard, .priority]
  ///     if purchasePrice > 50 {
  ///         freeOptions.insert(.secondDay)
  ///     }
  ///     print(freeOptions.contains(.secondDay))
  ///     // Prints "true"
  ///
  /// - Parameter newMember: The element to insert.
  /// - Returns: `(true, newMember)` if `newMember` was not contained in
  ///   `self`. Otherwise, returns `(false, oldMember)`, where `oldMember` is
  ///   the member of the set equal to `newMember`.
  @inlinable // generic-performance
  @discardableResult
  public mutating func insert(
    _ newMember: Element
  ) -> (inserted: Bool, memberAfterInsert: Element) {
    let oldMember = self.intersection(newMember)
    let shouldInsert = oldMember != newMember
    let result = (
      inserted: shouldInsert,
      memberAfterInsert: shouldInsert ? newMember : oldMember)
    if shouldInsert {
      self.formUnion(newMember)
    }
    return result
  }
  
  /// Removes the given element and all elements subsumed by it.
  ///
  /// In the following example, the `.priority` shipping option is removed from
  /// the `options` option set. Attempting to remove the same shipping option
  /// a second time results in `nil`, because `options` no longer contains
  /// `.priority` as a member.
  ///
  ///     var options: ShippingOptions = [.secondDay, .priority]
  ///     let priorityOption = options.remove(.priority)
  ///     print(priorityOption == .priority)
  ///     // Prints "true"
  ///
  ///     print(options.remove(.priority))
  ///     // Prints "nil"
  ///
  /// In the next example, the `.express` element is passed to `remove(_:)`.
  /// Although `.express` is not a member of `options`, `.express` subsumes
  /// the remaining `.secondDay` element of the option set. Therefore,
  /// `options` is emptied and the intersection between `.express` and
  /// `options` is returned.
  ///
  ///     let expressOption = options.remove(.express)
  ///     print(expressOption == .express)
  ///     // Prints "false"
  ///     print(expressOption == .secondDay)
  ///     // Prints "true"
  ///
  /// - Parameter member: The element of the set to remove.
  /// - Returns: The intersection of `[member]` and the set, if the
  ///   intersection was nonempty; otherwise, `nil`.
  @inlinable // generic-performance
  @discardableResult
  public mutating func remove(_ member: Element) -> Element? {
    let r = isSuperset(of: member) ? Optional(member) : nil
    self.subtract(member)
    return r
  }

  /// Inserts the given element into the set.
  ///
  /// If `newMember` is not contained in the set but subsumes current members
  /// of the set, the subsumed members are returned.
  ///
  ///     var options: ShippingOptions = [.secondDay, .priority]
  ///     let replaced = options.update(with: .express)
  ///     print(replaced == .secondDay)
  ///     // Prints "true"
  ///
  /// - Returns: The intersection of `[newMember]` and the set if the
  ///   intersection was nonempty; otherwise, `nil`.
  @inlinable // generic-performance
  @discardableResult
  public mutating func update(with newMember: Element) -> Element? {
    let r = self.intersection(newMember)
    self.formUnion(newMember)
    return r.isEmpty ? nil : r
  }
}

/*
 如果, Rawvalue 是一个 int 值, 那么 SetAlgebra 的各种算法, 就可以通过 Int 的算法直接使用了.
 对于 OptionSet 来说, Rawvalue 是 Int 是一个非常常用的做法.
 */

extension OptionSet where RawValue: FixedWidthInteger {
  @inlinable // generic-performance
  public init() {
    self.init(rawValue: 0)
  }

/*
     Form 开头的方法, 一般就伴随着自身的修改, 这是 Swift 的命名习惯
     */
  @inlinable // generic-performance
  public mutating func formUnion(_ other: Self) {
    self = Self(rawValue: self.rawValue | other.rawValue)
  }
  
  @inlinable // generic-performance
  public mutating func formIntersection(_ other: Self) {
    self = Self(rawValue: self.rawValue & other.rawValue)
  }
  
  @inlinable // generic-performance
  public mutating func formSymmetricDifference(_ other: Self) {
    self = Self(rawValue: self.rawValue ^ other.rawValue)
  }
}
