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
// 应该是, 这种将类型作为函数的的参数的使用方式, 都是这种使用方法.
// 函数作为 static 存在, 使用 <T> 中的类型作为参数. 那么作为一个函数来说, 除了参数列表传入的参数, 使用环境的 T, 也可以认为是参数的一部分.
public enum MemoryLayout<T> {
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
    
    /// Returns the offset of an inline stored property within a type's in-memory
    /// representation.
    ///
    /// You can use this method to find the distance in bytes that can be added
    /// to a pointer of type `T` to get a pointer to the property referenced by
    /// `key`. The offset is available only if the given key refers to inline,
    /// directly addressable storage within the in-memory representation of `T`.
    ///
    /// If the return value of this method is non-`nil`, then accessing the value
    /// by key path or by an offset pointer are equivalent. For example, for a
    /// variable `root` of type `T`, a key path `key` of type
    /// `WritableKeyPath<T, U>`, and a `value` of type `U`:
    ///
    ///     // Mutation through the key path
    ///     root[keyPath: key] = value
    ///
    ///     // Mutation through the offset pointer
    ///     withUnsafeMutableBytes(of: &root) { bytes in
    ///         let offset = MemoryLayout<T>.offset(of: key)!
    ///         let rawPointerToValue = bytes.baseAddress! + offset
    ///         let pointerToValue = rawPointerToValue.assumingMemoryBound(to: U.self)
    ///         pointerToValue.pointee = value
    ///     }
    ///
    /// A property has inline, directly addressable storage when it is a stored
    /// property for which no additional work is required to extract or set the
    /// value. Properties are not directly accessible if they trigger any
    /// `didSet` or `willSet` accessors, perform any representation changes such
    /// as bridging or closure reabstraction, or mask the value out of
    /// overlapping storage as for packed bitfields. In addition, because class
    /// instance properties are always stored out-of-line, their positions are
    /// not accessible using `offset(of:)`.
    ///
    /// For example, in the `ProductCategory` type defined here, only
    /// `\.updateCounter`, `\.identifier`, and `\.identifier.name` refer to
    /// properties with inline, directly addressable storage:
    ///
    ///     struct ProductCategory {
    ///         struct Identifier {
    ///             var name: String              // addressable
    ///         }
    ///
    ///         var identifier: Identifier        // addressable
    ///         var updateCounter: Int            // addressable
    ///         var products: [Product] {         // not addressable: didSet handler
    ///             didSet { updateCounter += 1 }
    ///         }
    ///         var productCount: Int {           // not addressable: computed property
    ///             return products.count
    ///         }
    ///     }
    ///
    /// When using `offset(of:)` with a type imported from a library, don't
    /// assume that future versions of the library will have the same behavior.
    /// If a property is converted from a stored property to a computed
    /// property, the result of `offset(of:)` changes to `nil`. That kind of
    /// conversion is nonbreaking in other contexts, but would trigger a runtime
    /// error if the result of `offset(of:)` is force-unwrapped.
    ///
    /// - Parameter key: A key path referring to storage that can be accessed
    ///   through a value of type `T`.
    /// - Returns: The offset in bytes from a pointer to a value of type `T` to a
    ///   pointer to the storage referenced by `key`, or `nil` if no such offset
    ///   is available for the storage referenced by `key`. If the value is
    ///   `nil`, it can be because `key` is computed, has observers, requires
    ///   reabstraction, or overlaps storage with other properties.
    @_transparent
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
