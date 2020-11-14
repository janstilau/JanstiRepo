import SwiftShims

@frozen
@usableFromInline
internal struct _BridgeStorage<NativeClass: AnyObject> {
    @usableFromInline
    internal typealias Native = NativeClass
    
    @usableFromInline
    internal typealias ObjC = AnyObject
    
    // rawValue is passed inout to _isUnique.  Although its value
    // is unchanged, it must appear mutable to the optimizer.
    @usableFromInline
    internal var rawValue: Builtin.BridgeObject
    
    @inlinable
    @inline(__always)
    internal init(native: Native, isFlagged flag: Bool) {
        // Note: Some platforms provide more than one spare bit, but the minimum is
        // a single bit.
        
        _internalInvariant(_usesNativeSwiftReferenceCounting(NativeClass.self))
        
        rawValue = _makeNativeBridgeObject(
            native,
            flag ? (1 as UInt) << _objectPointerLowSpareBitShift : 0)
    }
    
    @inlinable
    @inline(__always)
    internal init(objC: ObjC) {
        _internalInvariant(_usesNativeSwiftReferenceCounting(NativeClass.self))
        rawValue = _makeObjCBridgeObject(objC)
    }
    
    @inlinable
    @inline(__always)
    internal init(native: Native) {
        _internalInvariant(_usesNativeSwiftReferenceCounting(NativeClass.self))
        rawValue = Builtin.reinterpretCast(native)
    }
    
    #if !(arch(i386) || arch(arm))
    @inlinable
    @inline(__always)
    internal init(taggedPayload: UInt) {
        rawValue = _bridgeObject(taggingPayload: taggedPayload)
    }
    #endif
    
    @inlinable
    @inline(__always)
    internal mutating func isUniquelyReferencedNative() -> Bool {
        return _isUnique(&rawValue)
    }
    
    @inlinable
    internal var isNative: Bool {
        @inline(__always) get {
            let result = Builtin.classifyBridgeObject(rawValue)
            return !Bool(Builtin.or_Int1(result.isObjCObject,
                                         result.isObjCTaggedPointer))
        }
    }
    
    @inlinable
    static var flagMask: UInt {
        @inline(__always) get {
            return (1 as UInt) << _objectPointerLowSpareBitShift
        }
    }
    
    @inlinable
    internal var isUnflaggedNative: Bool {
        @inline(__always) get {
            return (_bitPattern(rawValue) &
                (_bridgeObjectTaggedPointerBits | _objCTaggedPointerBits |
                    _objectPointerIsObjCBit | _BridgeStorage.flagMask)) == 0
        }
    }
    
    @inlinable
    internal var isObjC: Bool {
        @inline(__always) get {
            return !isNative
        }
    }
    
    @inlinable
    internal var nativeInstance: Native {
        @inline(__always) get {
            _internalInvariant(isNative)
            return Builtin.castReferenceFromBridgeObject(rawValue)
        }
    }
    
    @inlinable
    internal var unflaggedNativeInstance: Native {
        @inline(__always) get {
            _internalInvariant(isNative)
            _internalInvariant(_nonPointerBits(rawValue) == 0)
            return Builtin.reinterpretCast(rawValue)
        }
    }
    
    @inlinable
    @inline(__always)
    internal mutating func isUniquelyReferencedUnflaggedNative() -> Bool {
        _internalInvariant(isNative)
        return _isUnique_native(&rawValue)
    }
    
    @inlinable
    internal var objCInstance: ObjC {
        @inline(__always) get {
            _internalInvariant(isObjC)
            return Builtin.castReferenceFromBridgeObject(rawValue)
        }
    }
}
