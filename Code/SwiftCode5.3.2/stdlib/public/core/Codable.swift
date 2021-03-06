// 和 NSCoding 很类似的协议, Swift 版本的序列化, 反序列化的实现.
public protocol Encodable {
    func encode(to encoder: Encoder) throws
}
public protocol Decodable {
    init(from decoder: Decoder) throws
}

public typealias Codable = Encodable & Decodable

//===----------------------------------------------------------------------===//
// CodingKey
//===----------------------------------------------------------------------===//

// 实际上, 序列化的时候, 主要就是使用了字符串和 Int, 这个类, 也就是对于这两个值的封装而已.
public protocol CodingKey: CustomStringConvertible,
                           CustomDebugStringConvertible {
    var stringValue: String { get }
    init?(stringValue: String)
    
    var intValue: Int? { get }
    init?(intValue: Int)
}

extension CodingKey {
    public var description: String {
        let intValue = self.intValue?.description ?? "nil"
        return "\(type(of: self))(stringValue: \"\(stringValue)\", intValue: \(intValue))"
    }
    public var debugDescription: String {
        return description
    }
}


// Swift 自带两个编码器，分别是 JSONEncoder 和 PropertyListEncoder (它们定义在 Foundation 中，而不是在标准库里.
/*
 let encoder = JSONEncoder()
 let jsonData = try encoder.encode(places) // 129 bytes let jsonString = String(decoding: jsonData, as: UTF8.self)
 */
// 序列化器

public protocol Encoder {
    /// The path of coding keys taken to get to this point in encoding.
    var codingPath: [CodingKey] { get }
    /// Any contextual information set by the user for encoding.
    var userInfo: [CodingUserInfoKey: Any] { get }
    
    /// You must use only one kind of top-level encoding container. This method
    /// must not be called after a call to `unkeyedContainer()` or after
    /// encoding a value through a call to `singleValueContainer()`
    // 对于一个对象来说, 它的顶级数据, 只能有一种序列化容器进行数据的归档操作.
    
    // → 键容器(KeyedContainer)用于编码键值对。可以把键容器想像为一个特殊的字典，这 是到目前为止，应用最普遍的容器。键容器内部使用的键是强类型的，这为我们提供了类型安全和自动补全的特性。
    // 编码器 最终会在写入目标格式 (比如 JSON) 时，将键转换为字符串 (或者数字)，不过这对开发 者来说是隐藏的。
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key>
    
    // → 无键容器(UnkeyedContainer)用于编码一系列值，但不需要对应的键，可以将它想像 成保存编码结果的数组。因为没有对应的键来确定某个值，所以对无键容器中的值进行 解码的时候，需要遵守和编码时同样的顺序。
    // 这个用的很少, 因为实际上, 这就是按照顺序进行归档解档. 也就是说, 按照 0-4个字节应该是 x, 5-8个字节 应该是 y 这种方式在进行编码, 属实是很难记忆和扩展.
    // 实际上, 完全可以使用 keyed 方式进行代替. 所以, 业务上的类, 还是应该使用 container 进行处理, 而标准库里面, Range, Geometry 这些值, 是使用了 unkeyedContainer, 反序列化的时候, 也是要完全按照序列化的顺序进行反序列化.
    func unkeyedContainer() -> UnkeyedEncodingContainer
    
    // → 单值容器对单一值进行编码。你可以用它来处理只由单个属性定义的那些类型。例如: Int 这样的原始类型，或以原始类型实现了 RawRepresentable 协议的枚举。
    func singleValueContainer() -> SingleValueEncodingContainer
}

/// A type that can decode values from a native format into in-memory
/// representations.
public protocol Decoder {
    /// The path of coding keys taken to get to this point in decoding.
    var codingPath: [CodingKey] { get }
    
    /// Any contextual information set by the user for decoding.
    var userInfo: [CodingUserInfoKey: Any] { get }
    
    /// Returns the data stored in this decoder as represented in a container
    /// keyed by the given key type.
    ///
    /// - parameter type: The key type to use for the container.
    /// - returns: A keyed decoding container view into this decoder.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is
    ///   not a keyed container.
    func container<Key>(
        keyedBy type: Key.Type
    ) throws -> KeyedDecodingContainer<Key>
    
    /// Returns the data stored in this decoder as represented in a container
    /// appropriate for holding values with no keys.
    ///
    /// - returns: An unkeyed container view into this decoder.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is
    ///   not an unkeyed container.
    func unkeyedContainer() throws -> UnkeyedDecodingContainer
    
    /// Returns the data stored in this decoder as represented in a container
    /// appropriate for holding a single primitive value.
    ///
    /// - returns: A single value container view into this decoder.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is
    ///   not a single value container.
    func singleValueContainer() throws -> SingleValueDecodingContainer
}

//===----------------------------------------------------------------------===//
// Keyed Encoding Containers
//===----------------------------------------------------------------------===//

// 键值编码的实现. 主要就是, 通过 key, 存储特定类型的值.
// 需要提供各个基本数据类型的归档过程, 然后复杂的数据类型, 直接可以通过基本数据类型进行组合.
public protocol KeyedEncodingContainerProtocol {
    associatedtype Key: CodingKey
    
    /// The path of coding keys taken to get to this point in encoding.
    var codingPath: [CodingKey] { get }
    
    // throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    
    // 所以, 实际上数据类型就几种.
    // 字符串, int 类簇, double 类簇, 值对象, 引用对象. 对象必须是 Encodable, 最终还是使用 Int, double 进行归档.
    // encodeConditional 是为了归档引用对象的. 猜测里面有着避免循环引用的策略处理.
    mutating func encodeNil(forKey key: Key) throws
    mutating func encode(_ value: Bool, forKey key: Key) throws
    mutating func encode(_ value: String, forKey key: Key) throws
    mutating func encode(_ value: Double, forKey key: Key) throws
    mutating func encode(_ value: Float, forKey key: Key) throws
    mutating func encode(_ value: Int, forKey key: Key) throws
    mutating func encode(_ value: Int8, forKey key: Key) throws
    mutating func encode(_ value: Int16, forKey key: Key) throws
    mutating func encode(_ value: Int32, forKey key: Key) throws
    mutating func encode(_ value: Int64, forKey key: Key) throws
    mutating func encode(_ value: UInt, forKey key: Key) throws
    mutating func encode(_ value: UInt8, forKey key: Key) throws
    mutating func encode(_ value: UInt16, forKey key: Key) throws
    mutating func encode(_ value: UInt32, forKey key: Key) throws
    mutating func encode(_ value: UInt64, forKey key: Key) throws
    
    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws
    
    mutating func encodeConditional<T: AnyObject & Encodable>(
        _ object: T,
        forKey key: Key
    ) throws
    
    // 以下是带有 Optinal 版本的序列化的过程.
    mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws
    mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws
    mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws
    mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws
    mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws
    mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws
    mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws
    mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws
    mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws
    mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws
    mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws
    mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws
    mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws
    mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws
    mutating func encodeIfPresent<T: Encodable>(
        _ value: T?,
        forKey key: Key
    ) throws
    
    /// Stores a keyed encoding container for the given key and returns it.
    ///
    /// - parameter keyType: The key type to use for the container.
    /// - parameter key: The key to encode the container for.
    /// - returns: A new keyed encoding container.
    mutating func nestedContainer<NestedKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey>
    
    /// Stores an unkeyed encoding container for the given key and returns it.
    ///
    /// - parameter key: The key to encode the container for.
    /// - returns: A new unkeyed encoding container.
    mutating func nestedUnkeyedContainer(
        forKey key: Key
    ) -> UnkeyedEncodingContainer
    
    /// Stores a new nested container for the default `super` key and returns a
    /// new encoder instance for encoding `super` into that container.
    ///
    /// Equivalent to calling `superEncoder(forKey:)` with
    /// `Key(stringValue: "super", intValue: 0)`.
    ///
    /// - returns: A new encoder to pass to `super.encode(to:)`.
    mutating func superEncoder() -> Encoder
    
    /// Stores a new nested container for the given key and returns a new encoder
    /// instance for encoding `super` into that container.
    ///
    /// - parameter key: The key to encode `super` for.
    /// - returns: A new encoder to pass to `super.encode(to:)`.
    mutating func superEncoder(forKey key: Key) -> Encoder
}

// KeyValue 归档的实现类. 实际上, 这个类啥都没干, 就是一层转发.
public struct KeyedEncodingContainer<K: CodingKey> :
    KeyedEncodingContainerProtocol
{
    public typealias Key = K
    internal var _box: _KeyedEncodingContainerBase
    
    // 真正的数据的记录
    public init<Container: KeyedEncodingContainerProtocol>(
        _ container: Container
    ) where Container.Key == Key {
        _box = _KeyedEncodingContainerBox(container)
    }
    
    // 下面, 所有的功能, 仅仅是一层对于 _box 的转发, 而 _box 里面, 又是转发到了 传递过来的 container
    public var codingPath: [CodingKey] {
        return _box.codingPath
    }
    
    public mutating func encodeNil(forKey key: Key) throws {
        try _box.encodeNil(forKey: key)
    }
    
    public mutating func encode(_ value: Bool, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }
    
    public mutating func encode(_ value: String, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }
    
    public mutating func encode(_ value: Double, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }
    
    public mutating func encode(_ value: Float, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }
    
    public mutating func encode(_ value: Int, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }
    
    public mutating func encode(_ value: Int8, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }
    
    public mutating func encode(_ value: Int16, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }
    
    public mutating func encode(_ value: Int32, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }
    
    public mutating func encode(_ value: Int64, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }
    
    public mutating func encode(_ value: UInt, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }
    
    public mutating func encode(_ value: UInt8, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }
    
    public mutating func encode(_ value: UInt16, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }
    
    public mutating func encode(_ value: UInt32, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }
    
    public mutating func encode(_ value: UInt64, forKey key: Key) throws {
        try _box.encode(value, forKey: key)
    }
    
    public mutating func encode<T: Encodable>(
        _ value: T,
        forKey key: Key
    ) throws {
        try _box.encode(value, forKey: key)
    }
    
    public mutating func encodeConditional<T: AnyObject & Encodable>(
        _ object: T,
        forKey key: Key
    ) throws {
        try _box.encodeConditional(object, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: Bool?,
        forKey key: Key
    ) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: String?,
        forKey key: Key
    ) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: Double?,
        forKey key: Key
    ) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: Float?,
        forKey key: Key
    ) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: Int?,
        forKey key: Key
    ) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: Int8?,
        forKey key: Key
    ) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: Int16?,
        forKey key: Key
    ) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: Int32?,
        forKey key: Key
    ) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: Int64?,
        forKey key: Key
    ) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: UInt?,
        forKey key: Key
    ) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: UInt8?,
        forKey key: Key
    ) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: UInt16?,
        forKey key: Key
    ) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: UInt32?,
        forKey key: Key
    ) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: UInt64?,
        forKey key: Key
    ) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }
    
    public mutating func encodeIfPresent<T: Encodable>(
        _ value: T?,
        forKey key: Key
    ) throws {
        try _box.encodeIfPresent(value, forKey: key)
    }
    
    public mutating func nestedContainer<NestedKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> {
        return _box.nestedContainer(keyedBy: NestedKey.self, forKey: key)
    }
    
    public mutating func nestedUnkeyedContainer(
        forKey key: Key
    ) -> UnkeyedEncodingContainer {
        return _box.nestedUnkeyedContainer(forKey: key)
    }
    
    public mutating func superEncoder() -> Encoder {
        return _box.superEncoder()
    }
    
    public mutating func superEncoder(forKey key: Key) -> Encoder {
        return _box.superEncoder(forKey: key)
    }
}

