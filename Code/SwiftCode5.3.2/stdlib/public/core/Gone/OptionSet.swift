/*
    原来的 Enum 有两种使用方式.
    每个 Enum case 代表一个值, 这种在 Swift 里面被 Enum 类型代替, 并且有了很大的加强.
    每个 值, 代理一个集合, 单纯这个值是没有意义的, 在使用的时候, 需要将这个值和特殊值进行比较使用.
    这种使用方式, 其实重要的不是 Type, 而是集合操作.
 OptionSet 抽象的就是这种类型.
 一般来说, OptionSet 里面会用 static 定义一些特殊的值, 用作比较操作.
 并且, OptionSet 的 value, 其实是没有非法值之说的, 因为 type 的组合是各种各样的, 是一个组合的关系.
 使用的时候, 还是和原来的 enum 一样, 判断值与之之间的管理, 通过 SetAlgebra 的抽象, 这层判断不是 &, | 这种二进制操作符, 而是 contians, union 这种更加符合集合操作的语句了.
 一般来说, rawValue 还是 Int 的, 系统也给出了 Int 为 RawValue 的时候, 各种集合操作.

 如果想自定义 rawValue 的话, 那么 SetAlgebra 的各种操作也要自己实现.
 例如, RawValue 为 string, 各个有效的值, 由 , 进行分割, 那么集合操作的时候, 就是先用 , 进行 split, 然后字符串数组进行 contains, union, interact 各种操作. 最终, 值还是以 , 连接的方式变为一个字符串.
 */

public protocol OptionSet: SetAlgebra, RawRepresentable {
    // 这个 Element 是 SetAlgebra 的要求, = Self 也符合 Set 的定义, 集合的各种操作, 都是集合.
    associatedtype Element = Self
    init(rawValue: RawValue)
}

// 对于集合操作的各种实现, 都是建立在 SetAlgebra 的基础上的.
extension OptionSet {
    // Swift 对于改变是自改变, 还是返回值有了明确的命名方式
    // form 开头表示, 自己改变, 否则就是返回值.
    public func union(_ other: Self) -> Self {
        var r: Self = Self(rawValue: self.rawValue)
        r.formUnion(other)
        return r
    }
    
    public func intersection(_ other: Self) -> Self {
        var r = Self(rawValue: self.rawValue)
        r.formIntersection(other)
        return r
    }
    
    public func symmetricDifference(_ other: Self) -> Self {
        var r = Self(rawValue: self.rawValue)
        r.formSymmetricDifference(other)
        return r
    }
}

extension OptionSet where Element == Self {
    public func contains(_ member: Self) -> Bool {
        return self.isSuperset(of: member)
    }
    
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
    
    public mutating func remove(_ member: Element) -> Element? {
        let intersectionElements = intersection(member)
        guard !intersectionElements.isEmpty else {
            return nil
        }
        
        self.subtract(member)
        return intersectionElements
    }
    
    public mutating func update(with newMember: Element) -> Element? {
        let r = self.intersection(newMember)
        self.formUnion(newMember)
        return r.isEmpty ? nil : r
    }
}

// 当 RawValue 是 Int 的时候, 各种集合操作是如何实现的.
// 就是 C 风格最原始的 Int 操作.
extension OptionSet where RawValue: FixedWidthInteger {
    public init() {
        self.init(rawValue: 0)
    }
    public mutating func formUnion(_ other: Self) {
        self = Self(rawValue: self.rawValue | other.rawValue)
    }
    public mutating func formIntersection(_ other: Self) {
        self = Self(rawValue: self.rawValue & other.rawValue)
    }
    public mutating func formSymmetricDifference(_ other: Self) {
        self = Self(rawValue: self.rawValue ^ other.rawValue)
    }
}
