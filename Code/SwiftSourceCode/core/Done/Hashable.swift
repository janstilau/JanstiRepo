/*
 Hashable 主要的用途, 其实就是在 Set, Dict 里面当做 key 来进行使用.
 如果, 系统可以自动推导出 Hash 值来, 那么对象也就可以自动实现 hash 算法.
 具体的条件不用记.
 如果, hash 值可以根据特定的值获取, 那么重写 hash 方法, 用那个特定值来确定最终结果, 是值的推荐的.
 */
///
/// Conforming to the Hashable Protocol
public protocol Hashable: Equatable {
    /*
     最重要的方法, 但是现在实现 Hashable 要求的是实现  func hash(into hasher: inout Hasher)
     也就是, 现在系统要求你提供 hash 的过程, 具体这个值怎么获得,  系统来进行处理.
     */
    var hashValue: Int { get }
    
    /*
     一个类, 具体如何获取到最终值的过程.
     这里, 文档有了明确的说明, 必须是和 equatable 里面的 component 一致.
     如何取哪些值判断相等, 那么就应该, 如何用哪些值进行 hash.
     */
    func hash(into hasher: inout Hasher)
    
    func _rawHashValue(seed: Int) -> Int
}

extension Hashable {
    @inlinable
    @inline(__always)
    public func _rawHashValue(seed: Int) -> Int {
        var hasher = Hasher(_seed: seed)
        hasher.combine(self)
        return hasher._finalize()
    }
}

@inlinable
@inline(__always)
public func _hashValue<H: Hashable>(for value: H) -> Int {
    return value._rawHashValue(seed: 0)
}
@_silgen_name("_swift_stdlib_Hashable_isEqual_indirect")
internal func Hashable_isEqual_indirect<T: Hashable>(
    _ lhs: UnsafePointer<T>,
    _ rhs: UnsafePointer<T>
) -> Bool {
    return lhs.pointee == rhs.pointee
}

// Called by the SwiftValue implementation.
@_silgen_name("_swift_stdlib_Hashable_hashValue_indirect")
internal func Hashable_hashValue_indirect<T: Hashable>(
    _ value: UnsafePointer<T>
) -> Int {
    return value.pointee.hashValue
}
