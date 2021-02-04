import SwiftShims

extension String: Hashable {
    /// Hashes the essential components of this value by feeding them into the
    /// given hasher.
    ///
    /// - Parameter hasher: The hasher to use when combining the components
    ///   of this instance.
    public func hash(into hasher: inout Hasher) {
        if _fastPath(self._guts.isNFCFastUTF8) {
            self._guts.withFastUTF8 {
                hasher.combine(bytes: UnsafeRawBufferPointer($0))
            }
            hasher.combine(0xFF as UInt8) // terminator
        } else {
            _gutsSlice._normalizedHash(into: &hasher)
        }
    }
}

extension StringProtocol {
    /// Hashes the essential components of this value by feeding them into the
    /// given hasher.
    ///
    /// - Parameter hasher: The hasher to use when combining the components
    ///   of this instance.
    @_specialize(where Self == String)
    @_specialize(where Self == Substring)
    public func hash(into hasher: inout Hasher) {
        _gutsSlice._normalizedHash(into: &hasher)
    }
}

extension _StringGutsSlice {
    @_effects(releasenone) @inline(never) // slow-path
    internal func _normalizedHash(into hasher: inout Hasher) {
        if self.isNFCFastUTF8 {
            self.withFastUTF8 {
                hasher.combine(bytes: UnsafeRawBufferPointer($0))
            }
        } else {
            _withNFCCodeUnits {
                hasher.combine($0)
            }
        }
        hasher.combine(0xFF as UInt8) // terminator
    }
}

