#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif


public protocol ConstraintInsetTarget: ConstraintConstantTarget {
}

extension Int: ConstraintInsetTarget {
}

extension UInt: ConstraintInsetTarget {
}

extension Float: ConstraintInsetTarget {
}

extension Double: ConstraintInsetTarget {
}

extension CGFloat: ConstraintInsetTarget {
}

extension ConstraintInsets: ConstraintInsetTarget {
}

extension ConstraintInsetTarget {

    internal var constraintInsetTargetValue: ConstraintInsets {
        if let amount = self as? ConstraintInsets {
            return amount
        } else if let amount = self as? Float {
            return ConstraintInsets(top: CGFloat(amount), left: CGFloat(amount), bottom: CGFloat(amount), right: CGFloat(amount))
        } else if let amount = self as? Double {
            return ConstraintInsets(top: CGFloat(amount), left: CGFloat(amount), bottom: CGFloat(amount), right: CGFloat(amount))
        } else if let amount = self as? CGFloat {
            return ConstraintInsets(top: amount, left: amount, bottom: amount, right: amount)
        } else if let amount = self as? Int {
            return ConstraintInsets(top: CGFloat(amount), left: CGFloat(amount), bottom: CGFloat(amount), right: CGFloat(amount))
        } else if let amount = self as? UInt {
            return ConstraintInsets(top: CGFloat(amount), left: CGFloat(amount), bottom: CGFloat(amount), right: CGFloat(amount))
        } else {
            return ConstraintInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
    }
    
}
