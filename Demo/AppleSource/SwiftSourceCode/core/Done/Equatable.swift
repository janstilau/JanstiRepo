/*
 因为 == 这个操作, 是整个系统运转的核心, 所以, 专门要为它定义一个协议. 这个协议的 primitive Method 就是 == 操作符的实现.
 */
///
/// 很多函数, 是不应该传入闭包的, 如果还是指定函数的运营过程, 就没有那么通用了.
///
/// Conforming to the Equatable Protocol
/// ====================================
/// 类型自动进行 equal 的适配.
/// 当符合下面的条件的时候, Struct 和 Enum 会自动符合 Equatable
///  其实, 很简单, 就是内存上的值, 都是可以进行 equal 的判断, 那么整个值, 也就可以这样判断了.

/*
 因为这是操作符的重载, 所以要用 static 修饰.
 相比于, C++ 在类内部函数操作符重载, 默认操作符左边是 Self. Swift static, 两个操作参数的形式更加明确.
 */
public protocol Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool
}

/*
 用 primitive 来完成后续工作, 能够保持逻辑的统一.
 */
extension Equatable {
    @_transparent
    public static func != (lhs: Self, rhs: Self) -> Bool {
        return !(lhs == rhs)
    }
}

/*
 同一性比较.
 */
//===----------------------------------------------------------------------===//
// Reference comparison
//===----------------------------------------------------------------------===//

/*
 虽然, 引用相等不是 Equatable 协议里面的, 但是应该放到这个文件里面, 文件管理按照功能来划分代码.
 这里, 包括了可选值的比较.
 */
@inlinable // trivial-implementation
public func === (lhs: AnyObject?, rhs: AnyObject?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return ObjectIdentifier(l) == ObjectIdentifier(r)
    case (nil, nil):
        return true
    default:
        return false
    }
}

@inlinable // trivial-implementation
public func !== (lhs: AnyObject?, rhs: AnyObject?) -> Bool {
    return !(lhs === rhs)
}