public protocol KeyedDecodingContainerProtocol {
    associatedtype Key: CodingKey
    
    /// The path of coding keys taken to get to this point in decoding.
    var codingPath: [CodingKey] { get }
    
    /// All the keys the `Decoder` has for this container.
    ///
    /// Different keyed containers from the same `Decoder` may return different
    /// keys here; it is possible to encode with multiple key types which are
    /// not convertible to one another. This should report all keys present
    /// which are convertible to the requested type.
    var allKeys: [Key] { get }
    
    /// Returns a Boolean value indicating whether the decoder contains a value
    /// associated with the given key.
    ///
    /// The value associated with `key` may be a null value as appropriate for
    /// the data format.
    ///
    /// - parameter key: The key to search for.
    /// - returns: Whether the `Decoder` has an entry for the given key.
    func contains(_ key: Key) -> Bool
    
    /// Decodes a null value for the given key.
    ///
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: Whether the encountered value was null.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    func decodeNil(forKey key: Key) throws -> Bool
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    func decode(_ type: String.Type, forKey key: Key) throws -> String
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool?
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String?
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double?
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float?
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int?
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8?
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16?
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32?
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64?
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt?
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8?
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16?
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32?
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64?
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    func decodeIfPresent<T: Decodable>(
        _ type: T.Type,
        forKey key: Key
    ) throws -> T?
    
