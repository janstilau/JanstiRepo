/// A type for propagating an unmanaged object reference.
/// When you use this type, you become partially responsible for
/// keeping the object alive.


// https://nshipster.cn/unmanaged/
/*
 API 对于开发者来说不只是把功能点接口暴露出来而已，同时也传达给我们一些其他的信息，比如说接口如何以及为什么要使用某些值。
 因为要传达这些信息，给东西起适当的名字这件事才变成了计算机科学中最难的部分之一，而这也成为好的 API 和不好的 API 的重要区别。
 命名, 是给使用者的强有力的暗示.
 Unmanaged 表示对不清晰的内存管理对象的封装，以及用烫手山芋的方式来管理他们。
 
 目前 iOS 中只有 CoreFoundation 需要手动管理资源.
 为了帮助大家理解 C 函数返回对象是否被调用者持有，苹果使用了 Create 规则 和 Get 规则 命名法.
 使用命名这种方式, 并不是语言或者编译器做的事情, 这仅仅是一套 API 的设计规范. 但是, 如果不遵守这个规范, 自己给自己找麻烦.

 
 一个 Unmanaged<T> 实例封装有一个 类型 T，它在相应范围内持有对该 T 对象的引用。从一个 Unmanaged 实例中获取一个 Swift 值的方法有两种：
 takeRetainedValue()：返回该实例中 Swift 管理的引用，并在调用的同时减少一次引用次数，所以可以按照 Create 规则来对待其返回值。
 takeUnretainedValue()：返回该实例中 Swift 管理的引用而 不减少 引用次数，所以可以按照 Get 规则来对待其返回值。
 在实践中最好不要直接操作 Unmanaged 实例，而是用这两个 take 开头的方法从返回值中拿到绑定的对象。
 */
public struct Unmanaged<Instance: AnyObject> {
    
    // 真正的数据部分, 就是一个引用, 不做引用计数的管理.
    // 所以, 这个类, 首先还是存一个值, 这个值就是指针.
    internal unowned(unsafe) var _value: Instance
    internal init(_private: Instance) { _value = _private }
    
    // 将一个裸指针, 强制转化成为 Instance 类型之后, 然后包装到 Unmanaged 里面.
    // 没有引用计数的操作.
    // Unmanaged 本身是带有 T 类型的, 所以之后的操作, 传进来的 rawPointer, 就是 T 类型的了.
    public static func fromOpaque(_ value: UnsafeRawPointer) -> Unmanaged {
        return Unmanaged(_private: unsafeBitCast(value, to: Instance.self))
    }
    
    // 将自己保存的指针, 转化成为一个裸指针, 里面没有引用计数的操作.
    public func toOpaque() -> UnsafeMutableRawPointer {
        return unsafeBitCast(_value, to: UnsafeMutableRawPointer.self)
    }
    
    // 通过一个指针构建 Unmanaged, 并进行一次 retain.
    public static func passRetained(_ value: Instance) -> Unmanaged {
        return Unmanaged(_private: value).retain()
    }
    
    // 通过一个指针构建 Unmanaged, 没有引用计数的操作.
    public static func passUnretained(_ value: Instance) -> Unmanaged {
        return Unmanaged(_private: value)
    }
    
    // 直接返回.
    public func takeUnretainedValue() -> Instance {
        return _value
    }
    
    // 在返回之前, 会有一次 release 的操作.
    // 这个应该是和 passRetained 配合使用的.
    public func takeRetainedValue() -> Instance {
        let result = _value
        release()
        return result
    }
    
    // 其实就是 NSObject 的 retain. 只不过现在 Swift 里面, 只能使用 Builtin.release 去调用.
    public func retain() -> Unmanaged {
        Builtin.retain(_value)
        return self
    }
    
    // 其实就是 NSObject 的 release. 只不过现在 Swift 里面, 只能使用 Builtin.release 去调用.
    public func release() {
        Builtin.release(_value)
    }
    
    public func autorelease() -> Unmanaged {
        Builtin.autorelease(_value)
        return self
    }
    
    /// Gets the value of the unmanaged referenced as a managed reference without
    /// consuming an unbalanced retain of it and passes it to the closure. Asserts
    /// that there is some other reference ('the owning reference') to the
    /// instance referenced by the unmanaged reference that guarantees the
    /// lifetime of the instance for the duration of the
    /// '_withUnsafeGuaranteedRef' call.
    ///
    /// NOTE: You are responsible for ensuring this by making the owning
    /// reference's lifetime fixed for the duration of the
    /// '_withUnsafeGuaranteedRef' call.
    ///
    /// Violation of this will incur undefined behavior.
    ///
    /// A lifetime of a reference 'the instance' is fixed over a point in the
    /// programm if:
    ///
    /// * There exists a global variable that references 'the instance'.
    ///
    ///   import Foundation
    ///   var globalReference = Instance()
    ///   func aFunction() {
    ///      point()
    ///   }
    ///
    /// Or if:
    ///
    /// * There is another managed reference to 'the instance' whose life time is
    ///   fixed over the point in the program by means of 'withExtendedLifetime'
    ///   dynamically closing over this point.
    ///
    ///   var owningReference = Instance()
    ///   ...
    ///   withExtendedLifetime(owningReference) {
    ///       point($0)
    ///   }
    ///
    /// Or if:
    ///
    /// * There is a class, or struct instance ('owner') whose lifetime is fixed
    ///   at the point and which has a stored property that references
    ///   'the instance' for the duration of the fixed lifetime of the 'owner'.
    ///
    ///  class Owned {
    ///  }
    ///
    ///  class Owner {
    ///    final var owned: Owned
    ///
    ///    func foo() {
    ///        withExtendedLifetime(self) {
    ///            doSomething(...)
    ///        } // Assuming: No stores to owned occur for the dynamic lifetime of
    ///          //           the withExtendedLifetime invocation.
    ///    }
    ///
    ///    func doSomething() {
    ///       // both 'self' and 'owned''s lifetime is fixed over this point.
    ///       point(self, owned)
    ///    }
    ///  }
    ///
    /// The last rule applies transitively through a chain of stored references
    /// and nested structs.
    ///
    /// Examples:
    ///
    ///   var owningReference = Instance()
    ///   ...
    ///   withExtendedLifetime(owningReference) {
    ///     let u = Unmanaged.passUnretained(owningReference)
    ///     for i in 0 ..< 100 {
    ///       u._withUnsafeGuaranteedRef {
    ///         $0.doSomething()
    ///       }
    ///     }
    ///   }
    ///
    ///  class Owner {
    ///    final var owned: Owned
    ///
    ///    func foo() {
    ///        withExtendedLifetime(self) {
    ///            doSomething(Unmanaged.passUnretained(owned))
    ///        }
    ///    }
    ///
    ///    func doSomething(_ u: Unmanaged<Owned>) {
    ///      u._withUnsafeGuaranteedRef {
    ///        $0.doSomething()
    ///      }
    ///    }
    ///  }
    @inlinable // unsafe-performance
    public func _withUnsafeGuaranteedRef<Result>(
        _ body: (Instance) throws -> Result
    ) rethrows -> Result {
        let (guaranteedInstance, token) = Builtin.unsafeGuaranteed(_value)
        let result = try body(guaranteedInstance)
        Builtin.unsafeGuaranteedEnd(token)
        return result
    }
}
