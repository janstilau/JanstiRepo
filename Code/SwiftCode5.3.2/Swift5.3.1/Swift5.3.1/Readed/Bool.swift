/*
 为什么专门要有这么一个类.
 之前的非0为真, 其实是有一点问题的. 会有很多的误操作.
 专门有一个 Bool 类, 所有判断的地方, 都是要Bool 类型的值, 就不能进行非零为真的判断了.
 所有的对象, 如果想要实现 Bool 的含义, 必须自己定义转化操作.
 */

@frozen
public struct Bool {
    @usableFromInline
    internal var _value: Builtin.Int1 // 只占用了一个 bit 位置的 int. 所以, 实际上还是原来的数据的表示.
    
    @_transparent
    public init() {
        let zero: Int8 = 0
        self._value = Builtin.trunc_Int8_Int1(zero._value)
    }
    
    @usableFromInline @_transparent
    internal init(_ v: Builtin.Int1) { self._value = v }
    
    @inlinable
    public init(_ value: Bool) {
        self = value
    }
    
    // 因为, generator.next() 是 mutatig 的, 所以这里必须是 inout 的.
    // 因为我们知道, 当不是计算属性, 没有属性观察的时候, 其实就是地址传递, 所以对于 struct 的 inout 的传递, 就没有了那么多的恐惧.
    @inlinable
    public static func random<T: RandomNumberGenerator>(
        using generator: inout T
    ) -> Bool {
        return (generator.next() >> 17) & 1 == 0
    }
    
    // 设计 Api 的时候, 可以考虑这样. 提供一个默认的版本, 提供一个可配置的版本. 当然, 最终的实现, 还是在可配置的版本里面.
    @inlinable
    public static func random() -> Bool {
        var g = SystemRandomNumberGenerator()
        return Bool.random(using: &g)
    }
}

// 设计自己的类的时候, 也应该这样, 一个 extension, 一个协议的使用.
// bool 可以通过字符串进行初始化.
// 在 init 方法里面, 多用 self, 这应该是比较能够确定的事情.
extension Bool: _ExpressibleByBuiltinBooleanLiteral, ExpressibleByBooleanLiteral {
    @_transparent
    public init(_builtinBooleanLiteral value: Builtin.Int1) {
        self._value = value
    }
    @_transparent
    public init(booleanLiteral value: Bool) {
        self = value
    }
}

// Bool 的字符串化.
extension Bool: CustomStringConvertible {
    /// A textual representation of the Boolean value.
    @inlinable
    public var description: String {
        return self ? "true" : "false"
    }
}

// 直接就是底层数据的比较.
extension Bool: Equatable {
    @_transparent
    public static func == (lhs: Bool, rhs: Bool) -> Bool {
        return Bool(Builtin.cmp_eq_Int1(lhs._value, rhs._value))
    }
}

// 直接使用万能 hash 算法, 填入的是 1. 0
extension Bool: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine((self ? 1 : 0) as UInt8)
    }
}

// 直接通过字符串来初始化数据, 一般来说, 这个 init 都是 optinal 的
extension Bool: LosslessStringConvertible {
    @inlinable
    public init?(_ description: String) {
        if description == "true" {
            self = true
        } else if description == "false" {
            self = false
        } else {
            return nil
        }
    }
}

//===----------------------------------------------------------------------===//
// Operators
//===----------------------------------------------------------------------===//

// ! 这个操作符, 不是天然的存在 Bool 类型上了, 必须定义了才可以.
extension Bool {
    @_transparent
    public static prefix func ! (a: Bool) -> Bool {
        return Bool(Builtin.xor_Int1(a._value, true._value))
    }
}

// && 这个操作符, 这里, 变成了自动闭包了.
extension Bool {
    @_transparent
    @inline(__always)
    public static func && (lhs: Bool, rhs: @autoclosure () throws -> Bool) rethrows
    -> Bool {
        return lhs ? try rhs() : false
    }
    
    @_transparent
    @inline(__always)
    public static func || (lhs: Bool, rhs: @autoclosure () throws -> Bool) rethrows
    -> Bool {
        return lhs ? true : try rhs()
    }
}

extension Bool {
    @inlinable
    public mutating func toggle() {
        self = !self
    }
}
