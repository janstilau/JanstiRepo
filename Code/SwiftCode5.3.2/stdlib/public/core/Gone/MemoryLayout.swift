// Size 这个数据类型, 实际数据的大小
// Stride 这个数据类型, 占据内存的大小, 里面会有对齐的考虑
// Alignment 这个数据类型的对齐方式.

//     struct Point {
//         let x: Double
//         let y: Double
//         let isFilled: Bool
//     }
//      MemoryLayout<Point>.size == 17
//      MemoryLayout<Point>.stride == 24
//      MemoryLayout<Point>.alignment == 8
//
//     let count = 4
//     let pointPointer = UnsafeMutableRawPointer.allocate(
//             bytes: count * MemoryLayout<Point>.stride,
//            alignedTo: MemoryLayout<Point>.alignment)


// 这个类, 最主要的方法, 都是对于 builtin 里面方法的封装. 所以实际的实现并不太清楚.
// 这种, 将类型参数当做参数来使用的方式, 在 C++ 里面特别流行.
// 这是一个 Enum, 而 Swift 的 namespace, 也是一个 Enum 完成的.
// Enum 作为包装类型, 没有成员变量. 承担了命名空间的职责.


// You can use MemoryLayout as a source of information about a type when allocating or binding memory using raw pointers.
// 在苹果眼里, 这个类, 主要还是用于内存分配管理的.
public enum MemoryLayout<T> {
    // A type’s size does not include any dynamically allocated or out of line storage. In particular, MemoryLayout<T>.size, when T is a class type, is the same regardless of how many stored properties T has.
    // 这里指的是, class 是会有类信息的指针在开头的, size 不包括这些信息, 仅仅包括类的成员变量占用的信息.
    public static var size: Int {
        return Int(Builtin.sizeof(T.self))
    }
    
    public static var stride: Int {
        return Int(Builtin.strideof(T.self))
    }
    
    public static var alignment: Int {
        return Int(Builtin.alignof(T.self))
    }
}

// 最主要的, 还是上面的封装.
// 但是函数有着类型推导的能力, 很多函数, 例如 dropLast, strde, 都是在函数内部生成一个对应的泛型对象, 泛型对象里面的类型, 都是利用函数推导出来的类型.
// 这里, MemoryLayout 需要的是类型, 但是 value 本身就是带有类型的. 一个简单地函数, 将 value 的 T 进行推导, 然后将推导出来的 T, 用到  MemoryLayout 中.
extension MemoryLayout {
    public static func size(ofValue value: T) -> Int {
        return MemoryLayout<T>.size
    }
    public static func stride(ofValue value: T) -> Int {
        return MemoryLayout.stride
    }
    public static func alignment(ofValue value: T) -> Int {
        return MemoryLayout.alignment
    }
    
        
    // 直接, 返回的就是 key 里面存储的值.
    // 所以, 在 PartialKeyPath<T> 构建的时候, 就应该是存储了这个值
    // 这个值, 应该是存在类型的元信息里面.
    // 通过这个值, 就能够达成, C 语言风格的, 指针寻找成员变量地址, 然后直接对成员变量赋值的操作了.
    public static func offset(of key: PartialKeyPath<T>) -> Int? {
        return key._storedInlineOffset
    }
}

extension MemoryLayout {
    internal static var _alignmentMask: Int { return alignment - 1 }
    
    internal static func _roundingUpToAlignment(_ value: Int) -> Int {
        return (value + _alignmentMask) & ~_alignmentMask
    }
    internal static func _roundingDownToAlignment(_ value: Int) -> Int {
        return value & ~_alignmentMask
    }
    
    internal static func _roundingUpToAlignment(_ value: UInt) -> UInt {
        return (value + UInt(bitPattern: _alignmentMask)) & ~UInt(bitPattern: _alignmentMask)
    }
    internal static func _roundingDownToAlignment(_ value: UInt) -> UInt {
        return value & ~UInt(bitPattern: _alignmentMask)
    }
    
    internal static func _roundingUpToAlignment(_ value: UnsafeRawPointer) -> UnsafeRawPointer {
        return UnsafeRawPointer(bitPattern:
                                    _roundingUpToAlignment(UInt(bitPattern: value))).unsafelyUnwrapped
    }
    internal static func _roundingDownToAlignment(_ value: UnsafeRawPointer) -> UnsafeRawPointer {
        return UnsafeRawPointer(bitPattern:
                                    _roundingDownToAlignment(UInt(bitPattern: value))).unsafelyUnwrapped
    }
    
    internal static func _roundingUpToAlignment(_ value: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(bitPattern:
                                        _roundingUpToAlignment(UInt(bitPattern: value))).unsafelyUnwrapped
    }
    internal static func _roundingDownToAlignment(_ value: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(bitPattern:
                                        _roundingDownToAlignment(UInt(bitPattern: value))).unsafelyUnwrapped
    }
    
    internal static func _roundingUpBaseToAlignment(_ value: UnsafeRawBufferPointer) -> UnsafeRawBufferPointer {
        let baseAddressBits = Int(bitPattern: value.baseAddress)
        var misalignment = baseAddressBits & _alignmentMask
        if misalignment != 0 {
            misalignment = _alignmentMask & -misalignment
            return UnsafeRawBufferPointer(
                start: UnsafeRawPointer(bitPattern: baseAddressBits + misalignment),
                count: value.count - misalignment)
        }
        return value
    }
    
    internal static func _roundingUpBaseToAlignment(_ value: UnsafeMutableRawBufferPointer) -> UnsafeMutableRawBufferPointer {
        let baseAddressBits = Int(bitPattern: value.baseAddress)
        var misalignment = baseAddressBits & _alignmentMask
        if misalignment != 0 {
            misalignment = _alignmentMask & -misalignment
            return UnsafeMutableRawBufferPointer(
                start: UnsafeMutableRawPointer(bitPattern: baseAddressBits + misalignment),
                count: value.count - misalignment)
        }
        return value
    }
}
