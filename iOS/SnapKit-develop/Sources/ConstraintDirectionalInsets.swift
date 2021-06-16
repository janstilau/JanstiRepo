#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif


#if os(iOS) || os(tvOS)
    @available(iOS 11.0, tvOS 11.0, *)
    public typealias ConstraintDirectionalInsets = NSDirectionalEdgeInsets
#endif
