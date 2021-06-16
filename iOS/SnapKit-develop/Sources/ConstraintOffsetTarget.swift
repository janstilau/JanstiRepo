#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif


public protocol ConstraintOffsetTarget: ConstraintConstantTarget {
}

extension Int: ConstraintOffsetTarget {
}

extension UInt: ConstraintOffsetTarget {
}

extension Float: ConstraintOffsetTarget {
}

extension Double: ConstraintOffsetTarget {
}

extension CGFloat: ConstraintOffsetTarget {
}

extension ConstraintOffsetTarget {
    
    internal var constraintOffsetTargetValue: CGFloat {
        let offset: CGFloat
        if let amount = self as? Float {
            offset = CGFloat(amount)
        } else if let amount = self as? Double {
            offset = CGFloat(amount)
        } else if let amount = self as? CGFloat {
            offset = CGFloat(amount)
        } else if let amount = self as? Int {
            offset = CGFloat(amount)
        } else if let amount = self as? UInt {
            offset = CGFloat(amount)
        } else {
            offset = 0.0
        }
        return offset
    }
    
}
