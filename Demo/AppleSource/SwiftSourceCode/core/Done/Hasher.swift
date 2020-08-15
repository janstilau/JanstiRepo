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
    @usableFromInline @frozen
    internal struct _TailBuffer {
        // msb                                                             lsb
        // +---------+-------+-------+-------+-------+-------+-------+-------+
        // |byteCount|                 tail (<= 56 bits)                     |
        // +---------+-------+-------+-------+-------+-------+-------+-------+
        internal var value: UInt64
        
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
    
    @usableFromInline @frozen
    /*
     Core 里面, _buffer 用作值的存储, _state 用作最终值的计算逻辑的载体.
     */
    internal struct _Core {
        private var _buffer: _TailBuffer
        private var _state: Hasher._State
        
        @inline(__always)
        internal init(state: Hasher._State) {
            self._buffer = _TailBuffer()
            self._state = state
        }
        
        @inline(__always)
        internal init() {
            self.init(state: _State())
        }
        
        @inline(__always)
        internal init(seed: Int) {
            self.init(state: _State(seed: seed))
        }
        
        @inline(__always)
        internal mutating func combine(_ value: UInt) {
            #if arch(i386) || arch(arm)
            combine(UInt32(truncatingIfNeeded: value))
            #else
            combine(UInt64(truncatingIfNeeded: value))
            #endif
        }
        
        @inline(__always)
        internal mutating func combine(_ value: UInt64) {
            _state.compress(_buffer.append(value))
        }
        
        @inline(__always)
        internal mutating func combine(_ value: UInt32) {
            let value = UInt64(truncatingIfNeeded: value)
            if let chunk = _buffer.append(value, count: 4) {
                _state.compress(chunk)
            }
        }
        
        @inline(__always)
        internal mutating func combine(_ value: UInt16) {
            let value = UInt64(truncatingIfNeeded: value)
            if let chunk = _buffer.append(value, count: 2) {
                _state.compress(chunk)
            }
        }
        
        @inline(__always)
        internal mutating func combine(_ value: UInt8) {
            let value = UInt64(truncatingIfNeeded: value)
            if let chunk = _buffer.append(value, count: 1) {
                _state.compress(chunk)
            }
        }
        
        @inline(__always)
        internal mutating func combine(bytes: UInt64, count: Int) {
            _internalInvariant(count >= 0 && count < 8)
            let count = UInt64(truncatingIfNeeded: count)
            if let chunk = _buffer.append(bytes, count: count) {
                _state.compress(chunk)
            }
        }
        
        @inline(__always)
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
        
        @inline(__always)
        internal mutating func finalize() -> UInt64 {
            return _state.finalize(tailAndByteCount: _buffer.value)
        }
    }
}


/*
 具体的 Core 和 Buffer 原理没有细看.
 可以简单的认为, Core 是做逻辑运算的, Buffer 是做值的存储的.
 */

/*
 Hasher 可以不断的用 Combine 进行值的填入, 然后最后调用 finalize 得到想要的值.
 一般来说, 我们自己的对象, 想要进行 hash, 只会把 id 相关的值, 进行填入.
 id 作为整个 app 中, 逻辑唯一性的表示. 在数据库中可以保证唯一性.
 
 swift 的 hasher 可以保证, 如果值发生了改变, 或者传入的次序发生了改变, 那么最后的 hash 值会发生大改变.
 这就避免了, 简单的 hash 算法, 例如成员变量 hash 值相加导致最终结果一样的后果.
 可以说, 系统提供了这个类, 简便了用户自己设计 hash 算法的必要了.
 不过, 这个 hash 值是不稳定了, 每次重新运用, 相同的数据, 会产生不同的结果. 所以, 这个值不应该进行存储.
 如果要进行存储, 还是用通用的 MD5, sha 算法得到的值.
 hash 值, 本身是 hash 表用作检索用的. 而 hash 表, 本身就是一个内存里面才有的概念. 所以, 每次运用, 重新 hash 生成该表就可以了.
 */

@frozen // FIXME: Should be resilient (rdar://problem/38549901)
public struct Hasher {
    internal var _core: _Core // Core
    
    @_effects(releasenone)
    public init() {
        self._core = _Core()
    }
    
    @usableFromInline
    @_effects(releasenone)
    internal init(_seed: Int) {
        self._core = _Core(seed: _seed)
    }
    
    @usableFromInline // @testable
    @_effects(releasenone)
    internal init(_rawSeed: (UInt64, UInt64)) {
        self._core = _Core(state: _State(rawSeed: _rawSeed))
    }
    
    /// Indicates whether we're running in an environment where hashing needs to
    /// be deterministic. If this is true, the hash seed is not random, and hash
    /// tables do not apply per-instance perturbation that is not repeatable.
    /// This is not recommended for production use, but it is useful in certain
    /// test environments where randomization may lead to unwanted nondeterminism
    /// of test results.
    @inlinable
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
    
    /*
     Hash 一个对象, 其实就是这个对象调用 hash 方法, 然后把 hasher 传入进去.
     程序员只会看到 hash 方法, 是因为, 整个生成 hash 值的过程, 是一个固定的流程, 程序员仅仅是改写其中一个方法而已.
     */
    @inlinable
    @inline(__always)
    public mutating func combine<H: Hashable>(_ value: H) {
        value.hash(into: &self)
    }
    
    /*
     各种不同的 int 值做 hash.
     */
    @_effects(releasenone)
    @usableFromInline
    internal mutating func _combine(_ value: UInt) {
        _core.combine(value)
    }
    
    @_effects(releasenone)
    @usableFromInline
    internal mutating func _combine(_ value: UInt64) {
        _core.combine(value)
    }
    
    @_effects(releasenone)
    @usableFromInline
    internal mutating func _combine(_ value: UInt32) {
        _core.combine(value)
    }
    
    @_effects(releasenone)
    @usableFromInline
    internal mutating func _combine(_ value: UInt16) {
        _core.combine(value)
    }
    
    @_effects(releasenone)
    @usableFromInline
    internal mutating func _combine(_ value: UInt8) {
        _core.combine(value)
    }
    
    @_effects(releasenone)
    @usableFromInline
    internal mutating func _combine(bytes value: UInt64, count: Int) {
        _core.combine(bytes: value, count: count)
    }
    
    @_effects(releasenone)
    public mutating func combine(bytes: UnsafeRawBufferPointer) {
        _core.combine(bytes: bytes)
    }
    
    /*
     这是一个破坏性的调用. finalize 之后, 不能再次调用了.
     */
    @_effects(releasenone)
    @usableFromInline
    internal mutating func _finalize() -> Int {
        return Int(truncatingIfNeeded: _core.finalize())
    }
    
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
        #if arch(i386) || arch(arm)
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
