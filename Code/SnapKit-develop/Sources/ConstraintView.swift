#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif


#if os(iOS) || os(tvOS)
    public typealias ConstraintView = UIView
#else
    public typealias ConstraintView = NSView
#endif
