
// OC 的手动内存管理的引入, 目前不太清楚, 什么时候, 会用到这个类.
@frozen
public struct Unmanaged<Instance: AnyObject> {
    @usableFromInline
    // 必须是一个类的对象, 因为这个类, 主要做的是内存控制. 必须是一个引用值.
    /*
     当unowned（safe）引用的对象被dealloc之后，如果再次访问这个对象，将会抛出一个异常来终止程序(访问之前会进行检查，如果所引用的对象已经被release，就抛出个异常，这也行就是safe的意思吧)
     但unowned（unsafe）不同，当unowned（unsafe）引用的对象被dealloc之后，如果再次访问这个内存，会出现三种情况：（不会检查，直接访问，这也许就是unsafe的意思吧）
     1 内存没有被改变点-->输出原来的值
     2 内存被改变掉-->crash
     3 内存被同类型对象覆盖-->不会crash，到使用的内存模型确实新对象的。
     参考之前的 zombie 的设计, safe 这件事, 会耗费性能.
     */
    // 这里, 和自己的想法有点差异. 内部使用的存储属性, 就应该使用 _ 开头作为存储.
    // 然后外界使用的, 使用 计算属性包一层, 或者 不加_ 作为存储属性.
    internal unowned(unsafe) var _value: Instance
    
    @usableFromInline @_transparent
    internal init(_private: Instance) { _value = _private }
    
    // 存一个 void 指针, 转变成为 Instance 的指针. 调用 init(_private) 方法, 生成盒子对象.
    @_transparent
    public static func fromOpaque(
        @_nonEphemeral _ value: UnsafeRawPointer
    ) -> Unmanaged {
        return Unmanaged(_private: unsafeBitCast(value, to: Instance.self))
    }
    
    // 将自己管理的对象, 转变成为了一个 可变的 void 指针.
    @_transparent
    public func toOpaque() -> UnsafeMutableRawPointer {
        return unsafeBitCast(_value, to: UnsafeMutableRawPointer.self)
    }
    
    // retain 一个对象.
    // 从这里可以看到. Unmanaged 保持值语义的行为.
    @_transparent
    public static func passRetained(_ value: Instance) -> Unmanaged {
        return Unmanaged(_private: value).retain()
    }
    
    @_transparent
    public static func passUnretained(_ value: Instance) -> Unmanaged {
        return Unmanaged(_private: value)
    }
    
    // 返回 void 指针.
    @_transparent // unsafe-performance
    public func takeUnretainedValue() -> Instance {
        return _value
    }
    
    /// Gets the value of this unmanaged reference as a managed
    /// reference and consumes an unbalanced retain of it.
    ///
    /// This is useful when a function returns an unmanaged reference
    /// and you know that you're responsible for releasing the result.
    ///
    /// - Returns: The object referenced by this `Unmanaged` instance.
    @_transparent // unsafe-performance
    public func takeRetainedValue() -> Instance {
        let result = _value
        release()
        return result
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
    @_transparent
    public func _withUnsafeGuaranteedRef<Result>(
        _ body: (Instance) throws -> Result
    ) rethrows -> Result {
        var tmp = self
        // Builtin.convertUnownedUnsafeToGuaranteed expects to have a base value
        // that the +0 value depends on. In this case, we are assuming that is done
        // for us opaquely already. So, the builtin will emit a mark_dependence on a
        // trivial object. The optimizer knows to eliminate that so we do not have
        // any overhead from this.
        let fakeBase: Int? = nil
        return try body(Builtin.convertUnownedUnsafeToGuaranteed(fakeBase,
                                                                 &tmp._value))
    }
    
    /// Performs an unbalanced retain of the object.
    @_transparent
    public func retain() -> Unmanaged {
        Builtin.retain(_value)
        return self
    }
    
    /// Performs an unbalanced release of the object.
    @_transparent
    public func release() {
        Builtin.release(_value)
    }
    
    @_transparent
    public func autorelease() -> Unmanaged {
        Builtin.autorelease(_value)
        return self
    }
}
