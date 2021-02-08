//  __ContiguousArrayStorageBase supplies the implementation of the
//  _NSArrayCore API (and thus, NSArray the API) for our
//  _ContiguousArrayStorage<T>.  We can't put this implementation
//  directly on _ContiguousArrayStorage because generic classes can't
//  override Objective-C selectors.
//
//===----------------------------------------------------------------------===//

#if _runtime(_ObjC)
import SwiftShims

/// Returns `true` iff the given `index` is valid as a position, i.e. `0
/// ≤ index ≤ count`.
@usableFromInline @_transparent
internal func _isValidArrayIndex(_ index: Int, count: Int) -> Bool {
    return (index >= 0) && (index <= count)
}

/// Returns `true` iff the given `index` is valid for subscripting, i.e.
/// `0 ≤ index < count`.
@usableFromInline @_transparent
internal func _isValidArraySubscript(_ index: Int, count: Int) -> Bool {
    return (index >= 0) && (index < count)
}



internal class __SwiftNativeNSArrayWithContiguousStorage {
    
    @nonobjc internal override init() { super.init() }
    
    deinit {}
    
    // withSth(block) 这种写法, 非常常见, withSth 是这个方法的逻辑 => get, block 是 get 后的逻辑.
    // 这种在 OC 的时候, 其实会让代码很混乱. 但是 Swift 里面, 可以通过 Block 的类型, 确定 with 函数的类型, 所以用的很广.
    internal func withUnsafeBufferOfObjects<R>(
        _ body: (UnsafeBufferPointer<AnyObject>) throws -> R
    ) rethrows -> R {
        _internalInvariantFailure(
            "Must override withUnsafeBufferOfObjects in derived classes")
    }
}

private let NSNotFound: Int = .max

// 这个类, 是对于 NSArray 的模拟.
// NSArray 本质上, 就是管理一个 [anyobject] 的数组.
// 下面的所有操作, 都是对于这个数组的操作. 被包装到 withUnsafeBufferOfObjects 函数内部了.
extension __SwiftNativeNSArrayWithContiguousStorage {
    @objc internal var count: Int {
        return withUnsafeBufferOfObjects { $0.count }
    }
    
    @nonobjc private func _objectAt(_ index: Int) -> Unmanaged<AnyObject> {
        return withUnsafeBufferOfObjects {
            objects in
            return Unmanaged.passUnretained(objects[index])
        }
    }
    
    dynamic internal func objectAtSubscript(_ index: Int) -> Unmanaged<AnyObject> {
        return _objectAt(index)
    }
    
    dynamic internal func objectAt(_ index: Int) -> Unmanaged<AnyObject> {
        return _objectAt(index)
    }
    
    @objc internal func getObjects(
        _ aBuffer: UnsafeMutablePointer<AnyObject>, range: _SwiftNSRange
    ) {
        return withUnsafeBufferOfObjects {
            objects in
            if objects.isEmpty { return }
            // 这里, 没有引用计数的变化
            UnsafeMutableRawPointer(aBuffer).copyMemory( from: objects.baseAddress! + range.location,
                                                         byteCount: range.length * MemoryLayout<AnyObject>.stride)
        }
    }
    
    internal func countByEnumerating(
        with state: UnsafeMutablePointer<_SwiftNSFastEnumerationState>,
        objects: UnsafeMutablePointer<AnyObject>?, count: Int
    ) -> Int {
        var enumerationState = state.pointee
        
        if enumerationState.state != 0 {
            return 0
        }
        
        return withUnsafeBufferOfObjects {
            objects in
            enumerationState.mutationsPtr = _fastEnumerationStorageMutationsPtr
            enumerationState.itemsPtr =
                AutoreleasingUnsafeMutablePointer(objects.baseAddress)
            enumerationState.state = 1
            state.pointee = enumerationState
            return objects.count
        }
    }
    
    internal func copy(with _: _SwiftNSZone?) -> AnyObject {
        return self
    }
}

