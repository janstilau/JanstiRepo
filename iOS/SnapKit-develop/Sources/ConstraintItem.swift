#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif


public final class ConstraintItem {
    
    internal weak var target: AnyObject?
    internal let attributes: ConstraintAttributes
    
    internal init(target: AnyObject?, attributes: ConstraintAttributes) {
        self.target = target
        self.attributes = attributes
    }
    
    internal var layoutConstraintItem: LayoutConstraintItem? {
        return self.target as? LayoutConstraintItem
    }
    
}

public func ==(lhs: ConstraintItem, rhs: ConstraintItem) -> Bool {
    // pointer equality
    guard lhs !== rhs else {
        return true
    }
    
    // must both have valid targets and identical attributes
    guard let target1 = lhs.target,
          let target2 = rhs.target,
          target1 === target2 && lhs.attributes == rhs.attributes else {
            return false
    }
    
    return true
}
