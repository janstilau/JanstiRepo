// A type that can be hashed into a `Hasher` to produce an integer hash value.
// 所以, 实际上, hasher 做的事情, 并没有太大的变化. 还是最终生成一个 hash 值.


// Swift 对于 hash 值的自动计算, 是建立在 protocol 的基础上的. 对于 Array, 如果想要成为 hashable 的, 那么要求其中的 value 必须也是 hashable 的.

// Struct 和 Enum, 如果他们的存储单元都是 hashable 的, 那么可以自动变为 hashable. 这个应该是编译器的事情, 因为Struct enum 作为基本的数据类型.
// Hasher 的出现, 让 feed 的顺序也尤其重要了, 普通意义上的  hashvalue 和 equtable 的关系, 也因此有了顺序上的考虑.

public protocol Hashable: Equatable {
    // 最原始的 hash 类型应该提供的值, 但是 Swift 目前, 更加强调使用 Hasher 获取该值.
    var hashValue: Int { get }
    
    // 填充到 hasher 里面的内容, 应该和 equalable 里面判断的内容, 是一模一样的.
    // 让用户写出一个 hash 算法来, 实在是太难了. 而 hash 算法是可以提前写好的, 然后填入不同数据就可以了.
    // 侯捷的课程里面, 就有相关的构建一个万能的哈希算法章节. Hasher 这个类, 应该就是对于这个万能哈希算法的封装.
    func hash(into hasher: inout Hasher)
    
    // 默认实现, 就是生成一个 Hasher, 通过这个 Hasher 来获取 hashValue.
    // 源码里面, _ 开头表示私有方法的传统, 一直没有丢.
    func _rawHashValue(seed: Int) -> Int
}

extension Hashable {
    public func _rawHashValue(seed: Int) -> Int {
        var hasher = Hasher(_seed: seed)
        hasher.combine(self)
        return hasher._finalize()
    }
}

// 类似于 C++ 的全局 hash 函数. 内部使用通用算法生成 hash 值.
public func _hashValue<H: Hashable>(for value: H) -> Int {
    return value._rawHashValue(seed: 0)
}

internal func Hashable_isEqual_indirect<T: Hashable>(
    _ lhs: UnsafePointer<T>,
    _ rhs: UnsafePointer<T>
) -> Bool {
    return lhs.pointee == rhs.pointee
}

internal func Hashable_hashValue_indirect<T: Hashable>(
    _ value: UnsafePointer<T>
) -> Int {
    return value.pointee.hashValue
}
