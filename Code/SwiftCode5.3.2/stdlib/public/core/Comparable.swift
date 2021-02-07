// 想要实现 Comparable, 必须是 Equatable 的.
public protocol Comparable: Equatable {
    static func < (lhs: Self, rhs: Self) -> Bool
    static func <= (lhs: Self, rhs: Self) -> Bool
    static func >= (lhs: Self, rhs: Self) -> Bool
    static func > (lhs: Self, rhs: Self) -> Bool
}

extension Comparable {
    // 大于号的默认实现, 就是 rhs, lhs 位置互换, 逻辑学的使用.
    public static func > (lhs: Self, rhs: Self) -> Bool {
        return rhs < lhs
    }
    
    // 逻辑学的
    public static func <= (lhs: Self, rhs: Self) -> Bool {
        return !(rhs < lhs)
    }
    
    // 逻辑学的
    public static func >= (lhs: Self, rhs: Self) -> Bool {
        return !(lhs < rhs)
    }
}
