
// _ValidUTF8Buffer 表示的是, 一个合法的 UTF8 的表示.
// 在 UTF8.Swift func decode(_ source: EncodedScalar) -> Unicode.Scalar 里面, 是传递一个 _ValidUTF8Buffer 进入, 返回一个 Unicode.Scalar 出来.
// 因为 UTF8 可能是 1, 2, 3, 4 个字节的, 将这层逻辑, 通过 _ValidUTF8Buffer, typealias _ValidUTF8Buffer = EncodedScalar 进行一层封装而已.
public struct _ValidUTF8Buffer {
    public typealias Element = Unicode.UTF8.CodeUnit // UInt8
    // 真正存储的是一个 UInt32, 也就是 4 个 CodeUnit
    internal var _biasedBits: UInt32
    internal init(_biasedBits: UInt32) {
        self._biasedBits = _biasedBits
    }
    internal init(_containing e: Element) {
        _internalInvariant(
            e != 192 && e != 193 && !(245...255).contains(e), "invalid UTF8 byte")
        _biasedBits = UInt32(truncatingIfNeeded: e &+ 1)
    }
}

extension _ValidUTF8Buffer: Sequence {
    public typealias SubSequence = Slice<_ValidUTF8Buffer>
    
    public struct Iterator: IteratorProtocol, Sequence {
        public init(_ x: _ValidUTF8Buffer) { _biasedBits = x._biasedBits }
        public mutating func next() -> Element? {
            // 取当前值, 然后 _biasedBits 右移 8 位
            // 每个 Iterator 在创建的一个, copy 一份 Buffer 的 _biasedBits 进入, 这里 buffer 里的值不会被污染.
            if _biasedBits == 0 { return nil }
            defer { _biasedBits >>= 8 }
            return Element(truncatingIfNeeded: _biasedBits) &- 1
        }
        internal var _biasedBits: UInt32
    }
    
    @inlinable
    public func makeIterator() -> Iterator {
        return Iterator(self)
    }
}

extension _ValidUTF8Buffer: Collection {
    
    public struct Index: Comparable {
        internal var _biasedBits: UInt32
        internal init(_biasedBits: UInt32) { self._biasedBits = _biasedBits }
        public static func == (lhs: Index, rhs: Index) -> Bool {
            return lhs._biasedBits == rhs._biasedBits
        }
        public static func < (lhs: Index, rhs: Index) -> Bool {
            return lhs._biasedBits > rhs._biasedBits
        }
    }
    
    public var startIndex: Index {
        return Index(_biasedBits: _biasedBits)
    }
    
    public var endIndex: Index {
        return Index(_biasedBits: 0)
    }
    
    // 这里没看明白.
    public var count: Int {
        return UInt32.bitWidth &>> 3 &- _biasedBits.leadingZeroBitCount &>> 3
    }
    
    public var isEmpty: Bool {
        return _biasedBits == 0
    }
    
    public func index(after i: Index) -> Index {
        return Index(_biasedBits: i._biasedBits >> 8)
    }
    
    public subscript(i: Index) -> Element {
        return Element(truncatingIfNeeded: i._biasedBits) &- 1
    }
}

extension _ValidUTF8Buffer: BidirectionalCollection {
    public func index(before i: Index) -> Index {
        let offset = _ValidUTF8Buffer(_biasedBits: i._biasedBits).count
        return Index(_biasedBits: _biasedBits &>> (offset &<< 3 - 8))
    }
}

extension _ValidUTF8Buffer: RandomAccessCollection {
    public typealias Indices = DefaultIndices<_ValidUTF8Buffer>
    public func distance(from i: Index, to j: Index) -> Int {
        _debugPrecondition(_isValid(i))
        _debugPrecondition(_isValid(j))
        return (
            i._biasedBits.leadingZeroBitCount - j._biasedBits.leadingZeroBitCount
        ) &>> 3
    }
    
    @inlinable
    @inline(__always)
    public func index(_ i: Index, offsetBy n: Int) -> Index {
        let startOffset = distance(from: startIndex, to: i)
        let newOffset = startOffset + n
        _debugPrecondition(newOffset >= 0)
        _debugPrecondition(newOffset <= count)
        return Index(_biasedBits: _biasedBits._fullShiftRight(newOffset &<< 3))
    }
}

extension _ValidUTF8Buffer: RangeReplaceableCollection {
    @inlinable
    public init() {
        _biasedBits = 0
    }
    
    @inlinable
    public var capacity: Int {
        return _ValidUTF8Buffer.capacity
    }
    
    @inlinable
    public static var capacity: Int {
        return UInt32.bitWidth / Element.bitWidth
    }
    
    @inlinable
    @inline(__always)
    public mutating func append(_ e: Element) {
        _debugPrecondition(count + 1 <= capacity)
        _internalInvariant(
            e != 192 && e != 193 && !(245...255).contains(e), "invalid UTF8 byte")
        _biasedBits |= UInt32(e &+ 1) &<< (count &<< 3)
    }
    
    @inlinable
    @inline(__always)
    @discardableResult
    public mutating func removeFirst() -> Element {
        _debugPrecondition(!isEmpty)
        let result = Element(truncatingIfNeeded: _biasedBits) &- 1
        _biasedBits = _biasedBits._fullShiftRight(8)
        return result
    }
    
    @inlinable
    internal func _isValid(_ i: Index) -> Bool {
        return i == endIndex || indices.contains(i)
    }
    
    @inlinable
    @inline(__always)
    public mutating func replaceSubrange<C: Collection>(
        _ target: Range<Index>, with replacement: C
    ) where C.Element == Element {
        _debugPrecondition(_isValid(target.lowerBound))
        _debugPrecondition(_isValid(target.upperBound))
        var r = _ValidUTF8Buffer()
        for x in self[..<target.lowerBound] { r.append(x) }
        for x in replacement                { r.append(x) }
        for x in self[target.upperBound...] { r.append(x) }
        self = r
    }
}

extension _ValidUTF8Buffer {
    @inlinable
    @inline(__always)
    public mutating func append(contentsOf other: _ValidUTF8Buffer) {
        _debugPrecondition(count + other.count <= capacity)
        _biasedBits |= UInt32(
            truncatingIfNeeded: other._biasedBits) &<< (count &<< 3)
    }
}

extension _ValidUTF8Buffer {
    @inlinable
    public static var encodedReplacementCharacter: _ValidUTF8Buffer {
        return _ValidUTF8Buffer(_biasedBits: 0xBD_BF_EF &+ 0x01_01_01)
    }
    
    // 返回, 这个字符用 UTF8 表示的数据, 以及需要多少个字节表示该 UNicode 字符.
    internal var _bytes: (bytes: UInt64, count: Int) {
        let count = self.count
        let mask: UInt64 = 1 &<< (UInt64(truncatingIfNeeded: count) &<< 3) &- 1
        let unbiased = UInt64(truncatingIfNeeded: _biasedBits) &- 0x0101010101010101
        return (unbiased & mask, count)
    }
}
