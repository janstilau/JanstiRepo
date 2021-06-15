#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif


#if os(iOS) || os(tvOS)
    @available(iOS 9.0, *)
    public typealias ConstraintLayoutGuide = UILayoutGuide
#else
    @available(OSX 10.11, *)
    public typealias ConstraintLayoutGuide = NSLayoutGuide
#endif
