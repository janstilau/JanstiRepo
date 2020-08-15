/*
 专门有一个类型代表 BOOL 值, 而不再是, 00000000 表示 false, 其他表示 true.\
 相比于, 内存不为 0x0000 就为 TRUE, 专门的创建一个类型, 表示判断, 意义要明显的多.
 可能对于习惯于上面内存表示判断的人, 这样的写法比较啰嗦, 但是这种非 0 即为 true 的判断, 实际徒增复杂度
 */

@frozen
public struct Bool {
    @usableFromInline
    /*
     作为一个值类型, 它是占据内存空间的, 只有 1 bit. 所以, 这个类型只会有两个居民存在.
     这个类型, 只有这么一个成员变量.
     */
    internal var _value: Builtin.Int1
    
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
    
    /*
     RandomNumberGenerator 是一个协议, 它的 next 会返回一个UInt64.
     所以, Generator 到底生成一个什么样的数字, 完全可以外界进行控制.
     */
    @inlinable
    public static func random<T: RandomNumberGenerator>(
        using generator: inout T
    ) -> Bool {
        return (generator.next() >> 17) & 1 == 0
    }
    
    /*
     作为类的设计者, 应该提供一个最简便的方法, 给外界的使用者.
     应该提供一个最通用的方法, 给外界需要自定义的人.
     所以, 利用上面的全的方法, 这里提供一个简便的方法.
     */
    @inlinable
    public static func random() -> Bool {
        var g = SystemRandomNumberGenerator()
        return Bool.random(using: &g)
    }
}

extension Bool: _ExpressibleByBuiltinBooleanLiteral, ExpressibleByBooleanLiteral {
    @_transparent
    public init(_builtinBooleanLiteral value: Builtin.Int1) {
        self._value = value
    }
    
    
    /*
     struct Person:ExpressibleByBooleanLiteral {
     typealias BooleanLiteralType = Bool
     
     var name: String
     var age: Int
     init(name: String, age: Int) {
        self.name = name
        self.age = age
     }
     init(booleanLiteral boolValue: Bool) {
     if (boolValue) {
        self.name = "Justin"
        self.age = 23
     } else {
        self.name = "Jansti"
        self.age = 18
     }
     }
     }
     let cPerson:Person = true
     上面是一个例子, 可以编译通过并使用.
     
     如果, 一个自定义的类, 想要直接通过 Bool 值进行初始化, 那么需要显式地申明自己想要这份能力, 也就是 ExpressibleByBooleanLiteral 接口的实现.
     在这个接口里面, init(booleanLiteral boolValue: Bool) 需要被实现, 这个方法, 名字特殊, 有着 parameter label 进行限制.
     相比于, C++ 无缘无故的给你进行转换, 这种写法, 要安全的多. 而且好像只能是通过系统提供的字面量进行初始化
     */
    @_transparent
    public init(booleanLiteral value: Bool) {
        self = value
    }
}

/*
 字符串化.
 */
extension Bool: CustomStringConvertible {
    /// A textual representation of the Boolean value.
    @inlinable
    public var description: String {
        return self ? "true" : "false"
    }
}

/*
 其实还是直接的物理判断.
 */
extension Bool: Equatable {
    @_transparent
    public static func == (lhs: Bool, rhs: Bool) -> Bool {
        return Bool(Builtin.cmp_eq_Int1(lhs._value, rhs._value))
    }
}

extension Bool: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine((self ? 1 : 0) as UInt8)
    }
}

//===----------------------------------------------------------------------===//
// Operators
//===----------------------------------------------------------------------===//
/*
 作为一个类型, 要考虑他相关的操作符. 也就是说, 需要显式地写出这个操作符的定义, 才能模拟出原有 C 风格的效果.
 */
extension Bool {
    @_transparent
    public static prefix func ! (a: Bool) -> Bool {
        return Bool(Builtin.xor_Int1(a._value, true._value))
    }
}

/*
 模拟 C 分割的操作符, 注意, Swift 里面, 所有带有短路效果的操作符, 后面的参数都是自动闭包.
 */
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
