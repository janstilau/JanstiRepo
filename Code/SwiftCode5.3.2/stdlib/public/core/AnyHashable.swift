
// 这是一个模板方法预埋点, 目前没有想到业务上使用的必要.
public protocol _HasCustomAnyHashableRepresentation {
    __consuming func _toCustomAnyHashable() -> AnyHashable?
}


// 一个内部协议, 用_标明, 这个协议, 不应该抛出当前的功能的业务范围.
internal protocol _AnyHashableBox {
    var _canonicalBox: _AnyHashableBox { get }
    
    func _isEqual(to box: _AnyHashableBox) -> Bool?
    var _hashValue: Int { get }
    func _hash(into hasher: inout Hasher)
    func _rawHashValue(_seed: Int) -> Int
    
    var _base: Any { get }
    func _unbox<T: Hashable>() -> T?
    func _downCastConditional<T>(into result: UnsafeMutablePointer<T>) -> Bool
}

// 默认返回 self. 当自定义 _AnyHashableBox 可以提供更好的实现.
extension _AnyHashableBox {
    var _canonicalBox: _AnyHashableBox {
        return self
    }
}

// 这也是一个 struct. 但是, 它里面存储一个 Hashable 值, 作为 base.
internal struct _ConcreteHashableBox<Base: Hashable>: _AnyHashableBox {
    internal var _baseHashable: Base
    internal init(_ base: Base) {
        self._baseHashable = base
    }
    
    internal func _unbox<T: Hashable>() -> T? {
        return (self as _AnyHashableBox as? _ConcreteHashableBox<T>)?._baseHashable
    }
    
    // 最终, 还是使用了 hashable base 的 == 判断.
    internal func _isEqual(to rhs: _AnyHashableBox) -> Bool? {
        if let rhs: Base = rhs._unbox() {
            return _baseHashable == rhs
        }
        return nil
    }
    
    internal var _hashValue: Int {
        return _baseHashable.hashValue
    }
    
    func _hash(into hasher: inout Hasher) {
        _baseHashable.hash(into: &hasher)
    }
    
    func _rawHashValue(_seed: Int) -> Int {
        return _baseHashable._rawHashValue(seed: _seed)
    }
    
    internal var _base: Any {
        return _baseHashable
    }
    
    func _downCastConditional<T>(into result: UnsafeMutablePointer<T>) -> Bool {
        guard let value = _baseHashable as? T else { return false }
        result.initialize(to: value)
        return true
    }
}

// 这本来就是一个 struct, 如果直接将 base 存在 AnyHashable 有什么问题吗 ????
public struct AnyHashable {
    
    internal var _box: _AnyHashableBox
    internal init(_box box: _AnyHashableBox) {
        self._box = box
    }
    
    // 传递一个 hashable 的值来, 在内部创建一个包装的盒子.
    internal init<H: Hashable>(_usingDefaultRepresentationOf base: H) {
        self._box = _ConcreteHashableBox(base)
    }
    public var base: Any {
        return _box._base
    }
    
    /// Perform a downcast directly on the internal boxed representation.
    ///
    /// This avoids the intermediate re-boxing we would get if we just did
    /// a downcast on `base`.
    internal
    func _downCastConditional<T>(into result: UnsafeMutablePointer<T>) -> Bool {
        // Attempt the downcast.
        if _box._downCastConditional(into: result) { return true }
        
        #if _runtime(_ObjC)
        // Bridge to Objective-C and then attempt the cast from there.
        // FIXME: This should also work without the Objective-C runtime.
        if let value = _bridgeAnythingToObjectiveC(_box._base) as? T {
            result.initialize(to: value)
            return true
        }
        #endif
        
        return false
    }
}

// AnyHashable is A type-erased hashable value.
// 之所以能够 erase, 就是因为, 它做了一层封装. 将真正的 HashAble 的数据, 放到了 box 里面, 而 hash, == 等操作, 还是会拿到这个数据进行处理.
extension AnyHashable: Equatable {
    public static func == (lhs: AnyHashable, rhs: AnyHashable) -> Bool {
        return lhs._box._canonicalBox._isEqual(to: rhs._box._canonicalBox) ?? false
    }
}

extension AnyHashable: Hashable {
    public var hashValue: Int {
        return _box._canonicalBox._hashValue
    }
    
    public func hash(into hasher: inout Hasher) {
        _box._canonicalBox._hash(into: &hasher)
    }
    
    public func _rawHashValue(seed: Int) -> Int {
        return _box._canonicalBox._rawHashValue(_seed: seed)
    }
}
