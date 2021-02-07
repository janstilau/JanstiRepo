// 这个协议, 最最重要的目的, 就是进行相等性的判断.
// 可判等是一个非常重要的事情, 计算机的本质, 无非就是比大小. 很多的算法, 如果算法的参数可以进行大小比较, 就不用传递 equal block 了.
// EqualAble 也是 Hashable, Comparable 的基本协议.
// 自动合成的 EqualAble 的原则就是, 从物理内存上, 可以判等, 也就是 struct 的成员变量可判等, enum 的关联变量可判等.
// Enum 首先是 type 判等, 然后是 type 相等下的各个值相等.
// Class 默认是地址判等. 如果想要根据成员变量判等, 需要重写 == .

public protocol Equatable {
    // lsh, rhs 是一个很标准的命名方式.
    static func == (lhs: Self, rhs: Self) -> Bool
}

extension Equatable {
    public static func != (lhs: Self, rhs: Self) -> Bool {
        return !(lhs == rhs)
    }
}

// 这里, 传递的是 Optinal, 编译器自动会进行包装.
// Optinal 的引入, 使得 Swift 里面, 不会出现空指针这种事情. 原因在于, 编译器会做考核, 所有没有初始化过的数据, 无法直接使用, 这也就导致了, 所有的引用对象, 都是有值的.
// ObjectIdentifier 是一个辅助类, 实现了指针对于相等性, hash 性的要求.
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

public func !== (lhs: AnyObject?, rhs: AnyObject?) -> Bool {
    return !(lhs === rhs)
}


