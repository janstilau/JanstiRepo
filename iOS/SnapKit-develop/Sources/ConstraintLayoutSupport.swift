#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif


#if os(iOS) || os(tvOS)
    @available(iOS 8.0, *)
    public typealias ConstraintLayoutSupport = UILayoutSupport
#else
    public class ConstraintLayoutSupport {}
#endif
