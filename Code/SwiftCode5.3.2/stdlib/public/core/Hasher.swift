import SwiftShims

@inline(__always)
internal func _loadPartialUnalignedUInt64LE(
    _ p: UnsafeRawPointer,
    byteCount: Int
) -> UInt64 {
    var result: UInt64 = 0
    switch byteCount {
    case 7:
        result |= UInt64(p.load(fromByteOffset: 6, as: UInt8.self)) &<< 48
        fallthrough
    case 6:
        result |= UInt64(p.load(fromByteOffset: 5, as: UInt8.self)) &<< 40
        fallthrough
    case 5:
        result |= UInt64(p.load(fromByteOffset: 4, as: UInt8.self)) &<< 32
        fallthrough
    case 4:
        result |= UInt64(p.load(fromByteOffset: 3, as: UInt8.self)) &<< 24
        fallthrough
    case 3:
        result |= UInt64(p.load(fromByteOffset: 2, as: UInt8.self)) &<< 16
        fallthrough
    case 2:
        result |= UInt64(p.load(fromByteOffset: 1, as: UInt8.self)) &<< 8
        fallthrough
    case 1:
        result |= UInt64(p.load(fromByteOffset: 0, as: UInt8.self))
        fallthrough
    case 0:
        return result
    default:
        _internalInvariantFailure()
    }
}

extension Hasher {
    /// This is a buffer for segmenting arbitrary data into 8-byte chunks.  Buffer
    /// storage is represented by a single 64-bit value in the format used by the
    /// finalization step of SipHash. (The least significant 56 bits hold the
    /// trailing bytes, while the most significant 8 bits hold the count of bytes
    /// appended so far, modulo 256. The count of bytes currently stored in the
    /// buffer is in the lower three bits of the byte count.)
    // FIXME: Remove @usableFromInline and @frozen once Hasher is resilient.
    // rdar://problem/38549901
    @usableFromInline @frozen
    internal struct _TailBuffer {
        // msb                                                             lsb
        // +---------+-------+-------+-------+-------+-------+-------+-------+
        // |byteCount|                 tail (<= 56 bits)                     |
        // +---------+-------+-------+-------+-------+-------+-------+-------+
        internal var value: UInt64 // 所以实际上, 就一个值.
        
        @inline(__always)
        internal init() {
            self.value = 0
        }
        
        @inline(__always)
        internal init(tail: UInt64, byteCount: UInt64) {
            // byteCount can be any value, but we only keep the lower 8 bits.  (The
            // lower three bits specify the count of bytes stored in this buffer.)
            // FIXME: This should be a single expression, but it causes exponential
            // behavior in the expression type checker <rdar://problem/42672946>.
            let shiftedByteCount: UInt64 = ((byteCount & 7) << 3)
            let mask: UInt64 = (1 << shiftedByteCount - 1)
            _internalInvariant(tail & ~mask == 0)
            self.value = (byteCount &<< 56 | tail)
        }
        
        @inline(__always)
        internal init(tail: UInt64, byteCount: Int) {
            self.init(tail: tail, byteCount: UInt64(truncatingIfNeeded: byteCount))
        }
        
        internal var tail: UInt64 {
            @inline(__always)
            get { return value & ~(0xFF &<< 56) }
        }
        
        internal var byteCount: UInt64 {
            @inline(__always)
            get { return value &>> 56 }
        }
        
        @inline(__always)
        internal mutating func append(_ bytes: UInt64) -> UInt64 {
            let c = byteCount & 7
            if c == 0 {
                value = value &+ (8 &<< 56)
                return bytes
            }
            let shift = c &<< 3
            let chunk = tail | (bytes &<< shift)
            value = (((value &>> 56) &+ 8) &<< 56) | (bytes &>> (64 - shift))
            return chunk
        }
        
        @inline(__always)
        internal
        mutating func append(_ bytes: UInt64, count: UInt64) -> UInt64? {
            _internalInvariant(count >= 0 && count < 8)
            _internalInvariant(bytes & ~((1 &<< (count &<< 3)) &- 1) == 0)
            let c = byteCount & 7
            let shift = c &<< 3
            if c + count < 8 {
                value = (value | (bytes &<< shift)) &+ (count &<< 56)
                return nil
            }
            let chunk = tail | (bytes &<< shift)
            value = ((value &>> 56) &+ count) &<< 56
            if c + count > 8 {
                value |= bytes &>> (64 - shift)
            }
            return chunk
        }
    }
}

extension Hasher {
    // 内部类型, 用 _Core 进行定义.
    //
    internal struct _Core {
        private var _buffer: _TailBuffer
        private var _state: Hasher._State // State 是真证的进行 hash 计算的类.
        
        internal init(state: Hasher._State) {
            self._buffer = _TailBuffer()
            self._state = state
        }
        
        internal init() {
            self.init(state: _State())
        }
        
