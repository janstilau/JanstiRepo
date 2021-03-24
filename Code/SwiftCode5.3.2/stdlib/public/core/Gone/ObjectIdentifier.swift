// 因为, Swift 里面将指针的操作隐藏了, 所以, 想要利用指针作为对象的唯一性判断, 要经过 ObjectIdentifier 包装一层.
// 其实, 在 C++ 里面, 指针可以作为 key, 因为有一个专门的通过指针计算出 hash 值的函数.
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

// 各种协议的实现, 都是根据 value 里面存储的 rawPointer 进行的.
extension ObjectIdentifier: Equatable {
    public static func == (x: ObjectIdentifier,
                           y: ObjectIdentifier) -> Bool {
        return Bool(Builtin.cmp_eq_RawPointer(x._value, y._value))
    }
}
// 实际上, 就是指针在内存上位置的比较. 只不过, 需要专门的从 指针 => 到 Uint 的转化工作.
extension ObjectIdentifier: Comparable {
    public static func < (lhs: ObjectIdentifier,
                          rhs: ObjectIdentifier) -> Bool {
        return UInt(bitPattern: lhs) < UInt(bitPattern: rhs)
    }
}
// 将指针, 变化成为 Int, 传递到 hasher 里面.
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
