/*
 因为 == 这个操作, 是整个系统运转的核心, 所以, 专门要为它定义一个协议. 这个协议的 primitive Method 就是 == 操作符的实现.
 */
///
/// 很多函数, 是不应该传入闭包的, 如果还是指定函数的运营过程, 就没有那么通用了. 所以, 在各种系统已经提供的实现里面, 有着对于实现了 == 的类型的默认实现.
///
/// 只要自身的成员变量, 实现了 equable 的协议, 那么这个类型就能够自动实现 == 操作. 其实很简单, 数据是数据, 方法是方法, 方法是公用的, 数据是各自对象私有的. 只要比较私有的, 就能判断相等了.

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
 这里, AnyObject, 说明, 这种比较, 仅仅是引用对象的.
 这里, 还包括了可选值的比较.
 
 ObjectIdentifier 仅仅是一个包装了原始指针的盒子.
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


