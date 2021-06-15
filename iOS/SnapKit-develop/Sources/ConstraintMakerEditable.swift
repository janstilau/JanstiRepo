#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif

// Editable 指的是, 可以设置 multiplier 和 constant
public class ConstraintMakerEditable: ConstraintMakerPrioritizable {

    @discardableResult
    public func multipliedBy(_ amount: ConstraintMultiplierTarget) -> ConstraintMakerEditable {
        self.description.multiplier = amount
        return self
    }
    
    @discardableResult
    public func dividedBy(_ amount: ConstraintMultiplierTarget) -> ConstraintMakerEditable {
        return self.multipliedBy(1.0 / amount.constraintMultiplierTargetValue)
    }
    
    @discardableResult
    public func offset(_ amount: ConstraintOffsetTarget) -> ConstraintMakerEditable {
        self.description.constant = amount.constraintOffsetTargetValue
        return self
    }
    
    @discardableResult
    public func inset(_ amount: ConstraintInsetTarget) -> ConstraintMakerEditable {
        self.description.constant = amount.constraintInsetTargetValue
        return self
    }
    
    #if os(iOS) || os(tvOS)
    @discardableResult
    @available(iOS 11.0, tvOS 11.0, *)
    public func inset(_ amount: ConstraintDirectionalInsetTarget) -> ConstraintMakerEditable {
        self.description.constant = amount.constraintDirectionalInsetTargetValue
        return self
    }
    #endif
}
