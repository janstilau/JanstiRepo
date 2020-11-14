internal struct _BridgingBufferHeader {
  internal init(_ count: Int) { self.count = count }
  internal var count: Int
}

// NOTE: older runtimes called this class _BridgingBufferStorage.
// The two must coexist without a conflicting ObjC class name, so it
// was renamed. The old name must not be used in the new runtime.
internal final class __BridgingBufferStorage
  : ManagedBuffer<_BridgingBufferHeader, AnyObject> {
}

internal typealias _BridgingBuffer
  = ManagedBufferPointer<_BridgingBufferHeader, AnyObject>

extension ManagedBufferPointer
where Header == _BridgingBufferHeader, Element == AnyObject {
  internal init(_ count: Int) {
    self.init(
      _uncheckedBufferClass: __BridgingBufferStorage.self,
      minimumCapacity: count)
    self.withUnsafeMutablePointerToHeader {
      $0.initialize(to: Header(count))
    }
  }

  internal var count: Int {
    @inline(__always)
    get {
      return header.count
    }
    @inline(__always)
    set {
      return header.count = newValue
    }
  }

  internal subscript(i: Int) -> Element {
    @inline(__always)
    get {
      return withUnsafeMutablePointerToElements { $0[i] }
    }
  }

  internal var baseAddress: UnsafeMutablePointer<Element> {
    @inline(__always)
    get {
      return withUnsafeMutablePointerToElements { $0 }
    }
  }

  internal var storage: AnyObject? {
    @inline(__always)
    get {
      return buffer
    }
  }
}