@objc internal final class _SwiftNSMutableArray :
    _SwiftNativeNSMutableArray
{
    internal var contents: [AnyObject]
    
    internal init(_ array: [AnyObject]) {
        contents = array
        super.init()
    }
    
    @objc internal var count: Int {
        return contents.count
    }
    
    dynamic internal func objectAtSubscript(_ index: Int) -> Unmanaged<AnyObject> {
        return Unmanaged.passUnretained(contents[index])
    }
    
    dynamic internal func objectAt(_ index: Int) -> Unmanaged<AnyObject> {
        return Unmanaged.passUnretained(contents[index])
    }
    
    @objc internal func getObjects(
        _ aBuffer: UnsafeMutablePointer<AnyObject>, range: _SwiftNSRange
    ) {
        return contents.withContiguousStorageIfAvailable { objects in
            if objects.isEmpty { return }
            UnsafeMutableRawPointer(aBuffer).copyMemory(
                from: objects.baseAddress! + range.location,
                byteCount: range.length * MemoryLayout<AnyObject>.stride)
        }!
    }
    
    internal func countByEnumerating(
        with state: UnsafeMutablePointer<_SwiftNSFastEnumerationState>,
        objects: UnsafeMutablePointer<AnyObject>?, count: Int
    ) -> Int {
        var enumerationState = state.pointee
        
        if enumerationState.state != 0 {
            return 0
        }
        
        return contents.withContiguousStorageIfAvailable {
            objects in
            enumerationState.mutationsPtr = _fastEnumerationStorageMutationsPtr
            enumerationState.itemsPtr =
                AutoreleasingUnsafeMutablePointer(objects.baseAddress)
            enumerationState.state = 1
            state.pointee = enumerationState
            return objects.count
        }!
    }
    
    @objc(copyWithZone:)
    dynamic internal func copy(with _: _SwiftNSZone?) -> AnyObject {
        return contents._bridgeToObjectiveCImpl()
    }
    
    @objc(insertObject:atIndex:)
    dynamic internal func insert(_ anObject: AnyObject, at index: Int) {
        contents.insert(anObject, at: index)
    }
    
    @objc(removeObjectAtIndex:)
    dynamic internal func removeObject(at index: Int) {
        contents.remove(at: index)
    }
    
    @objc(addObject:)
    dynamic internal func add(_ anObject: AnyObject) {
        contents.append(anObject)
    }
    
    @objc(removeLastObject)
    dynamic internal func removeLastObject() {
        if !contents.isEmpty {
            contents.removeLast()
        }
    }
    
    @objc(replaceObjectAtIndex:withObject:)
    dynamic internal func replaceObject(at index: Int, with anObject: AnyObject) {
        //enforces bounds, unlike set equivalent, which can append
        contents[index] = anObject
    }
    
    //Non-core methods overridden for performance
    
    @objc(exchangeObjectAtIndex:withObjectAtIndex:)
    dynamic internal func exchange(at index: Int, with index2: Int) {
        contents.swapAt(index, index2)
    }
    
    @objc(replaceObjectsInRange:withObjects:count:)
    dynamic internal func replaceObjects(in range: _SwiftNSRange,
                                         with objects: UnsafePointer<AnyObject>,
                                         count: Int) {
        let range = range.location ..< range.location + range.length
        let buf = UnsafeBufferPointer(start: objects, count: count)
        if range == contents.startIndex..<contents.endIndex {
            contents = Array(buf)
        } else {
            // We make an Array here to make sure that something is holding onto the
            // objects in `buf`, since replaceSubrange could release them
            contents.replaceSubrange(range, with: Array(buf))
        }
    }
    
    @objc(insertObjects:count:atIndex:)
    dynamic internal func insertObjects(_ objects: UnsafePointer<AnyObject>,
                                        count: Int,
                                        at index: Int) {
        let buf = UnsafeBufferPointer(start: objects, count: count)
        contents.insert(contentsOf: buf, at: index)
    }
    
    @objc(indexOfObjectIdenticalTo:)
    dynamic internal func index(ofObjectIdenticalTo object: AnyObject) -> Int {
        return contents.firstIndex { $0 === object } ?? NSNotFound
    }
    
    @objc(removeObjectsInRange:)
    dynamic internal func removeObjects(in range: _SwiftNSRange) {
        let range = range.location ..< range.location + range.length
        contents.replaceSubrange(range, with: [])
    }
    
    @objc(removeAllObjects)
    dynamic internal func removeAllObjects() {
        contents = []
    }
    
    @objc(setObject:atIndex:)
    dynamic internal func setObject(_ anObject: AnyObject, at index: Int) {
        if index == contents.count {
            contents.append(anObject)
        } else {
            contents[index] = anObject
        }
    }
    
    @objc(setObject:atIndexedSubscript:) dynamic
    internal func setObjectSubscript(_ anObject: AnyObject, at index: Int) {
        if index == contents.count {
            contents.append(anObject)
        } else {
            contents[index] = anObject
        }
    }
}

