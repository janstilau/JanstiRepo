
// String 对于 Collection 的实现.

import SwiftShims

extension String: BidirectionalCollection {
    public typealias IndexDistance = Int
    public typealias SubSequence = Substring
    public typealias Element = Character
    public var startIndex: Index { return _guts.startIndex }
    public var endIndex: Index { return _guts.endIndex }
    public var count: Int {
        return distance(from: startIndex, to: endIndex)
    }
    
    // 这里, 会保证, Index 是 Unicode 可见新语义的.
    public func index(after i: Index) -> Index {
        let i = _guts.scalarAlign(i)
        let stride = _characterStride(startingAt: i)
        let nextOffset = i._encodedOffset &+ stride
        let nextStride = _characterStride(
            startingAt: Index(_encodedOffset: nextOffset)._scalarAligned)
        return Index(
            encodedOffset: nextOffset, characterStride: nextStride)._scalarAligned
    }
    
    public func index(before i: Index) -> Index {
        let i = _guts.scalarAlign(i)
        let stride = _characterStride(endingAt: i)
        let priorOffset = i._encodedOffset &- stride
        return Index(
            encodedOffset: priorOffset, characterStride: stride)._scalarAligned
    }
    
    public func index(_ i: Index, offsetBy n: IndexDistance) -> Index {
        return _index(i, offsetBy: n)
    }
    
    public func index(
        _ i: Index,
        offsetBy n: IndexDistance,
        limitedBy limit: Index
    ) -> Index? {
        return _index(i, offsetBy: n, limitedBy: limit)
    }
    
    // 这里就是遍历获取 distance
    public func distance(from start: Index, to end: Index) -> IndexDistance {
        return _distance(from: _guts.scalarAlign(start), to: _guts.scalarAlign(end))
    }
    
    public subscript(i: Index) -> Character {
        let i = _guts.scalarAlign(i)
        let distance = _characterStride(startingAt: i)
        return _guts.errorCorrectedCharacter(
            startingAt: i._encodedOffset,
            endingAt: i._encodedOffset &+ distance)
    }
    
    internal func _characterStride(startingAt i: Index) -> Int {
        _internalInvariant_5_1(i._isScalarAligned)
        
        // Fast check if it's already been measured, otherwise check resiliently
        if let d = i.characterStride { return d }
        
        if i == endIndex { return 0 }
        
        return _guts._opaqueCharacterStride(startingAt: i._encodedOffset)
    }
    
    @inlinable @inline(__always)
    internal func _characterStride(endingAt i: Index) -> Int {
        _internalInvariant_5_1(i._isScalarAligned)
        
        if i == startIndex { return 0 }
        
        return _guts._opaqueCharacterStride(endingAt: i._encodedOffset)
    }
}

extension String {
    
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        internal var _guts: _StringGuts
        internal var _position: Int = 0
        internal var _end: Int
        
        internal init(_ guts: _StringGuts) {
            self._end = guts.count
            self._guts = guts
        }
        
        public mutating func next() -> Character? {
            guard _fastPath(_position < _end) else { return nil }
            
            let len = _guts._opaqueCharacterStride(startingAt: _position)
            let nextPosition = _position &+ len
            let result = _guts.errorCorrectedCharacter(
                startingAt: _position, endingAt: nextPosition)
            _position = nextPosition
            return result
        }
    }
    
    public __consuming func makeIterator() -> Iterator {
        return Iterator(_guts)
    }
}

