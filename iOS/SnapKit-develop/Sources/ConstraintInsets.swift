#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif


#if os(iOS) || os(tvOS)
    public typealias ConstraintInsets = UIEdgeInsets
#else
    public typealias ConstraintInsets = NSEdgeInsets
#endif
