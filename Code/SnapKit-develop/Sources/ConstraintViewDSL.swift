#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif

/*
    各种, 和 base 相关的操作, 直接转交给了 base.
    这是没有问题的, 因为, 就算是 base 上面的 category, 也是仅仅能够使用公开的属性方法.
    所以, bsse 转交, 和自己调用, 在封装看来, 没有变化.
    从 lazy 的实现, 可以看出, 这是苹果的实现 API 的思路.
 */


public struct ConstraintViewDSL: ConstraintAttributesDSL {
    
    @discardableResult
    public func prepareConstraints(_ closure: (_ make: ConstraintMaker) -> Void) -> [Constraint] {
        return ConstraintMaker.prepareConstraints(item: self.view, closure: closure)
    }
    
    // 外界定义的闭包, 仅仅是一个参数而已, 真正的设置约束的过程, 是在 ConstraintMaker.makeConstraints 的内部.
    public func makeConstraints(_ closure: (_ make: ConstraintMaker) -> Void) {
        ConstraintMaker.makeConstraints(item: self.view, closure: closure)
    }
    
    public func remakeConstraints(_ closure: (_ make: ConstraintMaker) -> Void) {
        ConstraintMaker.remakeConstraints(item: self.view, closure: closure)
    }
    
    public func updateConstraints(_ closure: (_ make: ConstraintMaker) -> Void) {
        ConstraintMaker.updateConstraints(item: self.view, closure: closure)
    }
    
    public func removeConstraints() {
        ConstraintMaker.removeConstraints(item: self.view)
    }
    
    public var contentHuggingHorizontalPriority: Float {
        get {
            return self.view.contentHuggingPriority(for: .horizontal).rawValue
        }
        // nonmutating 关键字, 表示在关键字修饰的方法中, 不会修改当前结构体的属性值,
        nonmutating set {
            self.view.setContentHuggingPriority(LayoutPriority(rawValue: newValue), for: .horizontal)
        }
    }
    
    public var contentHuggingVerticalPriority: Float {
        get {
            return self.view.contentHuggingPriority(for: .vertical).rawValue
        }
        nonmutating set {
            self.view.setContentHuggingPriority(LayoutPriority(rawValue: newValue), for: .vertical)
        }
    }
    
    public var contentCompressionResistanceHorizontalPriority: Float {
        get {
            return self.view.contentCompressionResistancePriority(for: .horizontal).rawValue
        }
        nonmutating set {
            self.view.setContentCompressionResistancePriority(LayoutPriority(rawValue: newValue), for: .horizontal)
        }
    }
    
    public var contentCompressionResistanceVerticalPriority: Float {
        get {
            return self.view.contentCompressionResistancePriority(for: .vertical).rawValue
        }
        nonmutating set {
            self.view.setContentCompressionResistancePriority(LayoutPriority(rawValue: newValue), for: .vertical)
        }
    }
    
    public var target: AnyObject? {
        return self.view
    }
    
    internal let view: ConstraintView
    
    internal init(view: ConstraintView) {
        self.view = view
    }
}
