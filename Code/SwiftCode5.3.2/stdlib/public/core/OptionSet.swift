/*
 0X0010101101
 这种方式, 是之前 C 时代用来进行 Optioan 操作的方式, 当我们想要一个 Int 值传递多特性的时候, 就会使用这种方式.
 
 但是, 实际上, 我们想要的效果是 1判断有没有, 2可以加, 3可以减
 这些其实都是集合操作.
 既然是集合, 那么如果里面是一个 set 的话, 也可以完成上面这些操作.
 如果还能指定一些特殊的值, 比如, monday 这个字符串表示星期一, 那么 set 里面填充的值组合, 也就有了意义, 比如7天的值都填充进去了, 那就是一周都算了.
 所以, 其实并不是要使用这种二进制偏移的方式, 来实现 optionset.
 
 Swift OptionSet 由 SetAlgebra, RawRepresentable 两个协议构成, 就是明确的表示了这个事情,
 1. 这个类型, 需要支持集合操作.
 2. 这个类型, 里面的值, 需要能够使用某个原始类型的值直接能够生成.
 */
public protocol OptionSet: SetAlgebra, RawRepresentable {
    // We can't constrain the associated Element type to be the same as
    // Self, but we can do almost as well with a default and a
    // constrained extension
    
    /// The element type of the option set.
    ///
    /// To inherit all the default implementations from the `OptionSet` protocol,
    /// the `Element` type must be `Self`, the default.
    associatedtype Element = Self
    
    // FIXME: This initializer should just be the failable init from
    // RawRepresentable. Unfortunately, current language limitations
    // that prevent non-failable initializers from forwarding to
    // failable ones would prevent us from generating the non-failing
    // default (zero-argument) initializer.  Since OptionSet's main
    // purpose is to create convenient conformances to SetAlgebra,
    // we opt for a non-failable initializer.
    
    /// Creates a new option set from the given raw value.
    ///
    /// This initializer always succeeds, even if the value passed as `rawValue`
    /// exceeds the static properties declared as part of the option set. This
    /// example creates an instance of `ShippingOptions` with a raw value beyond
    /// the highest element, with a bit mask that effectively contains all the
    /// declared static members.
    ///
    ///     let extraOptions = ShippingOptions(rawValue: 255)
    ///     print(extraOptions.isStrictSuperset(of: .all))
    ///     // Prints "true"
    ///
    /// - Parameter rawValue: The raw value of the option set to create. Each bit
    ///   of `rawValue` potentially represents an element of the option set,
    ///   though raw values may include bits that are not defined as distinct
    ///   values of the `OptionSet` type.
    init(rawValue: RawValue)
}

/// `OptionSet` requirements for which default implementations
/// are supplied.
///
/// - Note: A type conforming to `OptionSet` can implement any of
///  these initializers or methods, and those implementations will be
///  used in lieu of these defaults.
extension OptionSet {
    /// Returns a new option set of the elements contained in this set, in the
    /// given set, or in both.
    ///
    /// This example uses the `union(_:)` method to add two more shipping options
    /// to the default set.
    ///
    ///     let defaultShipping = ShippingOptions.standard
    ///     let memberShipping = defaultShipping.union([.secondDay, .priority])
    ///     print(memberShipping.contains(.priority))
    ///     // Prints "true"
    ///
    /// - Parameter other: An option set.
    /// - Returns: A new option set made up of the elements contained in this
    ///   set, in `other`, or in both.
    @inlinable // generic-performance
    public func union(_ other: Self) -> Self {
        var r: Self = Self(rawValue: self.rawValue)
        r.formUnion(other)
        return r
    }
    
    /// Returns a new option set with only the elements contained in both this
    /// set and the given set.
    ///
    /// This example uses the `intersection(_:)` method to limit the available
    /// shipping options to what can be used with a PO Box destination.
    ///
    ///     // Can only ship standard or priority to PO Boxes
    ///     let poboxShipping: ShippingOptions = [.standard, .priority]
    ///     let memberShipping: ShippingOptions =
    ///             [.standard, .priority, .secondDay]
    ///
    ///     let availableOptions = memberShipping.intersection(poboxShipping)
    ///     print(availableOptions.contains(.priority))
    ///     // Prints "true"
    ///     print(availableOptions.contains(.secondDay))
    ///     // Prints "false"
    ///
    /// - Parameter other: An option set.
    /// - Returns: A new option set with only the elements contained in both this
    ///   set and `other`.
    @inlinable // generic-performance
    public func intersection(_ other: Self) -> Self {
        var r = Self(rawValue: self.rawValue)
        r.formIntersection(other)
        return r
    }
    