        // 各种基本数据类型, 使用 state 的 compress 方法, 进行数据的填充.
        internal init(seed: Int) {
            self.init(state: _State(seed: seed))
        }
        
        internal mutating func combine(_ value: UInt) {
            combine(UInt64(truncatingIfNeeded: value))
        }
        
        internal mutating func combine(_ value: UInt64) {
            _state.compress(_buffer.append(value))
        }
        
        internal mutating func combine(_ value: UInt32) {
            let value = UInt64(truncatingIfNeeded: value)
            if let chunk = _buffer.append(value, count: 4) {
                _state.compress(chunk)
            }
        }
        
        internal mutating func combine(_ value: UInt16) {
            let value = UInt64(truncatingIfNeeded: value)
            if let chunk = _buffer.append(value, count: 2) {
                _state.compress(chunk)
            }
        }
        
        internal mutating func combine(_ value: UInt8) {
            let value = UInt64(truncatingIfNeeded: value)
            if let chunk = _buffer.append(value, count: 1) {
                _state.compress(chunk)
            }
        }
        
        internal mutating func combine(bytes: UInt64, count: Int) {
            _internalInvariant(count >= 0 && count < 8)
            let count = UInt64(truncatingIfNeeded: count)
            if let chunk = _buffer.append(bytes, count: count) {
                _state.compress(chunk)
            }
        }
        
        internal mutating func combine(bytes: UnsafeRawBufferPointer) {
            var remaining = bytes.count
            guard remaining > 0 else { return }
            var data = bytes.baseAddress!
            
            // Load first unaligned partial word of data
            do {
                let start = UInt(bitPattern: data)
                let end = _roundUp(start, toAlignment: MemoryLayout<UInt64>.alignment)
                let c = min(remaining, Int(end - start))
                if c > 0 {
                    let chunk = _loadPartialUnalignedUInt64LE(data, byteCount: c)
                    combine(bytes: chunk, count: c)
                    data += c
                    remaining -= c
                }
            }
            _internalInvariant(
                remaining == 0 ||
                    Int(bitPattern: data) & (MemoryLayout<UInt64>.alignment - 1) == 0)
            
            // Load as many aligned words as there are in the input buffer
            while remaining >= MemoryLayout<UInt64>.size {
                combine(UInt64(littleEndian: data.load(as: UInt64.self)))
                data += MemoryLayout<UInt64>.size
                remaining -= MemoryLayout<UInt64>.size
            }
            
            // Load last partial word of data
            _internalInvariant(remaining >= 0 && remaining < 8)
            if remaining > 0 {
                let chunk = _loadPartialUnalignedUInt64LE(data, byteCount: remaining)
                combine(bytes: chunk, count: remaining)
            }
        }
        
        internal mutating func finalize() -> UInt64 {
            return _state.finalize(tailAndByteCount: _buffer.value)
        }
    }
}

/* Hash 本意是将一个复杂的数据类型, 转化为一个 int 值, 这样就可以用到 hash 表里面, 而 hash 是一个小型的数据库, 可以快速的读取. 这个小型的数据库, 需要一个非负整数值.
    如何获得这个值, 是每个类自己的能力. 所以, hash 方法需要每个类自己的写, 一般来说, 都会挑选一个 id 值作为 key, 进行 hash. 但是 Swift 特别强调值对象, 也就是用数据来代表一个对象, 而不是 id. id 代表对象, 更多的像是引用对象的意味.
 同时, 不同的数据类型, 如何 hash, 如果有一个通用的 hash 函数, 可以应对任何的类型的 hash, 那么编写类的人会轻松很多.
 基本数据类型的 hash 方法, 标准库一定会提供的, 但是一个对象, 很很多基本数据类型, 那么如何组织这些成员综合获得的最终值, 其实没有一个通用的解决方法.
 Hasher 就是一个通用的哈希函数的封装.
 Hasher 每次程序运行的时候, 随机种子都会变化, 所以获取的 hash 值, 不能用于存储.
 
 Hasher 的 combine, 仅仅有几个 Int 为参数的接口, 一个指针的接口, 一个 Hashable 参数的接口. 其实也是很明白的事情. 任何数据, 都能算作是 Int 数据的集合. 标准库一定会把常见的数据类型, 例如 double, int, string 的 hasher 写好的了, 那么在 Hashable 里面, 直接取调用这些类型的 hash 方法就可以了.
 复杂的类型通过调用简单类型的 hash, 来获取 hash 值.
 基本上, 自定义的类型, 不会复杂到要自己实现, 数据到 Byte 的转化工作.
 
*/

// `Hasher` can be used to map an arbitrary sequence of bytes to an integer hash value
public struct Hasher {
    internal var _core: _Core
    
    // 每次程序启动的时候, 都会有一个随机种子设置. 这个种子, 应该是一个全局量. 这个设计思想, 可以借鉴下.
    public init() {
        self._core = _Core()
    }
    
    internal init(_seed: Int) {
        self._core = _Core(seed: _seed)
    }
    