/// An `NSArray` whose contiguous storage is created and filled, upon
/// first access, by bridging the elements of a Swift `Array`.
///
/// Ideally instances of this class would be allocated in-line in the
/// buffers used for Array storage.
@_fixed_layout // FIXME(sil-serialize-all)
@usableFromInline
@objc internal final class __SwiftDeferredNSArray
: __SwiftNativeNSArrayWithContiguousStorage {
    
    // This stored property should be stored at offset zero.  We perform atomic
    // operations on it.
    //
    // Do not access this property directly.
    @nonobjc
    internal var _heapBufferBridged_DoNotUse: AnyObject?
    
    // When this class is allocated inline, this property can become a
    // computed one.
    @usableFromInline
    @nonobjc
    internal let _nativeStorage: __ContiguousArrayStorageBase
    
    @nonobjc
    internal var _heapBufferBridgedPtr: UnsafeMutablePointer<AnyObject?> {
        return _getUnsafePointerToStoredProperties(self).assumingMemoryBound(
            to: Optional<AnyObject>.self)
    }
    
    internal var _heapBufferBridged: __BridgingBufferStorage? {
        if let ref =
            _stdlib_atomicLoadARCRef(object: _heapBufferBridgedPtr) {
            return unsafeBitCast(ref, to: __BridgingBufferStorage.self)
        }
        return nil
    }
    
    @inlinable // FIXME(sil-serialize-all)
    @nonobjc
    internal init(_nativeStorage: __ContiguousArrayStorageBase) {
        self._nativeStorage = _nativeStorage
    }
    
    internal func _destroyBridgedStorage(_ hb: __BridgingBufferStorage?) {
        if let bridgedStorage = hb {
            let buffer = _BridgingBuffer(bridgedStorage)
            let count = buffer.count
            buffer.baseAddress.deinitialize(count: count)
        }
    }
    
    deinit {
        _destroyBridgedStorage(_heapBufferBridged)
    }
    
    internal override func withUnsafeBufferOfObjects<R>(
        _ body: (UnsafeBufferPointer<AnyObject>) throws -> R
    ) rethrows -> R {
        while true {
            var buffer: UnsafeBufferPointer<AnyObject>
            
            // If we've already got a buffer of bridged objects, just use it
            if let bridgedStorage = _heapBufferBridged {
                let bridgingBuffer = _BridgingBuffer(bridgedStorage)
                buffer = UnsafeBufferPointer(
                    start: bridgingBuffer.baseAddress, count: bridgingBuffer.count)
            }
            
            // If elements are bridged verbatim, the native buffer is all we
            // need, so return that.
            else if let buf = _nativeStorage._withVerbatimBridgedUnsafeBuffer(
                { $0 }
            ) {
                buffer = buf
            }
            else {
                // Create buffer of bridged objects.
                let objects = _nativeStorage._getNonVerbatimBridgingBuffer()
                
                // Atomically store a reference to that buffer in self.
                if !_stdlib_atomicInitializeARCRef(
                    object: _heapBufferBridgedPtr, desired: objects.storage!) {
                    
                    // Another thread won the race.  Throw out our buffer.
                    _destroyBridgedStorage(
                        unsafeDowncast(objects.storage!, to: __BridgingBufferStorage.self))
                }
                continue // Try again
            }
            
            defer { _fixLifetime(self) }
            return try body(buffer)
        }
    }
    
    /// Returns the number of elements in the array.
    ///
    /// This override allows the count to be read without triggering
    /// bridging of array elements.
    @objc
    internal override var count: Int {
        return _nativeStorage.countAndCapacity.count
    }
}
#else
// Empty shim version for non-objc platforms.
@usableFromInline
@_fixed_layout
internal class __SwiftNativeNSArrayWithContiguousStorage {
    @inlinable
    internal init() {}
    
