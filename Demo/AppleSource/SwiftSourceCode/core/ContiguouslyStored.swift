@usableFromInline
internal protocol _HasContiguousBytes {
    func withUnsafeBytes<R>(
        _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R
    
    var _providesContiguousBytesNoCopy: Bool { get }
}
extension _HasContiguousBytes {
    @inlinable
    var _providesContiguousBytesNoCopy: Bool {
        @inline(__always) get { return true }
    }
}
extension Array: _HasContiguousBytes {
    @inlinable
    var _providesContiguousBytesNoCopy: Bool {
        @inline(__always) get {
            #if _runtime(_ObjC)
            return _buffer._isNative
            #else
            return true
            #endif
        }
    }
}
extension ContiguousArray: _HasContiguousBytes {}
extension UnsafeBufferPointer: _HasContiguousBytes {
    @inlinable @inline(__always)
    func withUnsafeBytes<R>(
        _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R {
        let ptr = UnsafeRawPointer(self.baseAddress)
        let len = self.count &* MemoryLayout<Element>.stride
        return try body(UnsafeRawBufferPointer(start: ptr, count: len))
    }
}
extension UnsafeMutableBufferPointer: _HasContiguousBytes {
    @inlinable @inline(__always)
    func withUnsafeBytes<R>(
        _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R {
        let ptr = UnsafeRawPointer(self.baseAddress)
        let len = self.count &* MemoryLayout<Element>.stride
        return try body(UnsafeRawBufferPointer(start: ptr, count: len))
    }
}
extension UnsafeRawBufferPointer: _HasContiguousBytes {
    @inlinable @inline(__always)
    func withUnsafeBytes<R>(
        _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R {
        return try body(self)
    }
}
extension UnsafeMutableRawBufferPointer: _HasContiguousBytes {
    @inlinable @inline(__always)
    func withUnsafeBytes<R>(
        _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R {
        return try body(UnsafeRawBufferPointer(self))
    }
}
extension String: _HasContiguousBytes {
    @inlinable
    internal var _providesContiguousBytesNoCopy: Bool {
        @inline(__always) get { return self._guts.isFastUTF8 }
    }
    
    @inlinable @inline(__always)
    internal func withUnsafeBytes<R>(
        _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R {
        var copy = self
        return try copy.withUTF8 { return try body(UnsafeRawBufferPointer($0)) }
    }
}
extension Substring: _HasContiguousBytes {
    @inlinable
    internal var _providesContiguousBytesNoCopy: Bool {
        @inline(__always) get { return self._wholeGuts.isFastUTF8 }
    }
    
    @inlinable @inline(__always)
    internal func withUnsafeBytes<R>(
        _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R {
        var copy = self
        return try copy.withUTF8 { return try body(UnsafeRawBufferPointer($0)) }
    }
}
