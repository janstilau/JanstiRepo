#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif


public class ConstraintMakerFinalizable {
    
    internal let description: ConstraintDescription
    
    internal init(_ description: ConstraintDescription) {
        self.description = description
    }
    
    @discardableResult
    public func labeled(_ label: String) -> ConstraintMakerFinalizable {
        self.description.label = label
        return self
    }
    
    public var constraint: Constraint {
        return self.description.constraint!
    }
    
}