    /// Returns a new option set with the elements contained in this set or in
    /// the given set, but not in both.
    ///
    /// - Parameter other: An option set.
    /// - Returns: A new option set with only the elements contained in either
    ///   this set or `other`, but not in both.
    @inlinable // generic-performance
    public func symmetricDifference(_ other: Self) -> Self {
        var r = Self(rawValue: self.rawValue)
        r.formSymmetricDifference(other)
        return r
    }
}

/// `OptionSet` requirements for which default implementations are
/// supplied when `Element == Self`, which is the default.
///
/// - Note: A type conforming to `OptionSet` can implement any of
///   these initializers or methods, and those implementations will be
///   used in lieu of these defaults.
extension OptionSet where Element == Self {
    /// Returns a Boolean value that indicates whether a given element is a
    /// member of the option set.
    ///
    /// This example uses the `contains(_:)` method to check whether next-day
    /// shipping is in the `availableOptions` instance.
    ///
    ///     let availableOptions = ShippingOptions.express
    ///     if availableOptions.contains(.nextDay) {
    ///         print("Next day shipping available")
    ///     }
    ///     // Prints "Next day shipping available"
    ///
    /// - Parameter member: The element to look for in the option set.
    /// - Returns: `true` if the option set contains `member`; otherwise,
    ///   `false`.
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
        let intersectionElements = intersection(member)
        guard !intersectionElements.isEmpty else {
            return nil
        }
        
        self.subtract(member)
        return intersectionElements
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

/// `OptionSet` requirements for which default implementations are
/// supplied when `RawValue` conforms to `FixedWidthInteger`,
/// which is the usual case.  Each distinct bit of an option set's
/// `.rawValue` corresponds to a disjoint value of the `OptionSet`.
///
/// - `union` is implemented as a bitwise "or" (`|`) of `rawValue`s
/// - `intersection` is implemented as a bitwise "and" (`&`) of
///   `rawValue`s
/// - `symmetricDifference` is implemented as a bitwise "exclusive or"
///    (`^`) of `rawValue`s
///
/// - Note: A type conforming to `OptionSet` can implement any of
///   these initializers or methods, and those implementations will be
///   used in lieu of these defaults.
extension OptionSet where RawValue: FixedWidthInteger {
    /// Creates an empty option set.
    ///
    /// This initializer creates an option set with a raw value of zero.
    @inlinable // generic-performance
    public init() {
        self.init(rawValue: 0)
    }
    
    /// Inserts the elements of another set into this option set.
    ///
    /// This method is implemented as a `|` (bitwise OR) operation on the
    /// two sets' raw values.
    ///
    /// - Parameter other: An option set.
    @inlinable // generic-performance
    public mutating func formUnion(_ other: Self) {
        self = Self(rawValue: self.rawValue | other.rawValue)
    }
    
    /// Removes all elements of this option set that are not 
    /// also present in the given set.
    ///
    /// This method is implemented as a `&` (bitwise AND) operation on the
    /// two sets' raw values.
    ///
    /// - Parameter other: An option set.
    @inlinable // generic-performance
    public mutating func formIntersection(_ other: Self) {
        self = Self(rawValue: self.rawValue & other.rawValue)
    }
    
    /// Replaces this set with a new set containing all elements 
    /// contained in either this set or the given set, but not in both.
    ///
    /// This method is implemented as a `^` (bitwise XOR) operation on the two
    /// sets' raw values.
    ///
    /// - Parameter other: An option set.
    @inlinable // generic-performance
    public mutating func formSymmetricDifference(_ other: Self) {
        self = Self(rawValue: self.rawValue ^ other.rawValue)
    }
}