    /// Returns the data stored for the given key as represented in a container
    /// keyed by the given key type.
    ///
    /// - parameter type: The key type to use for the container.
    /// - parameter key: The key that the nested container is associated with.
    /// - returns: A keyed decoding container view into `self`.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is
    ///   not a keyed container.
    func nestedContainer<NestedKey>(
        keyedBy type: NestedKey.Type,
        forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey>
    
    /// Returns the data stored for the given key as represented in an unkeyed
    /// container.
    ///
    /// - parameter key: The key that the nested container is associated with.
    /// - returns: An unkeyed decoding container view into `self`.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is
    ///   not an unkeyed container.
    func nestedUnkeyedContainer(
        forKey key: Key
    ) throws -> UnkeyedDecodingContainer
    
    /// Returns a `Decoder` instance for decoding `super` from the container
    /// associated with the default `super` key.
    ///
    /// Equivalent to calling `superDecoder(forKey:)` with
    /// `Key(stringValue: "super", intValue: 0)`.
    ///
    /// - returns: A new `Decoder` to pass to `super.init(from:)`.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the default `super` key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the default `super` key.
    func superDecoder() throws -> Decoder
    
    /// Returns a `Decoder` instance for decoding `super` from the container
    /// associated with the given key.
    ///
    /// - parameter key: The key to decode `super` for.
    /// - returns: A new `Decoder` to pass to `super.init(from:)`.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    func superDecoder(forKey key: Key) throws -> Decoder
}

// An implementation of _KeyedDecodingContainerBase and
// _KeyedDecodingContainerBox are given at the bottom of this file.

/// A concrete container that provides a view into a decoder's storage, making
/// the encoded properties of a decodable type accessible by keys.
public struct KeyedDecodingContainer<K: CodingKey> :
    KeyedDecodingContainerProtocol
{
    public typealias Key = K
    
    /// The container for the concrete decoder.
    internal var _box: _KeyedDecodingContainerBase
    
    /// Creates a new instance with the given container.
    ///
    /// - parameter container: The container to hold.
    public init<Container: KeyedDecodingContainerProtocol>(
        _ container: Container
    ) where Container.Key == Key {
        _box = _KeyedDecodingContainerBox(container)
    }
    
    /// The path of coding keys taken to get to this point in decoding.
    public var codingPath: [CodingKey] {
        return _box.codingPath
    }
    
    /// All the keys the decoder has for this container.
    ///
    /// Different keyed containers from the same decoder may return different
    /// keys here, because it is possible to encode with multiple key types
    /// which are not convertible to one another. This should report all keys
    /// present which are convertible to the requested type.
    public var allKeys: [Key] {
        return _box.allKeys as! [Key]
    }
    
    /// Returns a Boolean value indicating whether the decoder contains a value
    /// associated with the given key.
    ///
    /// The value associated with the given key may be a null value as
    /// appropriate for the data format.
    ///
    /// - parameter key: The key to search for.
    /// - returns: Whether the `Decoder` has an entry for the given key.
    public func contains(_ key: Key) -> Bool {
        return _box.contains(key)
    }
    
    /// Decodes a null value for the given key.
    ///
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: Whether the encountered value was null.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    public func decodeNil(forKey key: Key) throws -> Bool {
        return try _box.decodeNil(forKey: key)
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        return try _box.decode(Bool.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    public func decode(_ type: String.Type, forKey key: Key) throws -> String {
        return try _box.decode(String.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    public func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        return try _box.decode(Double.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    public func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        return try _box.decode(Float.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    public func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        return try _box.decode(Int.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        return try _box.decode(Int8.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        return try _box.decode(Int16.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        return try _box.decode(Int32.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        return try _box.decode(Int64.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        return try _box.decode(UInt.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    public func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        return try _box.decode(UInt8.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        return try _box.decode(UInt16.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        return try _box.decode(UInt32.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        return try _box.decode(UInt64.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    public func decode<T: Decodable>(
        _ type: T.Type,
        forKey key: Key
    ) throws -> T {
        return try _box.decode(T.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    public func decodeIfPresent(
        _ type: Bool.Type,
        forKey key: Key
    ) throws -> Bool? {
        return try _box.decodeIfPresent(Bool.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    public func decodeIfPresent(
        _ type: String.Type,
        forKey key: Key
    ) throws -> String? {
        return try _box.decodeIfPresent(String.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    public func decodeIfPresent(
        _ type: Double.Type,
        forKey key: Key
    ) throws -> Double? {
        return try _box.decodeIfPresent(Double.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    public func decodeIfPresent(
        _ type: Float.Type,
        forKey key: Key
    ) throws -> Float? {
        return try _box.decodeIfPresent(Float.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    public func decodeIfPresent(
        _ type: Int.Type,
        forKey key: Key
    ) throws -> Int? {
        return try _box.decodeIfPresent(Int.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    public func decodeIfPresent(
        _ type: Int8.Type,
        forKey key: Key
    ) throws -> Int8? {
        return try _box.decodeIfPresent(Int8.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    public func decodeIfPresent(
        _ type: Int16.Type,
        forKey key: Key
    ) throws -> Int16? {
        return try _box.decodeIfPresent(Int16.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    public func decodeIfPresent(
        _ type: Int32.Type,
        forKey key: Key
    ) throws -> Int32? {
        return try _box.decodeIfPresent(Int32.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    public func decodeIfPresent(
        _ type: Int64.Type,
        forKey key: Key
    ) throws -> Int64? {
        return try _box.decodeIfPresent(Int64.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    public func decodeIfPresent(
        _ type: UInt.Type,
        forKey key: Key
    ) throws -> UInt? {
        return try _box.decodeIfPresent(UInt.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    public func decodeIfPresent(
        _ type: UInt8.Type,
        forKey key: Key
    ) throws -> UInt8? {
        return try _box.decodeIfPresent(UInt8.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    public func decodeIfPresent(
        _ type: UInt16.Type,
        forKey key: Key
    ) throws -> UInt16? {
        return try _box.decodeIfPresent(UInt16.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    public func decodeIfPresent(
        _ type: UInt32.Type,
        forKey key: Key
    ) throws -> UInt32? {
        return try _box.decodeIfPresent(UInt32.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    public func decodeIfPresent(
        _ type: UInt64.Type,
        forKey key: Key
    ) throws -> UInt64? {
        return try _box.decodeIfPresent(UInt64.self, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    public func decodeIfPresent<T: Decodable>(
        _ type: T.Type,
        forKey key: Key
    ) throws -> T? {
        return try _box.decodeIfPresent(T.self, forKey: key)
    }
    
    /// Returns the data stored for the given key as represented in a container
    /// keyed by the given key type.
    ///
    /// - parameter type: The key type to use for the container.
    /// - parameter key: The key that the nested container is associated with.
    /// - returns: A keyed decoding container view into `self`.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is
    ///   not a keyed container.
    public func nestedContainer<NestedKey>(
        keyedBy type: NestedKey.Type,
        forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> {
        return try _box.nestedContainer(keyedBy: NestedKey.self, forKey: key)
    }
    
    /// Returns the data stored for the given key as represented in an unkeyed
    /// container.
    ///
    /// - parameter key: The key that the nested container is associated with.
    /// - returns: An unkeyed decoding container view into `self`.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is
    ///   not an unkeyed container.
    public func nestedUnkeyedContainer(
        forKey key: Key
    ) throws -> UnkeyedDecodingContainer {
        return try _box.nestedUnkeyedContainer(forKey: key)
    }
    
    /// Returns a `Decoder` instance for decoding `super` from the container
    /// associated with the default `super` key.
    ///
    /// Equivalent to calling `superDecoder(forKey:)` with
    /// `Key(stringValue: "super", intValue: 0)`.
    ///
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the default `super` key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the default `super` key.
    public func superDecoder() throws -> Decoder {
        return try _box.superDecoder()
    }
    
    /// Returns a `Decoder` instance for decoding `super` from the container
    /// associated with the given key.
    ///
    /// - parameter key: The key to decode `super` for.
    /// - returns: A new `Decoder` to pass to `super.init(from:)`.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    public func superDecoder(forKey key: Key) throws -> Decoder {
        return try _box.superDecoder(forKey: key)
    }
}

//===----------------------------------------------------------------------===//
// Unkeyed Encoding Containers
//===----------------------------------------------------------------------===//

// 按序进行序列的一种序列化类.
public protocol UnkeyedEncodingContainer {
    /// The path of coding keys taken to get to this point in encoding.
    var codingPath: [CodingKey] { get }
    
    /// The number of elements encoded into the container.
    var count: Int { get }
    
    /// Encodes a null value.
    ///
    /// - throws: `EncodingError.invalidValue` if a null value is invalid in the
    ///   current context for this format.
    mutating func encodeNil() throws
    
    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    mutating func encode(_ value: Bool) throws
    
    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    mutating func encode(_ value: String) throws
    
    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    mutating func encode(_ value: Double) throws
    
    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    mutating func encode(_ value: Float) throws
    
    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    mutating func encode(_ value: Int) throws
    
    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    mutating func encode(_ value: Int8) throws
    
    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    mutating func encode(_ value: Int16) throws
    
    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    mutating func encode(_ value: Int32) throws
    
    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    mutating func encode(_ value: Int64) throws
    
    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    mutating func encode(_ value: UInt) throws
    
    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    mutating func encode(_ value: UInt8) throws
    
    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    mutating func encode(_ value: UInt16) throws
    
    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    mutating func encode(_ value: UInt32) throws
    
    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    mutating func encode(_ value: UInt64) throws
    
    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    mutating func encode<T: Encodable>(_ value: T) throws
    
    /// Encodes a reference to the given object only if it is encoded
    /// unconditionally elsewhere in the payload (previously, or in the future).
    ///
    /// For encoders which don't support this feature, the default implementation
    /// encodes the given object unconditionally.
    ///
    /// For formats which don't support this feature, the default implementation
    /// encodes the given object unconditionally.
    ///
    /// - parameter object: The object to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    mutating func encodeConditional<T: AnyObject & Encodable>(_ object: T) throws
    
    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == Bool
    
    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == String
    
    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == Double
    
    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == Float
    
    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == Int
    
    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == Int8
    
    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == Int16
    
    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == Int32
    
    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == Int64
    
    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == UInt
    
    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == UInt8
    
    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == UInt16
    
    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == UInt32
    
    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == UInt64
    
    /// Encodes the elements of the given sequence.
    ///
    /// - parameter sequence: The sequences whose contents to encode.
    /// - throws: An error if any of the contained values throws an error.
    mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element: Encodable
    
    /// Encodes a nested container keyed by the given type and returns it.
    ///
    /// - parameter keyType: The key type to use for the container.
    /// - returns: A new keyed encoding container.
    mutating func nestedContainer<NestedKey>(
        keyedBy keyType: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey>
    
    /// Encodes an unkeyed encoding container and returns it.
    ///
    /// - returns: A new unkeyed encoding container.
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer
    
    /// Encodes a nested container and returns an `Encoder` instance for encoding
    /// `super` into that container.
    ///
    /// - returns: A new encoder to pass to `super.encode(to:)`.
    mutating func superEncoder() -> Encoder
}

/// A type that provides a view into a decoder's storage and is used to hold
/// the encoded properties of a decodable type sequentially, without keys.
///
/// Decoders should provide types conforming to `UnkeyedDecodingContainer` for
/// their format.
public protocol UnkeyedDecodingContainer {
    /// The path of coding keys taken to get to this point in decoding.
    var codingPath: [CodingKey] { get }
    
    /// The number of elements contained within this container.
    ///
    /// If the number of elements is unknown, the value is `nil`.
    var count: Int? { get }
    
    /// A Boolean value indicating whether there are no more elements left to be
    /// decoded in the container.
    var isAtEnd: Bool { get }
    
    /// The current decoding index of the container (i.e. the index of the next
    /// element to be decoded.) Incremented after every successful decode call.
    var currentIndex: Int { get }
    
    /// Decodes a null value.
    ///
    /// If the value is not null, does not increment currentIndex.
    ///
    /// - returns: Whether the encountered value was null.
    /// - throws: `DecodingError.valueNotFound` if there are no more values to
    ///   decode.
    mutating func decodeNil() throws -> Bool
    
    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null, or of there are no more values to decode.
    mutating func decode(_ type: Bool.Type) throws -> Bool
    
    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null, or of there are no more values to decode.
    mutating func decode(_ type: String.Type) throws -> String
    
    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null, or of there are no more values to decode.
    mutating func decode(_ type: Double.Type) throws -> Double
    
    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null, or of there are no more values to decode.
    mutating func decode(_ type: Float.Type) throws -> Float
    
    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null, or of there are no more values to decode.
    mutating func decode(_ type: Int.Type) throws -> Int
    
    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null, or of there are no more values to decode.
    mutating func decode(_ type: Int8.Type) throws -> Int8
    
    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null, or of there are no more values to decode.
    mutating func decode(_ type: Int16.Type) throws -> Int16
    
    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null, or of there are no more values to decode.
    mutating func decode(_ type: Int32.Type) throws -> Int32
    
    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null, or of there are no more values to decode.
    mutating func decode(_ type: Int64.Type) throws -> Int64
    
    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null, or of there are no more values to decode.
    mutating func decode(_ type: UInt.Type) throws -> UInt
    
    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null, or of there are no more values to decode.
    mutating func decode(_ type: UInt8.Type) throws -> UInt8
    
    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null, or of there are no more values to decode.
    mutating func decode(_ type: UInt16.Type) throws -> UInt16
    
    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null, or of there are no more values to decode.
    mutating func decode(_ type: UInt32.Type) throws -> UInt32
    
    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null, or of there are no more values to decode.
    mutating func decode(_ type: UInt64.Type) throws -> UInt64
    
    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null, or of there are no more values to decode.
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T
    
    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to
    /// decode, or if the value is null. The difference between these states can
    /// be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value
    ///   is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: Bool.Type) throws -> Bool?
    
    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to
    /// decode, or if the value is null. The difference between these states can
    /// be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value
    ///   is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: String.Type) throws -> String?
    
    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to
    /// decode, or if the value is null. The difference between these states can
    /// be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value
    ///   is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: Double.Type) throws -> Double?
    
    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to
    /// decode, or if the value is null. The difference between these states can
    /// be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value
    ///   is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: Float.Type) throws -> Float?
    
    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to
    /// decode, or if the value is null. The difference between these states can
    /// be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value
    ///   is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: Int.Type) throws -> Int?
    
    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to
    /// decode, or if the value is null. The difference between these states can
    /// be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value
    ///   is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: Int8.Type) throws -> Int8?
    
    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to
    /// decode, or if the value is null. The difference between these states can
    /// be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value
    ///   is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: Int16.Type) throws -> Int16?
    
    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to
    /// decode, or if the value is null. The difference between these states can
    /// be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value
    ///   is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: Int32.Type) throws -> Int32?
    
    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to
    /// decode, or if the value is null. The difference between these states can
    /// be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value
    ///   is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: Int64.Type) throws -> Int64?
    
    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to
    /// decode, or if the value is null. The difference between these states can
    /// be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value
    ///   is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: UInt.Type) throws -> UInt?
    
    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to
    /// decode, or if the value is null. The difference between these states can
    /// be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value
    ///   is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: UInt8.Type) throws -> UInt8?
    
    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to
    /// decode, or if the value is null. The difference between these states can
    /// be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value
    ///   is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: UInt16.Type) throws -> UInt16?
    
    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to
    /// decode, or if the value is null. The difference between these states can
    /// be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value
    ///   is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: UInt32.Type) throws -> UInt32?
    
    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to
    /// decode, or if the value is null. The difference between these states can
    /// be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value
    ///   is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    mutating func decodeIfPresent(_ type: UInt64.Type) throws -> UInt64?
    
    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to
    /// decode, or if the value is null. The difference between these states can
    /// be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value
    ///   is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    mutating func decodeIfPresent<T: Decodable>(_ type: T.Type) throws -> T?
    
    /// Decodes a nested container keyed by the given type.
    ///
    /// - parameter type: The key type to use for the container.
    /// - returns: A keyed decoding container view into `self`.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is
    ///   not a keyed container.
    mutating func nestedContainer<NestedKey>(
        keyedBy type: NestedKey.Type
    ) throws -> KeyedDecodingContainer<NestedKey>
    
    /// Decodes an unkeyed nested container.
    ///
    /// - returns: An unkeyed decoding container view into `self`.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is
    ///   not an unkeyed container.
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer
    
    /// Decodes a nested container and returns a `Decoder` instance for decoding
    /// `super` from that container.
    ///
    /// - returns: A new `Decoder` to pass to `super.init(from:)`.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null, or of there are no more values to decode.
    mutating func superDecoder() throws -> Decoder
}

// 如何, archive 单个值.
public protocol SingleValueEncodingContainer {
    /// The path of coding keys taken to get to this point in encoding.
    var codingPath: [CodingKey] { get }
    
    /// Encodes a null value.
    ///
    /// - throws: `EncodingError.invalidValue` if a null value is invalid in the
    ///   current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)`
    ///   call.
    mutating func encodeNil() throws
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)`
    ///   call.
    mutating func encode(_ value: Bool) throws
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)`
    ///   call.
    mutating func encode(_ value: String) throws
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)`
    ///   call.
    mutating func encode(_ value: Double) throws
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)`
    ///   call.
    mutating func encode(_ value: Float) throws
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)`
    ///   call.
    mutating func encode(_ value: Int) throws
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)`
    ///   call.
    mutating func encode(_ value: Int8) throws
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)`
    ///   call.
    mutating func encode(_ value: Int16) throws
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)`
    ///   call.
    mutating func encode(_ value: Int32) throws
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)`
    ///   call.
    mutating func encode(_ value: Int64) throws
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)`
    ///   call.
    mutating func encode(_ value: UInt) throws
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)`
    ///   call.
    mutating func encode(_ value: UInt8) throws
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)`
    ///   call.
    mutating func encode(_ value: UInt16) throws
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)`
    ///   call.
    mutating func encode(_ value: UInt32) throws
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)`
    ///   call.
    mutating func encode(_ value: UInt64) throws
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)`
    ///   call.
    mutating func encode<T: Encodable>(_ value: T) throws
}

/// A container that can support the storage and direct decoding of a single
/// nonkeyed value.
public protocol SingleValueDecodingContainer {
    /// The path of coding keys taken to get to this point in encoding.
    var codingPath: [CodingKey] { get }
    
    /// Decodes a null value.
    ///
    /// - returns: Whether the encountered value was null.
    func decodeNil() -> Bool
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null.
    func decode(_ type: Bool.Type) throws -> Bool
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null.
    func decode(_ type: String.Type) throws -> String
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null.
    func decode(_ type: Double.Type) throws -> Double
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null.
    func decode(_ type: Float.Type) throws -> Float
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null.
    func decode(_ type: Int.Type) throws -> Int
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null.
    func decode(_ type: Int8.Type) throws -> Int8
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null.
    func decode(_ type: Int16.Type) throws -> Int16
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null.
    func decode(_ type: Int32.Type) throws -> Int32
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null.
    func decode(_ type: Int64.Type) throws -> Int64
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null.
    func decode(_ type: UInt.Type) throws -> UInt
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null.
    func decode(_ type: UInt8.Type) throws -> UInt8
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null.
    func decode(_ type: UInt16.Type) throws -> UInt16
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null.
    func decode(_ type: UInt32.Type) throws -> UInt32
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null.
    func decode(_ type: UInt64.Type) throws -> UInt64
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null.
    func decode<T: Decodable>(_ type: T.Type) throws -> T
}

//===----------------------------------------------------------------------===//
// User Info
//===----------------------------------------------------------------------===//

/// A user-defined key for providing context during encoding and decoding.
public struct CodingUserInfoKey: RawRepresentable, Equatable, Hashable {
    public typealias RawValue = String
    
    /// The key's string value.
    public let rawValue: String
    
    /// Creates a new instance with the given raw value.
    ///
    /// - parameter rawValue: The value of the key.
    public init?(rawValue: String) {
        self.rawValue = rawValue
    }
    
    /// Returns a Boolean value indicating whether the given keys are equal.
    ///
    /// - parameter lhs: The key to compare against.
    /// - parameter rhs: The key to compare with.
    public static func ==(
        lhs: CodingUserInfoKey,
        rhs: CodingUserInfoKey
    ) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    
    /// The key's hash value.
    public var hashValue: Int {
        return self.rawValue.hashValue
    }
    
    /// Hashes the essential components of this value by feeding them into the
    /// given hasher.
    ///
    /// - Parameter hasher: The hasher to use when combining the components
    ///   of this instance.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.rawValue)
    }
}

//===----------------------------------------------------------------------===//
// Errors
//===----------------------------------------------------------------------===//

/// An error that occurs during the encoding of a value.
public enum EncodingError: Error {
    /// The context in which the error occurred.
    public struct Context {
        /// The path of coding keys taken to get to the point of the failing encode
        /// call.
        public let codingPath: [CodingKey]
        
        /// A description of what went wrong, for debugging purposes.
        public let debugDescription: String
        
        /// The underlying error which caused this error, if any.
        public let underlyingError: Error?
        
        /// Creates a new context with the given path of coding keys and a
        /// description of what went wrong.
        ///
        /// - parameter codingPath: The path of coding keys taken to get to the
        ///   point of the failing encode call.
        /// - parameter debugDescription: A description of what went wrong, for
        ///   debugging purposes.
        /// - parameter underlyingError: The underlying error which caused this
        ///   error, if any.
        public init(
            codingPath: [CodingKey],
            debugDescription: String,
            underlyingError: Error? = nil
        ) {
            self.codingPath = codingPath
            self.debugDescription = debugDescription
            self.underlyingError = underlyingError
        }
    }
    
    /// An indication that an encoder or its containers could not encode the
    /// given value.
    ///
    /// As associated values, this case contains the attempted value and context
    /// for debugging.
    case invalidValue(Any, Context)
    
    // MARK: - NSError Bridging
    
    // CustomNSError bridging applies only when the CustomNSError conformance is
    // applied in the same module as the declared error type. Since we cannot
    // access CustomNSError (which is defined in Foundation) from here, we can
    // use the "hidden" entry points.
    
    public var _domain: String {
        return "NSCocoaErrorDomain"
    }
    
    public var _code: Int {
        switch self {
        case .invalidValue: return 4866
        }
    }
    
    public var _userInfo: AnyObject? {
        // The error dictionary must be returned as an AnyObject. We can do this
        // only on platforms with bridging, unfortunately.
        #if _runtime(_ObjC)
        let context: Context
        switch self {
        case .invalidValue(_, let c): context = c
        }
        
        var userInfo: [String: Any] = [
            "NSCodingPath": context.codingPath,
            "NSDebugDescription": context.debugDescription
        ]
        
        if let underlyingError = context.underlyingError {
            userInfo["NSUnderlyingError"] = underlyingError
        }
        
        return userInfo as AnyObject
        #else
        return nil
        #endif
    }
}

/// An error that occurs during the decoding of a value.
public enum DecodingError: Error {
    /// The context in which the error occurred.
    public struct Context {
        /// The path of coding keys taken to get to the point of the failing decode
        /// call.
        public let codingPath: [CodingKey]
        
        /// A description of what went wrong, for debugging purposes.
        public let debugDescription: String
        
        /// The underlying error which caused this error, if any.
        public let underlyingError: Error?
        
        /// Creates a new context with the given path of coding keys and a
        /// description of what went wrong.
        ///
        /// - parameter codingPath: The path of coding keys taken to get to the
        ///   point of the failing decode call.
        /// - parameter debugDescription: A description of what went wrong, for
        ///   debugging purposes.
        /// - parameter underlyingError: The underlying error which caused this
        ///   error, if any.
        public init(
            codingPath: [CodingKey],
            debugDescription: String,
            underlyingError: Error? = nil
        ) {
            self.codingPath = codingPath
            self.debugDescription = debugDescription
            self.underlyingError = underlyingError
        }
    }
    
    /// An indication that a value of the given type could not be decoded because
    /// it did not match the type of what was found in the encoded payload.
    ///
    /// As associated values, this case contains the attempted type and context
    /// for debugging.
    case typeMismatch(Any.Type, Context)
    
    /// An indication that a non-optional value of the given type was expected,
    /// but a null value was found.
    ///
    /// As associated values, this case contains the attempted type and context
    /// for debugging.
    case valueNotFound(Any.Type, Context)
    
    ///  An indication that a keyed decoding container was asked for an entry for
    ///  the given key, but did not contain one.
    ///
    /// As associated values, this case contains the attempted key and context
    /// for debugging.
    case keyNotFound(CodingKey, Context)
    
    /// An indication that the data is corrupted or otherwise invalid.
    ///
    /// As an associated value, this case contains the context for debugging.
    case dataCorrupted(Context)
    
    // MARK: - NSError Bridging
    
    // CustomNSError bridging applies only when the CustomNSError conformance is
    // applied in the same module as the declared error type. Since we cannot
    // access CustomNSError (which is defined in Foundation) from here, we can
    // use the "hidden" entry points.
    
    public var _domain: String {
        return "NSCocoaErrorDomain"
    }
    
    public var _code: Int {
        switch self {
        case .keyNotFound, .valueNotFound: return 4865
        case .typeMismatch, .dataCorrupted:  return 4864
        }
    }
    
    public var _userInfo: AnyObject? {
        // The error dictionary must be returned as an AnyObject. We can do this
        // only on platforms with bridging, unfortunately.
        #if _runtime(_ObjC)
        let context: Context
        switch self {
        case .keyNotFound(_,   let c): context = c
        case .valueNotFound(_, let c): context = c
        case .typeMismatch(_,  let c): context = c
        case .dataCorrupted(   let c): context = c
        }
        
        var userInfo: [String: Any] = [
            "NSCodingPath": context.codingPath,
            "NSDebugDescription": context.debugDescription
        ]
        
        if let underlyingError = context.underlyingError {
            userInfo["NSUnderlyingError"] = underlyingError
        }
        
        return userInfo as AnyObject
        #else
        return nil
        #endif
    }
}

// The following extensions allow for easier error construction.

internal struct _GenericIndexKey: CodingKey {
    internal var stringValue: String
    internal var intValue: Int?
    
    internal init?(stringValue: String) {
        return nil
    }
    
    internal init?(intValue: Int) {
        self.stringValue = "Index \(intValue)"
        self.intValue = intValue
    }
}

extension DecodingError {
    /// Returns a new `.dataCorrupted` error using a constructed coding path and
    /// the given debug description.
    ///
    /// The coding path for the returned error is constructed by appending the
    /// given key to the given container's coding path.
    ///
    /// - param key: The key which caused the failure.
    /// - param container: The container in which the corrupted data was
    ///   accessed.
    /// - param debugDescription: A description of the error to aid in debugging.
    ///
    /// - Returns: A new `.dataCorrupted` error with the given information.
    public static func dataCorruptedError<C: KeyedDecodingContainerProtocol>(
        forKey key: C.Key,
        in container: C,
        debugDescription: String
    ) -> DecodingError {
        let context = DecodingError.Context(
            codingPath: container.codingPath + [key],
            debugDescription: debugDescription)
        return .dataCorrupted(context)
    }
    
    /// Returns a new `.dataCorrupted` error using a constructed coding path and
    /// the given debug description.
    ///
    /// The coding path for the returned error is constructed by appending the
    /// given container's current index to its coding path.
    ///
    /// - param container: The container in which the corrupted data was
    ///   accessed.
    /// - param debugDescription: A description of the error to aid in debugging.
    ///
    /// - Returns: A new `.dataCorrupted` error with the given information.
    public static func dataCorruptedError(
        in container: UnkeyedDecodingContainer,
        debugDescription: String
    ) -> DecodingError {
        let context = DecodingError.Context(
            codingPath: container.codingPath +
                [_GenericIndexKey(intValue: container.currentIndex)!],
            debugDescription: debugDescription)
        return .dataCorrupted(context)
    }
    
    /// Returns a new `.dataCorrupted` error using a constructed coding path and
    /// the given debug description.
    ///
    /// The coding path for the returned error is the given container's coding
    /// path.
    ///
    /// - param container: The container in which the corrupted data was
    ///   accessed.
    /// - param debugDescription: A description of the error to aid in debugging.
    ///
    /// - Returns: A new `.dataCorrupted` error with the given information.
    public static func dataCorruptedError(
        in container: SingleValueDecodingContainer,
        debugDescription: String
    ) -> DecodingError {
        let context = DecodingError.Context(codingPath: container.codingPath,
                                            debugDescription: debugDescription)
        return .dataCorrupted(context)
    }
}


// 个人感觉是无意义的一个父类.
// 这个父类, 并没有实现任何协议, 但是协议里面的内容, 是需要这个类的功能实现的.
internal class _KeyedEncodingContainerBase {
    internal init(){}
    
    deinit {}
    
    // These must all be given a concrete implementation in _*Box.
    internal var codingPath: [CodingKey] {
        fatalError(" cannot be used directly.")
    }
    
    internal func encodeNil<K: CodingKey>(forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encode<K: CodingKey>(_ value: Bool, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encode<K: CodingKey>(_ value: String, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encode<K: CodingKey>(_ value: Double, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encode<K: CodingKey>(_ value: Float, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encode<K: CodingKey>(_ value: Int, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encode<K: CodingKey>(_ value: Int8, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encode<K: CodingKey>(_ value: Int16, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encode<K: CodingKey>(_ value: Int32, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encode<K: CodingKey>(_ value: Int64, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encode<K: CodingKey>(_ value: UInt, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encode<K: CodingKey>(_ value: UInt8, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encode<K: CodingKey>(_ value: UInt16, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encode<K: CodingKey>(_ value: UInt32, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encode<K: CodingKey>(_ value: UInt64, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encode<T: Encodable, K: CodingKey>(_ value: T, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encodeConditional<T: AnyObject & Encodable, K: CodingKey>(
        _ object: T,
        forKey key: K
    ) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encodeIfPresent<K: CodingKey>(_ value: Bool?, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encodeIfPresent<K: CodingKey>(_ value: String?, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encodeIfPresent<K: CodingKey>(_ value: Double?, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encodeIfPresent<K: CodingKey>(_ value: Float?, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encodeIfPresent<K: CodingKey>(_ value: Int?, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encodeIfPresent<K: CodingKey>(_ value: Int8?, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encodeIfPresent<K: CodingKey>(_ value: Int16?, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encodeIfPresent<K: CodingKey>(_ value: Int32?, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encodeIfPresent<K: CodingKey>(_ value: Int64?, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encodeIfPresent<K: CodingKey>(_ value: UInt?, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encodeIfPresent<K: CodingKey>(_ value: UInt8?, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encodeIfPresent<K: CodingKey>(_ value: UInt16?, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encodeIfPresent<K: CodingKey>(_ value: UInt32?, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encodeIfPresent<K: CodingKey>(_ value: UInt64?, forKey key: K) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func encodeIfPresent<T: Encodable, K: CodingKey>(
        _ value: T?,
        forKey key: K
    ) throws {
        fatalError(" cannot be used directly.")
    }
    
    internal func nestedContainer<NestedKey, K: CodingKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: K
    ) -> KeyedEncodingContainer<NestedKey> {
        fatalError(" cannot be used directly.")
    }
    
    internal func nestedUnkeyedContainer<K: CodingKey>(
        forKey key: K
    ) -> UnkeyedEncodingContainer {
        fatalError(" cannot be used directly.")
    }
    
    internal func superEncoder() -> Encoder {
        fatalError(" cannot be used directly.")
    }
    
    internal func superEncoder<K: CodingKey>(forKey key: K) -> Encoder {
        fatalError(" cannot be used directly.")
    }
}

// Box 的意思是, 里面有一个 base 值, 做真正的相关功能的实现, 本类, 仅仅是一层封装.
internal final class _KeyedEncodingContainerBox<
    Concrete: KeyedEncodingContainerProtocol
>: _KeyedEncodingContainerBase {
    
    typealias Key = Concrete.Key
    internal var concrete: Concrete // 实际的数据, 这个数据本身, 实现了 KeyedEncodingContainerProtocol 协议.
    
    internal init(_ container: Concrete) {
        concrete = container
    }
    
    // 所有的, 对于父类方法的 override, 都是根据 concrete 存储的值实现的.
    override internal var codingPath: [CodingKey] {
        return concrete.codingPath
    }
    
    // unsafeBitCast 这个函数, 类似于 interprement_cast
    override internal func encodeNil<K: CodingKey>(forKey key: K) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encodeNil(forKey: key)
    }
    
    override internal func encode<K: CodingKey>(_ value: Bool, forKey key: K) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encode(value, forKey: key)
    }
    
    override internal func encode<K: CodingKey>(_ value: String, forKey key: K) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encode(value, forKey: key)
    }
    
    override internal func encode<K: CodingKey>(_ value: Double, forKey key: K) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encode(value, forKey: key)
    }
    
    override internal func encode<K: CodingKey>(_ value: Float, forKey key: K) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encode(value, forKey: key)
    }
    
    override internal func encode<K: CodingKey>(_ value: Int, forKey key: K) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encode(value, forKey: key)
    }
    
    override internal func encode<K: CodingKey>(_ value: Int8, forKey key: K) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encode(value, forKey: key)
    }
    
    override internal func encode<K: CodingKey>(_ value: Int16, forKey key: K) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encode(value, forKey: key)
    }
    
    override internal func encode<K: CodingKey>(_ value: Int32, forKey key: K) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encode(value, forKey: key)
    }
    
    override internal func encode<K: CodingKey>(_ value: Int64, forKey key: K) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encode(value, forKey: key)
    }
    
    override internal func encode<K: CodingKey>(_ value: UInt, forKey key: K) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encode(value, forKey: key)
    }
    
    override internal func encode<K: CodingKey>(_ value: UInt8, forKey key: K) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encode(value, forKey: key)
    }
    
    override internal func encode<K: CodingKey>(_ value: UInt16, forKey key: K) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encode(value, forKey: key)
    }
    
    override internal func encode<K: CodingKey>(_ value: UInt32, forKey key: K) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encode(value, forKey: key)
    }
    
    override internal func encode<K: CodingKey>(_ value: UInt64, forKey key: K) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encode(value, forKey: key)
    }
    
    override internal func encode<T: Encodable, K: CodingKey>(
        _ value: T,
        forKey key: K
    ) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encode(value, forKey: key)
    }
    
    override internal func encodeConditional<T: AnyObject & Encodable, K: CodingKey>(
        _ object: T,
        forKey key: K
    ) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encodeConditional(object, forKey: key)
    }
    
    override internal func encodeIfPresent<K: CodingKey>(
        _ value: Bool?,
        forKey key: K
    ) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encodeIfPresent(value, forKey: key)
    }
    
    override internal func encodeIfPresent<K: CodingKey>(
        _ value: String?,
        forKey key: K
    ) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encodeIfPresent(value, forKey: key)
    }
    
    override internal func encodeIfPresent<K: CodingKey>(
        _ value: Double?,
        forKey key: K
    ) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encodeIfPresent(value, forKey: key)
    }
    
    override internal func encodeIfPresent<K: CodingKey>(
        _ value: Float?,
        forKey key: K
    ) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encodeIfPresent(value, forKey: key)
    }
    
    override internal func encodeIfPresent<K: CodingKey>(
        _ value: Int?,
        forKey key: K
    ) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encodeIfPresent(value, forKey: key)
    }
    
    override internal func encodeIfPresent<K: CodingKey>(
        _ value: Int8?,
        forKey key: K
    ) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encodeIfPresent(value, forKey: key)
    }
    
    override internal func encodeIfPresent<K: CodingKey>(
        _ value: Int16?,
        forKey key: K
    ) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encodeIfPresent(value, forKey: key)
    }
    
    override internal func encodeIfPresent<K: CodingKey>(
        _ value: Int32?,
        forKey key: K
    ) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encodeIfPresent(value, forKey: key)
    }
    
    override internal func encodeIfPresent<K: CodingKey>(
        _ value: Int64?,
        forKey key: K
    ) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encodeIfPresent(value, forKey: key)
    }
    
    override internal func encodeIfPresent<K: CodingKey>(
        _ value: UInt?,
        forKey key: K
    ) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encodeIfPresent(value, forKey: key)
    }
    
    override internal func encodeIfPresent<K: CodingKey>(
        _ value: UInt8?,
        forKey key: K
    ) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encodeIfPresent(value, forKey: key)
    }
    
    override internal func encodeIfPresent<K: CodingKey>(
        _ value: UInt16?,
        forKey key: K
    ) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encodeIfPresent(value, forKey: key)
    }
    
    override internal func encodeIfPresent<K: CodingKey>(
        _ value: UInt32?,
        forKey key: K
    ) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encodeIfPresent(value, forKey: key)
    }
    
    override internal func encodeIfPresent<K: CodingKey>(
        _ value: UInt64?,
        forKey key: K
    ) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encodeIfPresent(value, forKey: key)
    }
    
    override internal func encodeIfPresent<T: Encodable, K: CodingKey>(
        _ value: T?,
        forKey key: K
    ) throws {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        try concrete.encodeIfPresent(value, forKey: key)
    }
    
    override internal func nestedContainer<NestedKey, K: CodingKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: K
    ) -> KeyedEncodingContainer<NestedKey> {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return concrete.nestedContainer(keyedBy: NestedKey.self, forKey: key)
    }
    
    override internal func nestedUnkeyedContainer<K: CodingKey>(
        forKey key: K
    ) -> UnkeyedEncodingContainer {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return concrete.nestedUnkeyedContainer(forKey: key)
    }
    
    override internal func superEncoder() -> Encoder {
        return concrete.superEncoder()
    }
    
    override internal func superEncoder<K: CodingKey>(forKey key: K) -> Encoder {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return concrete.superEncoder(forKey: key)
    }
}

internal class _KeyedDecodingContainerBase {
    internal init(){}
    
    deinit {}
    
    internal var codingPath: [CodingKey] {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal var allKeys: [CodingKey] {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func contains<K: CodingKey>(_ key: K) -> Bool {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decodeNil<K: CodingKey>(forKey key: K) throws -> Bool {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decode<K: CodingKey>(
        _ type: Bool.Type,
        forKey key: K
    ) throws -> Bool {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decode<K: CodingKey>(
        _ type: String.Type,
        forKey key: K
    ) throws -> String {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decode<K: CodingKey>(
        _ type: Double.Type,
        forKey key: K
    ) throws -> Double {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decode<K: CodingKey>(
        _ type: Float.Type,
        forKey key: K
    ) throws -> Float {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decode<K: CodingKey>(
        _ type: Int.Type,
        forKey key: K
    ) throws -> Int {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decode<K: CodingKey>(
        _ type: Int8.Type,
        forKey key: K
    ) throws -> Int8 {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decode<K: CodingKey>(
        _ type: Int16.Type,
        forKey key: K
    ) throws -> Int16 {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decode<K: CodingKey>(
        _ type: Int32.Type,
        forKey key: K
    ) throws -> Int32 {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decode<K: CodingKey>(
        _ type: Int64.Type,
        forKey key: K
    ) throws -> Int64 {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decode<K: CodingKey>(
        _ type: UInt.Type,
        forKey key: K
    ) throws -> UInt {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decode<K: CodingKey>(
        _ type: UInt8.Type,
        forKey key: K
    ) throws -> UInt8 {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decode<K: CodingKey>(
        _ type: UInt16.Type,
        forKey key: K
    ) throws -> UInt16 {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decode<K: CodingKey>(
        _ type: UInt32.Type,
        forKey key: K
    ) throws -> UInt32 {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decode<K: CodingKey>(
        _ type: UInt64.Type,
        forKey key: K
    ) throws -> UInt64 {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decode<T: Decodable, K: CodingKey>(
        _ type: T.Type,
        forKey key: K
    ) throws -> T {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decodeIfPresent<K: CodingKey>(
        _ type: Bool.Type,
        forKey key: K
    ) throws -> Bool? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decodeIfPresent<K: CodingKey>(
        _ type: String.Type,
        forKey key: K
    ) throws -> String? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decodeIfPresent<K: CodingKey>(
        _ type: Double.Type,
        forKey key: K
    ) throws -> Double? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decodeIfPresent<K: CodingKey>(
        _ type: Float.Type,
        forKey key: K
    ) throws -> Float? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decodeIfPresent<K: CodingKey>(
        _ type: Int.Type,
        forKey key: K
    ) throws -> Int? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decodeIfPresent<K: CodingKey>(
        _ type: Int8.Type,
        forKey key: K
    ) throws -> Int8? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decodeIfPresent<K: CodingKey>(
        _ type: Int16.Type,
        forKey key: K
    ) throws -> Int16? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decodeIfPresent<K: CodingKey>(
        _ type: Int32.Type,
        forKey key: K
    ) throws -> Int32? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decodeIfPresent<K: CodingKey>(
        _ type: Int64.Type,
        forKey key: K
    ) throws -> Int64? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decodeIfPresent<K: CodingKey>(
        _ type: UInt.Type,
        forKey key: K
    ) throws -> UInt? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decodeIfPresent<K: CodingKey>(
        _ type: UInt8.Type,
        forKey key: K
    ) throws -> UInt8? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decodeIfPresent<K: CodingKey>(
        _ type: UInt16.Type,
        forKey key: K
    ) throws -> UInt16? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decodeIfPresent<K: CodingKey>(
        _ type: UInt32.Type,
        forKey key: K
    ) throws -> UInt32? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decodeIfPresent<K: CodingKey>(
        _ type: UInt64.Type,
        forKey key: K
    ) throws -> UInt64? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func decodeIfPresent<T: Decodable, K: CodingKey>(
        _ type: T.Type,
        forKey key: K
    ) throws -> T? {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func nestedContainer<NestedKey, K: CodingKey>(
        keyedBy type: NestedKey.Type,
        forKey key: K
    ) throws -> KeyedDecodingContainer<NestedKey> {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func nestedUnkeyedContainer<K: CodingKey>(
        forKey key: K
    ) throws -> UnkeyedDecodingContainer {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func superDecoder() throws -> Decoder {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
    
    internal func superDecoder<K: CodingKey>(forKey key: K) throws -> Decoder {
        fatalError("_KeyedDecodingContainerBase cannot be used directly.")
    }
}

internal final class _KeyedDecodingContainerBox<
    Concrete: KeyedDecodingContainerProtocol
>: _KeyedDecodingContainerBase {
    typealias Key = Concrete.Key
    
    internal var concrete: Concrete
    
    internal init(_ container: Concrete) {
        concrete = container
    }
    
    override var codingPath: [CodingKey] {
        return concrete.codingPath
    }
    
    override var allKeys: [CodingKey] {
        return concrete.allKeys
    }
    
    override internal func contains<K: CodingKey>(_ key: K) -> Bool {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return concrete.contains(key)
    }
    
    override internal func decodeNil<K: CodingKey>(forKey key: K) throws -> Bool {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decodeNil(forKey: key)
    }
    
    override internal func decode<K: CodingKey>(
        _ type: Bool.Type,
        forKey key: K
    ) throws -> Bool {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decode(Bool.self, forKey: key)
    }
    
    override internal func decode<K: CodingKey>(
        _ type: String.Type,
        forKey key: K
    ) throws -> String {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decode(String.self, forKey: key)
    }
    
    override internal func decode<K: CodingKey>(
        _ type: Double.Type,
        forKey key: K
    ) throws -> Double {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decode(Double.self, forKey: key)
    }
    
    override internal func decode<K: CodingKey>(
        _ type: Float.Type,
        forKey key: K
    ) throws -> Float {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decode(Float.self, forKey: key)
    }
    
    override internal func decode<K: CodingKey>(
        _ type: Int.Type,
        forKey key: K
    ) throws -> Int {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decode(Int.self, forKey: key)
    }
    
    override internal func decode<K: CodingKey>(
        _ type: Int8.Type,
        forKey key: K
    ) throws -> Int8 {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decode(Int8.self, forKey: key)
    }
    
    override internal func decode<K: CodingKey>(
        _ type: Int16.Type,
        forKey key: K
    ) throws -> Int16 {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decode(Int16.self, forKey: key)
    }
    
    override internal func decode<K: CodingKey>(
        _ type: Int32.Type,
        forKey key: K
    ) throws -> Int32 {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decode(Int32.self, forKey: key)
    }
    
    override internal func decode<K: CodingKey>(
        _ type: Int64.Type,
        forKey key: K
    ) throws -> Int64 {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decode(Int64.self, forKey: key)
    }
    
    override internal func decode<K: CodingKey>(
        _ type: UInt.Type,
        forKey key: K
    ) throws -> UInt {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decode(UInt.self, forKey: key)
    }
    
    override internal func decode<K: CodingKey>(
        _ type: UInt8.Type,
        forKey key: K
    ) throws -> UInt8 {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decode(UInt8.self, forKey: key)
    }
    
    override internal func decode<K: CodingKey>(
        _ type: UInt16.Type,
        forKey key: K
    ) throws -> UInt16 {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decode(UInt16.self, forKey: key)
    }
    
    override internal func decode<K: CodingKey>(
        _ type: UInt32.Type,
        forKey key: K
    ) throws -> UInt32 {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decode(UInt32.self, forKey: key)
    }
    
    override internal func decode<K: CodingKey>(
        _ type: UInt64.Type,
        forKey key: K
    ) throws -> UInt64 {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decode(UInt64.self, forKey: key)
    }
    
    override internal func decode<T: Decodable, K: CodingKey>(
        _ type: T.Type,
        forKey key: K
    ) throws -> T {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decode(T.self, forKey: key)
    }
    
    override internal func decodeIfPresent<K: CodingKey>(
        _ type: Bool.Type,
        forKey key: K
    ) throws -> Bool? {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decodeIfPresent(Bool.self, forKey: key)
    }
    
    override internal func decodeIfPresent<K: CodingKey>(
        _ type: String.Type,
        forKey key: K
    ) throws -> String? {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decodeIfPresent(String.self, forKey: key)
    }
    
    override internal func decodeIfPresent<K: CodingKey>(
        _ type: Double.Type,
        forKey key: K
    ) throws -> Double? {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decodeIfPresent(Double.self, forKey: key)
    }
    
    override internal func decodeIfPresent<K: CodingKey>(
        _ type: Float.Type,
        forKey key: K
    ) throws -> Float? {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decodeIfPresent(Float.self, forKey: key)
    }
    
    override internal func decodeIfPresent<K: CodingKey>(
        _ type: Int.Type,
        forKey key: K
    ) throws -> Int? {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decodeIfPresent(Int.self, forKey: key)
    }
    
    override internal func decodeIfPresent<K: CodingKey>(
        _ type: Int8.Type,
        forKey key: K
    ) throws -> Int8? {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decodeIfPresent(Int8.self, forKey: key)
    }
    
    override internal func decodeIfPresent<K: CodingKey>(
        _ type: Int16.Type,
        forKey key: K
    ) throws -> Int16? {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decodeIfPresent(Int16.self, forKey: key)
    }
    
    override internal func decodeIfPresent<K: CodingKey>(
        _ type: Int32.Type,
        forKey key: K
    ) throws -> Int32? {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decodeIfPresent(Int32.self, forKey: key)
    }
    
    override internal func decodeIfPresent<K: CodingKey>(
        _ type: Int64.Type,
        forKey key: K
    ) throws -> Int64? {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decodeIfPresent(Int64.self, forKey: key)
    }
    
    override internal func decodeIfPresent<K: CodingKey>(
        _ type: UInt.Type,
        forKey key: K
    ) throws -> UInt? {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decodeIfPresent(UInt.self, forKey: key)
    }
    
    override internal func decodeIfPresent<K: CodingKey>(
        _ type: UInt8.Type,
        forKey key: K
    ) throws -> UInt8? {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decodeIfPresent(UInt8.self, forKey: key)
    }
    
    override internal func decodeIfPresent<K: CodingKey>(
        _ type: UInt16.Type,
        forKey key: K
    ) throws -> UInt16? {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decodeIfPresent(UInt16.self, forKey: key)
    }
    
    override internal func decodeIfPresent<K: CodingKey>(
        _ type: UInt32.Type,
        forKey key: K
    ) throws -> UInt32? {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decodeIfPresent(UInt32.self, forKey: key)
    }
    
    override internal func decodeIfPresent<K: CodingKey>(
        _ type: UInt64.Type,
        forKey key: K
    ) throws -> UInt64? {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decodeIfPresent(UInt64.self, forKey: key)
    }
    
    override internal func decodeIfPresent<T: Decodable, K: CodingKey>(
        _ type: T.Type,
        forKey key: K
    ) throws -> T? {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.decodeIfPresent(T.self, forKey: key)
    }
    
    override internal func nestedContainer<NestedKey, K: CodingKey>(
        keyedBy type: NestedKey.Type,
        forKey key: K
    ) throws -> KeyedDecodingContainer<NestedKey> {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.nestedContainer(keyedBy: NestedKey.self, forKey: key)
    }
    
    override internal func nestedUnkeyedContainer<K: CodingKey>(
        forKey key: K
    ) throws -> UnkeyedDecodingContainer {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.nestedUnkeyedContainer(forKey: key)
    }
    
    override internal func superDecoder() throws -> Decoder {
        return try concrete.superDecoder()
    }
    
    override internal func superDecoder<K: CodingKey>(forKey key: K) throws -> Decoder {
        assert(K.self == Key.self)
        let key = unsafeBitCast(key, to: Key.self)
        return try concrete.superDecoder(forKey: key)
    }
}



// 以下是基本数据类型对于 Codeing 的适配工作.

extension Bool: Codable {
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(Bool.self)
    }
    
    // 对于, 这些明确的, 已经不会改动的值, 直接使用 singleValueContainer
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension RawRepresentable where RawValue == Bool, Self: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

// Decode 的时候, 一定要加相应的错误处理相关的逻辑.
extension RawRepresentable where RawValue == Bool, Self: Decodable {
    public init(from decoder: Decoder) throws {
        let decoded = try decoder.singleValueContainer().decode(RawValue.self)
        guard let value = Self(rawValue: decoded) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"
                )
            )
        }
        self = value
    }
}

extension String: Codable {
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(String.self)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}
// Where RawValue: Encodable, Self: Encodable 不可以吗
extension RawRepresentable where RawValue == String, Self: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension RawRepresentable where RawValue == String, Self: Decodable {
    public init(from decoder: Decoder) throws {
        let decoded = try decoder.singleValueContainer().decode(RawValue.self)
        guard let value = Self(rawValue: decoded) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"
                )
            )
        }
        
        self = value
    }
}

extension Double: Codable {
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(Double.self)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension RawRepresentable where RawValue == Double, Self: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension RawRepresentable where RawValue == Double, Self: Decodable {
    public init(from decoder: Decoder) throws {
        let decoded = try decoder.singleValueContainer().decode(RawValue.self)
        guard let value = Self(rawValue: decoded) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"
                )
            )
        }
        self = value
    }
}

extension Float: Codable {
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(Float.self)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension RawRepresentable where RawValue == Float, Self: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension RawRepresentable where RawValue == Float, Self: Decodable {
    public init(from decoder: Decoder) throws {
        let decoded = try decoder.singleValueContainer().decode(RawValue.self)
        guard let value = Self(rawValue: decoded) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"
                )
            )
        }
        
        self = value
    }
}

@available(macOS 10.16, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
extension Float16: Codable {
    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let floatValue = try Float(from: decoder)
        self = Float16(floatValue)
        if isInfinite && floatValue.isFinite {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Parsed JSON number \(floatValue) does not fit in Float16."
                )
            )
        }
    }
    
    /// Encodes this value into the given encoder.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        try Float(self).encode(to: encoder)
    }
}

extension Int: Codable {
    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(Int.self)
    }
    
    /// Encodes this value into the given encoder.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension RawRepresentable where RawValue == Int, Self: Encodable {
    /// Encodes this value into the given encoder, when the type's `RawValue`
    /// is `Int`.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension RawRepresentable where RawValue == Int, Self: Decodable {
    /// Creates a new instance by decoding from the given decoder, when the
    /// type's `RawValue` is `Int`.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let decoded = try decoder.singleValueContainer().decode(RawValue.self)
        guard let value = Self(rawValue: decoded) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"
                )
            )
        }
        
        self = value
    }
}

extension Int8: Codable {
    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(Int8.self)
    }
    
    /// Encodes this value into the given encoder.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension RawRepresentable where RawValue == Int8, Self: Encodable {
    /// Encodes this value into the given encoder, when the type's `RawValue`
    /// is `Int8`.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension RawRepresentable where RawValue == Int8, Self: Decodable {
    /// Creates a new instance by decoding from the given decoder, when the
    /// type's `RawValue` is `Int8`.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let decoded = try decoder.singleValueContainer().decode(RawValue.self)
        guard let value = Self(rawValue: decoded) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"
                )
            )
        }
        
        self = value
    }
}

extension Int16: Codable {
    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(Int16.self)
    }
    
    /// Encodes this value into the given encoder.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension RawRepresentable where RawValue == Int16, Self: Encodable {
    /// Encodes this value into the given encoder, when the type's `RawValue`
    /// is `Int16`.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension RawRepresentable where RawValue == Int16, Self: Decodable {
    /// Creates a new instance by decoding from the given decoder, when the
    /// type's `RawValue` is `Int16`.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let decoded = try decoder.singleValueContainer().decode(RawValue.self)
        guard let value = Self(rawValue: decoded) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"
                )
            )
        }
        
        self = value
    }
}

extension Int32: Codable {
    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(Int32.self)
    }
    
    /// Encodes this value into the given encoder.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension RawRepresentable where RawValue == Int32, Self: Encodable {
    /// Encodes this value into the given encoder, when the type's `RawValue`
    /// is `Int32`.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension RawRepresentable where RawValue == Int32, Self: Decodable {
    /// Creates a new instance by decoding from the given decoder, when the
    /// type's `RawValue` is `Int32`.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let decoded = try decoder.singleValueContainer().decode(RawValue.self)
        guard let value = Self(rawValue: decoded) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"
                )
            )
        }
        
        self = value
    }
}

extension Int64: Codable {
    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(Int64.self)
    }
    
    /// Encodes this value into the given encoder.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension RawRepresentable where RawValue == Int64, Self: Encodable {
    /// Encodes this value into the given encoder, when the type's `RawValue`
    /// is `Int64`.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension RawRepresentable where RawValue == Int64, Self: Decodable {
    /// Creates a new instance by decoding from the given decoder, when the
    /// type's `RawValue` is `Int64`.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let decoded = try decoder.singleValueContainer().decode(RawValue.self)
        guard let value = Self(rawValue: decoded) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"
                )
            )
        }
        
        self = value
    }
}

extension UInt: Codable {
    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(UInt.self)
    }
    
    /// Encodes this value into the given encoder.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension RawRepresentable where RawValue == UInt, Self: Encodable {
    /// Encodes this value into the given encoder, when the type's `RawValue`
    /// is `UInt`.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension RawRepresentable where RawValue == UInt, Self: Decodable {
    /// Creates a new instance by decoding from the given decoder, when the
    /// type's `RawValue` is `UInt`.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let decoded = try decoder.singleValueContainer().decode(RawValue.self)
        guard let value = Self(rawValue: decoded) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"
                )
            )
        }
        
        self = value
    }
}

extension UInt8: Codable {
    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(UInt8.self)
    }
    
    /// Encodes this value into the given encoder.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension RawRepresentable where RawValue == UInt8, Self: Encodable {
    /// Encodes this value into the given encoder, when the type's `RawValue`
    /// is `UInt8`.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension RawRepresentable where RawValue == UInt8, Self: Decodable {
    /// Creates a new instance by decoding from the given decoder, when the
    /// type's `RawValue` is `UInt8`.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let decoded = try decoder.singleValueContainer().decode(RawValue.self)
        guard let value = Self(rawValue: decoded) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"
                )
            )
        }
        
        self = value
    }
}

extension UInt16: Codable {
    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(UInt16.self)
    }
    
    /// Encodes this value into the given encoder.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension RawRepresentable where RawValue == UInt16, Self: Encodable {
    /// Encodes this value into the given encoder, when the type's `RawValue`
    /// is `UInt16`.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension RawRepresentable where RawValue == UInt16, Self: Decodable {
    /// Creates a new instance by decoding from the given decoder, when the
    /// type's `RawValue` is `UInt16`.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let decoded = try decoder.singleValueContainer().decode(RawValue.self)
        guard let value = Self(rawValue: decoded) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"
                )
            )
        }
        
        self = value
    }
}

extension UInt32: Codable {
    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(UInt32.self)
    }
    
    /// Encodes this value into the given encoder.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension RawRepresentable where RawValue == UInt32, Self: Encodable {
    /// Encodes this value into the given encoder, when the type's `RawValue`
    /// is `UInt32`.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension RawRepresentable where RawValue == UInt32, Self: Decodable {
    /// Creates a new instance by decoding from the given decoder, when the
    /// type's `RawValue` is `UInt32`.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let decoded = try decoder.singleValueContainer().decode(RawValue.self)
        guard let value = Self(rawValue: decoded) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"
                )
            )
        }
        
        self = value
    }
}

extension UInt64: Codable {
    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(UInt64.self)
    }
    
    /// Encodes this value into the given encoder.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self)
    }
}

extension RawRepresentable where RawValue == UInt64, Self: Encodable {
    /// Encodes this value into the given encoder, when the type's `RawValue`
    /// is `UInt64`.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension RawRepresentable where RawValue == UInt64, Self: Decodable {
    /// Creates a new instance by decoding from the given decoder, when the
    /// type's `RawValue` is `UInt64`.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let decoded = try decoder.singleValueContainer().decode(RawValue.self)
        guard let value = Self(rawValue: decoded) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize \(Self.self) from invalid \(RawValue.self) value \(decoded)"
                )
            )
        }
        
        self = value
    }
}

// 以下是复杂数据类型的 Codable 的适配

// 必须 Wrapped: Encodable, 这是前提.
extension Optional: Encodable where Wrapped: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none: try container.encodeNil()
        case .some(let wrapped): try container.encode(wrapped)
        }
    }
}

extension Optional: Decodable where Wrapped: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // 如果, 能够 decodeNil, 就代表 Optianl 是 Null, 否则, 就按照 Wrapped 来进行反序列化.
        // 其实, 使用一个 Type 明显的进行标识更加的友好一点.
        if container.decodeNil() {
            self = .none
        }  else {
            let element = try container.decode(Wrapped.self)
            self = .some(element)
        }
    }
}

//Array 就是使用了 unkeyedContainer, 非常符合 Array 的逻辑.
extension Array: Encodable where Element: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for element in self {
            try container.encode(element)
        }
    }
}

extension Array: Decodable where Element: Decodable {
    public init(from decoder: Decoder) throws {
        self.init()
        
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            let element = try container.decode(Element.self)
            self.append(element)
        }
    }
}

extension ContiguousArray: Encodable where Element: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for element in self {
            try container.encode(element)
        }
    }
}

extension ContiguousArray: Decodable where Element: Decodable {
    public init(from decoder: Decoder) throws {
        self.init()
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            let element = try container.decode(Element.self)
            self.append(element)
        }
    }
}

// Set, 就是 Array,
extension Set: Encodable where Element: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for element in self {
            try container.encode(element)
        }
    }
}

extension Set: Decodable where Element: Decodable {
    public init(from decoder: Decoder) throws {
        self.init()
        
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            let element = try container.decode(Element.self)
            self.insert(element)
        }
    }
}

// 字典的序列化反序列化

internal struct _DictionaryCodingKey: CodingKey {
    internal let stringValue: String
    internal let intValue: Int?
    internal init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = Int(stringValue)
    }
    internal init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

extension Dictionary: Encodable where Key: Encodable, Value: Encodable {
    // 如果, 字典的 key 是 String, 或者 Int, 那么就用 keyed 进行存储,
    // 否则, 是按照数组进行存储的.
    public func encode(to encoder: Encoder) throws {
        if Key.self == String.self {
            var container = encoder.container(keyedBy: _DictionaryCodingKey.self)
            for (key, value) in self {
                let codingKey = _DictionaryCodingKey(stringValue: key as! String)!
                try container.encode(value, forKey: codingKey)
            }
        } else if Key.self == Int.self {
            var container = encoder.container(keyedBy: _DictionaryCodingKey.self)
            for (key, value) in self {
                let codingKey = _DictionaryCodingKey(intValue: key as! Int)!
                try container.encode(value, forKey: codingKey)
            }
        } else {
            // 对于不是 int, 或者 string 为 key 的 dict, 是用数组存取的 key_value pair.
            var container = encoder.unkeyedContainer()
            for (key, value) in self {
                try container.encode(key)
                try container.encode(value)
            }
        }
    }
}

extension Dictionary: Decodable where Key: Decodable, Value: Decodable {
    public init(from decoder: Decoder) throws {
        self.init()
        
        if Key.self == String.self {
            let container = try decoder.container(keyedBy: _DictionaryCodingKey.self)
            for key in container.allKeys {
                let value = try container.decode(Value.self, forKey: key)
                self[key.stringValue as! Key] = value
            }
        } else if Key.self == Int.self {
            let container = try decoder.container(keyedBy: _DictionaryCodingKey.self)
            for key in container.allKeys {
                guard key.intValue != nil else {
                    // We provide stringValues for Int keys; if an encoder chooses not to
                    // use the actual intValues, we've encoded string keys.
                    // So on init, _DictionaryCodingKey tries to parse string keys as
                    // Ints. If that succeeds, then we would have had an intValue here.
                    // We don't, so this isn't a valid Int key.
                    var codingPath = decoder.codingPath
                    codingPath.append(key)
                    throw DecodingError.typeMismatch(
                        Int.self,
                        DecodingError.Context(
                            codingPath: codingPath,
                            debugDescription: "Expected Int key but found String key instead."
                        )
                    )
                }
                
                let value = try container.decode(Value.self, forKey: key)
                self[key.intValue! as! Key] = value
            }
        } else {
            var container = try decoder.unkeyedContainer()
            
            // We're expecting to get pairs. If the container has a known count, it
            // had better be even; no point in doing work if not.
            if let count = container.count {
                guard count % 2 == 0 else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "Expected collection of key-value pairs; encountered odd-length array instead."
                        )
                    )
                }
            }
            
            while !container.isAtEnd {
                let key = try container.decode(Key.self)
                
                guard !container.isAtEnd else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "Unkeyed container reached end before value in key-value pair."
                        )
                    )
                }
                
                let value = try container.decode(Value.self)
                self[key] = value
            }
        }
    }
}

//===----------------------------------------------------------------------===//
// Convenience Default Implementations
//===----------------------------------------------------------------------===//

// 默认就是无条件的进行序列化.
extension KeyedEncodingContainerProtocol {
    public mutating func encodeConditional<T: AnyObject & Encodable>(
        _ object: T,
        forKey key: Key
    ) throws {
        try encode(object, forKey: key)
    }
}

// 对于 IfPresent 这种, 都是默认如果为 nil, 不序列化该值的解决方案.
extension KeyedEncodingContainerProtocol {
    public mutating func encodeIfPresent(
        _ value: Bool?,
        forKey key: Key
    ) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: String?,
        forKey key: Key
    ) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: Double?,
        forKey key: Key
    ) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: Float?,
        forKey key: Key
    ) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: Int?,
        forKey key: Key
    ) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: Int8?,
        forKey key: Key
    ) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: Int16?,
        forKey key: Key
    ) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: Int32?,
        forKey key: Key
    ) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: Int64?,
        forKey key: Key
    ) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: UInt?,
        forKey key: Key
    ) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: UInt8?,
        forKey key: Key
    ) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: UInt16?,
        forKey key: Key
    ) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: UInt32?,
        forKey key: Key
    ) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }
    
    public mutating func encodeIfPresent(
        _ value: UInt64?,
        forKey key: Key
    ) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }
    
    public mutating func encodeIfPresent<T: Encodable>(
        _ value: T?,
        forKey key: Key
    ) throws {
        guard let value = value else { return }
        try encode(value, forKey: key)
    }
}

// Default implementation of decodeIfPresent(_:forKey:) in terms of
// decode(_:forKey:) and decodeNil(forKey:)
extension KeyedDecodingContainerProtocol {
    public func decodeIfPresent(
        _ type: Bool.Type,
        forKey key: Key
    ) throws -> Bool? {
        guard try self.contains(key) && !self.decodeNil(forKey: key)
        else { return nil }
        return try self.decode(Bool.self, forKey: key)
    }
    
    public func decodeIfPresent(
        _ type: String.Type,
        forKey key: Key
    ) throws -> String? {
        guard try self.contains(key) && !self.decodeNil(forKey: key)
        else { return nil }
        return try self.decode(String.self, forKey: key)
    }
    
    public func decodeIfPresent(
        _ type: Double.Type,
        forKey key: Key
    ) throws -> Double? {
        guard try self.contains(key) && !self.decodeNil(forKey: key)
        else { return nil }
        return try self.decode(Double.self, forKey: key)
    }
    
    public func decodeIfPresent(
        _ type: Float.Type,
        forKey key: Key
    ) throws -> Float? {
        guard try self.contains(key) && !self.decodeNil(forKey: key)
        else { return nil }
        return try self.decode(Float.self, forKey: key)
    }
    
    public func decodeIfPresent(
        _ type: Int.Type,
        forKey key: Key
    ) throws -> Int? {
        guard try self.contains(key) && !self.decodeNil(forKey: key)
        else { return nil }
        return try self.decode(Int.self, forKey: key)
    }
    
    public func decodeIfPresent(
        _ type: Int8.Type,
        forKey key: Key
    ) throws -> Int8? {
        guard try self.contains(key) && !self.decodeNil(forKey: key)
        else { return nil }
        return try self.decode(Int8.self, forKey: key)
    }
    
    public func decodeIfPresent(
        _ type: Int16.Type,
        forKey key: Key
    ) throws -> Int16? {
        guard try self.contains(key) && !self.decodeNil(forKey: key)
        else { return nil }
        return try self.decode(Int16.self, forKey: key)
    }
    
    public func decodeIfPresent(
        _ type: Int32.Type,
        forKey key: Key
    ) throws -> Int32? {
        guard try self.contains(key) && !self.decodeNil(forKey: key)
        else { return nil }
        return try self.decode(Int32.self, forKey: key)
    }
    
    public func decodeIfPresent(
        _ type: Int64.Type,
        forKey key: Key
    ) throws -> Int64? {
        guard try self.contains(key) && !self.decodeNil(forKey: key)
        else { return nil }
        return try self.decode(Int64.self, forKey: key)
    }
    
    public func decodeIfPresent(
        _ type: UInt.Type,
        forKey key: Key
    ) throws -> UInt? {
        guard try self.contains(key) && !self.decodeNil(forKey: key)
        else { return nil }
        return try self.decode(UInt.self, forKey: key)
    }
    
    public func decodeIfPresent(
        _ type: UInt8.Type,
        forKey key: Key
    ) throws -> UInt8? {
        guard try self.contains(key) && !self.decodeNil(forKey: key)
        else { return nil }
        return try self.decode(UInt8.self, forKey: key)
    }
    
    public func decodeIfPresent(
        _ type: UInt16.Type,
        forKey key: Key
    ) throws -> UInt16? {
        guard try self.contains(key) && !self.decodeNil(forKey: key)
        else { return nil }
        return try self.decode(UInt16.self, forKey: key)
    }
    
    public func decodeIfPresent(
        _ type: UInt32.Type,
        forKey key: Key
    ) throws -> UInt32? {
        guard try self.contains(key) && !self.decodeNil(forKey: key)
        else { return nil }
        return try self.decode(UInt32.self, forKey: key)
    }
    
    public func decodeIfPresent(
        _ type: UInt64.Type,
        forKey key: Key
    ) throws -> UInt64? {
        guard try self.contains(key) && !self.decodeNil(forKey: key)
        else { return nil }
        return try self.decode(UInt64.self, forKey: key)
    }
    
    public func decodeIfPresent<T: Decodable>(
        _ type: T.Type,
        forKey key: Key
    ) throws -> T? {
        guard try self.contains(key) && !self.decodeNil(forKey: key)
        else { return nil }
        return try self.decode(T.self, forKey: key)
    }
}

// Default implementation of encodeConditional(_:) in terms of encode(_:),
// and encode(contentsOf:) in terms of encode(_:) loop.
extension UnkeyedEncodingContainer {
    public mutating func encodeConditional<T: AnyObject & Encodable>(
        _ object: T
    ) throws {
        try self.encode(object)
    }
    
    public mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == Bool {
        for element in sequence {
            try self.encode(element)
        }
    }
    
    public mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == String {
        for element in sequence {
            try self.encode(element)
        }
    }
    
    public mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == Double {
        for element in sequence {
            try self.encode(element)
        }
    }
    
    public mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == Float {
        for element in sequence {
            try self.encode(element)
        }
    }
    
    public mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == Int {
        for element in sequence {
            try self.encode(element)
        }
    }
    
    public mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == Int8 {
        for element in sequence {
            try self.encode(element)
        }
    }
    
    public mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == Int16 {
        for element in sequence {
            try self.encode(element)
        }
    }
    
    public mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == Int32 {
        for element in sequence {
            try self.encode(element)
        }
    }
    
    public mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == Int64 {
        for element in sequence {
            try self.encode(element)
        }
    }
    
    public mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == UInt {
        for element in sequence {
            try self.encode(element)
        }
    }
    
    public mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == UInt8 {
        for element in sequence {
            try self.encode(element)
        }
    }
    
    public mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == UInt16 {
        for element in sequence {
            try self.encode(element)
        }
    }
    
    public mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == UInt32 {
        for element in sequence {
            try self.encode(element)
        }
    }
    
    public mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element == UInt64 {
        for element in sequence {
            try self.encode(element)
        }
    }
    
    public mutating func encode<T: Sequence>(
        contentsOf sequence: T
    ) throws where T.Element: Encodable {
        for element in sequence {
            try self.encode(element)
        }
    }
}

// Default implementation of decodeIfPresent(_:) in terms of decode(_:) and
// decodeNil()
extension UnkeyedDecodingContainer {
    public mutating func decodeIfPresent(
        _ type: Bool.Type
    ) throws -> Bool? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(Bool.self)
    }
    
    public mutating func decodeIfPresent(
        _ type: String.Type
    ) throws -> String? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(String.self)
    }
    
    public mutating func decodeIfPresent(
        _ type: Double.Type
    ) throws -> Double? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(Double.self)
    }
    
    public mutating func decodeIfPresent(
        _ type: Float.Type
    ) throws -> Float? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(Float.self)
    }
    
    public mutating func decodeIfPresent(
        _ type: Int.Type
    ) throws -> Int? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(Int.self)
    }
    
    public mutating func decodeIfPresent(
        _ type: Int8.Type
    ) throws -> Int8? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(Int8.self)
    }
    
    public mutating func decodeIfPresent(
        _ type: Int16.Type
    ) throws -> Int16? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(Int16.self)
    }
    
    public mutating func decodeIfPresent(
        _ type: Int32.Type
    ) throws -> Int32? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(Int32.self)
    }
    
    public mutating func decodeIfPresent(
        _ type: Int64.Type
    ) throws -> Int64? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(Int64.self)
    }
    
    public mutating func decodeIfPresent(
        _ type: UInt.Type
    ) throws -> UInt? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(UInt.self)
    }
    
    public mutating func decodeIfPresent(
        _ type: UInt8.Type
    ) throws -> UInt8? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(UInt8.self)
    }
    
    public mutating func decodeIfPresent(
        _ type: UInt16.Type
    ) throws -> UInt16? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(UInt16.self)
    }
    
    public mutating func decodeIfPresent(
        _ type: UInt32.Type
    ) throws -> UInt32? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(UInt32.self)
    }
    
    public mutating func decodeIfPresent(
        _ type: UInt64.Type
    ) throws -> UInt64? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(UInt64.self)
    }
    
    public mutating func decodeIfPresent<T: Decodable>(
        _ type: T.Type
    ) throws -> T? {
        guard try !self.isAtEnd && !self.decodeNil() else { return nil }
        return try self.decode(T.self)
    }
}