    @inlinable
    deinit {}
}
#endif

/// Base class of the heap buffer backing arrays.  
///
/// NOTE: older runtimes called this _ContiguousArrayStorageBase. The
/// two must coexist, so it was renamed. The old name must not be used
/// in the new runtime.
@usableFromInline
@_fixed_layout
internal class __ContiguousArrayStorageBase
: __SwiftNativeNSArrayWithContiguousStorage {
    
    @usableFromInline
    final var countAndCapacity: _ArrayBody
    
    @inlinable
    @nonobjc
    internal init(_doNotCallMeBase: ()) {
        _internalInvariantFailure("creating instance of __ContiguousArrayStorageBase")
    }
    
    #if _runtime(_ObjC)
    internal override func withUnsafeBufferOfObjects<R>(
        _ body: (UnsafeBufferPointer<AnyObject>) throws -> R
    ) rethrows -> R {
        if let result = try _withVerbatimBridgedUnsafeBuffer(body) {
            return result
        }
        _internalInvariantFailure(
            "Can't use a buffer of non-verbatim-bridged elements as an NSArray")
    }
    
    /// If the stored type is bridged verbatim, invoke `body` on an
    /// `UnsafeBufferPointer` to the elements and return the result.
    /// Otherwise, return `nil`.
    internal func _withVerbatimBridgedUnsafeBuffer<R>(
        _ body: (UnsafeBufferPointer<AnyObject>) throws -> R
    ) rethrows -> R? {
        _internalInvariantFailure(
            "Concrete subclasses must implement _withVerbatimBridgedUnsafeBuffer")
    }
    
    internal func _getNonVerbatimBridgingBuffer() -> _BridgingBuffer {
        _internalInvariantFailure(
            "Concrete subclasses must implement _getNonVerbatimBridgingBuffer")
    }
    
    @objc(mutableCopyWithZone:)
    dynamic internal func mutableCopy(with _: _SwiftNSZone?) -> AnyObject {
        let arr = Array<AnyObject>(_ContiguousArrayBuffer(self))
        return _SwiftNSMutableArray(arr)
    }
    
    @objc(indexOfObjectIdenticalTo:)
    dynamic internal func index(ofObjectIdenticalTo object: AnyObject) -> Int {
        let arr = Array<AnyObject>(_ContiguousArrayBuffer(self))
        return arr.firstIndex { $0 === object } ?? NSNotFound
    }
    #endif
    
    @inlinable
    internal func canStoreElements(ofDynamicType _: Any.Type) -> Bool {
        _internalInvariantFailure(
            "Concrete subclasses must implement canStoreElements(ofDynamicType:)")
    }
    
    /// A type that every element in the array is.
    @inlinable
    internal var staticElementType: Any.Type {
        _internalInvariantFailure(
            "Concrete subclasses must implement staticElementType")
    }
    
    @inlinable
    deinit {
        _internalInvariant(
            self !== _emptyArrayStorage, "Deallocating empty array storage?!")
    }
}
