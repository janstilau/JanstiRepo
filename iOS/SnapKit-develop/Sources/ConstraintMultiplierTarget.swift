#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif


public protocol ConstraintMultiplierTarget {
    
    var constraintMultiplierTargetValue: CGFloat { get }
    
}

extension Int: ConstraintMultiplierTarget {
    
    public var constraintMultiplierTargetValue: CGFloat {
        return CGFloat(self)
    }
    
}

extension UInt: ConstraintMultiplierTarget {
    
    public var constraintMultiplierTargetValue: CGFloat {
        return CGFloat(self)
    }
    
}

extension Float: ConstraintMultiplierTarget {
    
    public var constraintMultiplierTargetValue: CGFloat {
        return CGFloat(self)
    }
    
}

extension Double: ConstraintMultiplierTarget {
    
    public var constraintMultiplierTargetValue: CGFloat {
        return CGFloat(self)
    }
    
}

extension CGFloat: ConstraintMultiplierTarget {
    
    public var constraintMultiplierTargetValue: CGFloat {
        return self
    }
    
}