    internal init(_rawSeed: (UInt64, UInt64)) {
        self._core = _Core(state: _State(rawSeed: _rawSeed))
    }
    
    internal static var _isDeterministic: Bool {
        @inline(__always)
        get {
            return _swift_stdlib_Hashing_parameters.deterministic
        }
    }
    
    /// The 128-bit hash seed used to initialize the hasher state. Initialized
    /// once during process startup.
    @inlinable // @testable
    internal static var _executionSeed: (UInt64, UInt64) {
        @inline(__always)
        get {
            // The seed itself is defined in C++ code so that it is initialized during
            // static construction.  Almost every Swift program uses hash tables, so
            // initializing the seed during the startup seems to be the right
            // trade-off.
            return (
                _swift_stdlib_Hashing_parameters.seed0,
                _swift_stdlib_Hashing_parameters.seed1)
        }
    }
    
    // 这里, 就是给了 value 一个机会, 进行自己的 hash value 的计算.
    // 这里其实有点怪, 本来是 a call(b), 实际里面的代码缺变为了 b call(a)
    public mutating func combine<H: Hashable>(_ value: H) {
        value.hash(into: &self)
    }
    
    internal mutating func _combine(_ value: UInt) {
        _core.combine(value)
    }
    
    internal mutating func _combine(_ value: UInt64) {
        _core.combine(value)
    }
    
    internal mutating func _combine(_ value: UInt32) {
        _core.combine(value)
    }
    
    internal mutating func _combine(_ value: UInt16) {
        _core.combine(value)
    }
    
    internal mutating func _combine(_ value: UInt8) {
        _core.combine(value)
    }
    
    internal mutating func _combine(bytes value: UInt64, count: Int) {
        _core.combine(bytes: value, count: count)
    }
    
    // 任何的数据类型, 都可以转化为字节流的形式.
    // 所以, 只要实现了该方法, 任何的数据类型都能够进行转化了.
    public mutating func combine(bytes: UnsafeRawBufferPointer) {
        _core.combine(bytes: bytes)
    }
    
    /// Finalize the hasher state and return the hash value.
    /// Finalizing invalidates the hasher; additional bits cannot be combined
    /// into it, and it cannot be finalized again.
    @_effects(releasenone)
    @usableFromInline
    internal mutating func _finalize() -> Int {
        return Int(truncatingIfNeeded: _core.finalize())
    }
    
    /// Finalizes the hasher state and returns the hash value.
    ///
    /// Finalizing consumes the hasher: it is illegal to finalize a hasher you
    /// don't own, or to perform operations on a finalized hasher. (These may
    /// become compile-time errors in the future.)
    ///
    /// Hash values are not guaranteed to be equal across different executions of
    /// your program. Do not save hash values to use during a future execution.
    ///
    /// - Returns: The hash value calculated by the hasher.
    @_effects(releasenone)
    public __consuming func finalize() -> Int {
        var core = _core
        return Int(truncatingIfNeeded: core.finalize())
    }
    
    @_effects(readnone)
    @usableFromInline
    internal static func _hash(seed: Int, _ value: UInt64) -> Int {
        var state = _State(seed: seed)
        state.compress(value)
        let tbc = _TailBuffer(tail: 0, byteCount: 8)
        return Int(truncatingIfNeeded: state.finalize(tailAndByteCount: tbc.value))
    }
    
    @_effects(readnone)
    @usableFromInline
    internal static func _hash(seed: Int, _ value: UInt) -> Int {
        var state = _State(seed: seed)
        #if arch(i386) || arch(arm) || arch(wasm32)
        _internalInvariant(UInt.bitWidth < UInt64.bitWidth)
        let tbc = _TailBuffer(
            tail: UInt64(truncatingIfNeeded: value),
            byteCount: UInt.bitWidth &>> 3)
        #else
        _internalInvariant(UInt.bitWidth == UInt64.bitWidth)
        state.compress(UInt64(truncatingIfNeeded: value))
        let tbc = _TailBuffer(tail: 0, byteCount: 8)
        #endif
        return Int(truncatingIfNeeded: state.finalize(tailAndByteCount: tbc.value))
    }
    
    @_effects(readnone)
    @usableFromInline
    internal static func _hash(
        seed: Int,
        bytes value: UInt64,
        count: Int) -> Int {
        _internalInvariant(count >= 0 && count < 8)
        var state = _State(seed: seed)
        let tbc = _TailBuffer(tail: value, byteCount: count)
        return Int(truncatingIfNeeded: state.finalize(tailAndByteCount: tbc.value))
    }
    
    @_effects(readnone)
    @usableFromInline
    internal static func _hash(
        seed: Int,
        bytes: UnsafeRawBufferPointer) -> Int {
        var core = _Core(seed: seed)
        core.combine(bytes: bytes)
        return Int(truncatingIfNeeded: core.finalize())
    }
}
