#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif


@available(iOS 9.0, OSX 10.11, *)
public struct ConstraintLayoutGuideDSL: ConstraintAttributesDSL {
    
    @discardableResult
    public func prepareConstraints(_ closure: (_ make: ConstraintMaker) -> Void) -> [Constraint] {
        return ConstraintMaker.prepareConstraints(item: self.guide, closure: closure)
    }
    
    public func makeConstraints(_ closure: (_ make: ConstraintMaker) -> Void) {
        ConstraintMaker.makeConstraints(item: self.guide, closure: closure)
    }
    
    public func remakeConstraints(_ closure: (_ make: ConstraintMaker) -> Void) {
        ConstraintMaker.remakeConstraints(item: self.guide, closure: closure)
    }
    
    public func updateConstraints(_ closure: (_ make: ConstraintMaker) -> Void) {
        ConstraintMaker.updateConstraints(item: self.guide, closure: closure)
    }
    
    public func removeConstraints() {
        ConstraintMaker.removeConstraints(item: self.guide)
    }
    
    public var target: AnyObject? {
        return self.guide
    }
    
    internal let guide: ConstraintLayoutGuide
    
    internal init(guide: ConstraintLayoutGuide) {
        self.guide = guide
        
    }
    
}
