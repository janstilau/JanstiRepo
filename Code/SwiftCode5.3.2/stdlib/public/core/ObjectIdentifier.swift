// 引用数据类型, 自然应该是指针比较, 但是 pointer 在 Swift 里面, 是危险的行为.
// 所以, 专门有一个类, 将引用对象到指针的转化, 进行了封装, 在类的内部, 还是指针操作, 但是外界使用者并不知道.
// 这个类, 主要就是相等性, hash 的实现.
public struct ObjectIdentifier {
    // 里面的值, 就是存放的指针.
    internal let _value: Builtin.RawPointer
        
    public init(_ x: AnyObject) {
        self._value = Builtin.bridgeToRawPointer(x)
    }
    
    // unsafeBitCast 类似于 interpre_cast
    // 所以, 如果传递过来的是元类型信息, 直接就是强制类型转化就可以了.
    // 这里, 能够看出来, Swift 里面, 任何类型, 就算是 struct, 都是有着源类型的.
    public init(_ x: Any.Type) {
        self._value = unsafeBitCast(x, to: Builtin.RawPointer.self)
    }
}


extension ObjectIdentifier: Equatable {
    public static func == (x: ObjectIdentifier, y: ObjectIdentifier) -> Bool {
        return Bool(Builtin.cmp_eq_RawPointer(x._value, y._value))
    }
}

extension ObjectIdentifier: Comparable {
    public static func < (lhs: ObjectIdentifier, rhs: ObjectIdentifier) -> Bool {
        return UInt(bitPattern: lhs) < UInt(bitPattern: rhs)
    }
}

extension ObjectIdentifier: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(Int(Builtin.ptrtoint_Word(_value)))
    }
}

extension UInt {
    public init(bitPattern objectID: ObjectIdentifier) {
        self.init(Builtin.ptrtoint_Word(objectID._value))
    }
}

extension Int {
    public init(bitPattern objectID: ObjectIdentifier) {
        self.init(bitPattern: UInt(bitPattern: objectID))
    }
}
