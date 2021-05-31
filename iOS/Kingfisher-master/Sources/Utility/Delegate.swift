import Foundation
/// A class that keeps a weakly reference for `self` when implementing `onXXX` behaviors.
/// Instead of remembering to keep `self` as weak in a stored closure:
///
/// ```swift
/// // MyClass.swift
/// var onDone: (() -> Void)?
/// func done() {
///     onDone?()
/// }
///
/// // ViewController.swift
/// var obj: MyClass?
///
/// func doSomething() {
///     obj = MyClass()
///     obj!.onDone = { [weak self] in
///         self?.reportDone()
///     }
/// }
/// ```
///
/// You can create a `Delegate` and observe on `self`. Now, there is no retain cycle inside:
///
/// ```swift
/// // MyClass.swift
/// let onDone = Delegate<(), Void>()
/// func done() {
///     onDone.call()
/// }
///
/// // ViewController.swift
/// var obj: MyClass?
///
/// func doSomething() {
///     obj = MyClass()
///     obj!.onDone.delegate(on: self) { (self, _)
///         // `self` here is shadowed and does not keep a strong ref.
///         // So you can release both `MyClass` instance and `ViewController` instance.
///         self.reportDone()
///     }
/// }
/// ```
///
public class Delegate<Input, Output> {
    public init() {}
    
    private var block: ((Input) -> Output?)?
    // 这里, 就是设置回调的地方. 存储了回调的 target, 以及回调的行为.
    // 然后, 在容器类里面, 直接调用 call 方法.
    
    // 如果之前, 定义一个 protocol, 那么在宿主里面, 就是 self.delegate?.scrollViewDidScrolled(self)
    // 而使用这个 Delegate 的话, 就是 delegate(theDelegateObj, Block)
    // 也就是说, theDelegateObj 类里面, 主动配置对应的回调闭包, 省略了明显的协议定义的过程.
    public func delegate<T: AnyObject>(on target: T,
                                       block: ((T, Input) -> Output)?) {
        self.block = { [weak target] input in
            guard let target = target else { return nil }
            return block?(target, input)
        }
    }
    
    public func call(_ input: Input) -> Output? {
        return block?(input)
    }
    
    public func callAsFunction(_ input: Input) -> Output? {
        return call(input)
    }
}

extension Delegate where Input == Void {
    public func call() -> Output? {
        return call(())
    }
    
    public func callAsFunction() -> Output? {
        return call()
    }
}

extension Delegate where Input == Void, Output: OptionalProtocol {
    public func call() -> Output {
        return call(())
    }
    
    public func callAsFunction() -> Output {
        return call()
    }
}

extension Delegate where Output: OptionalProtocol {
    public func call(_ input: Input) -> Output {
        if let result = block?(input) {
            return result
        } else {
            return Output._createNil
        }
    }
    
    public func callAsFunction(_ input: Input) -> Output {
        return call(input)
    }
}

public protocol OptionalProtocol {
    static var _createNil: Self { get }
}
extension Optional : OptionalProtocol {
    public static var _createNil: Optional<Wrapped> {
        return nil
    }
}
