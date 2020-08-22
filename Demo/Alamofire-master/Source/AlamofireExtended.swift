/// Type that acts as a generic extension point for all `AlamofireExtended` types.
public struct AlamofireExtension<ExtendedType> {
    /// Stores the type or meta-type of any extended type.
    public private(set) var type: ExtendedType
    
    /// Create an instance from the provided value.
    ///
    /// - Parameter type: Instance being extended.
    public init(_ type: ExtendedType) {
        self.type = type
    }
}

/// Protocol describing the `af` extension points for Alamofire extended types.
public protocol AlamofireExtended {
    /// Type being extended.
    associatedtype ExtendedType
    
    /// Static Alamofire extension point.
    static var af: AlamofireExtension<ExtendedType>.Type { get set }
    /// Instance Alamofire extension point.
    var af: AlamofireExtension<ExtendedType> { get set }
}

public extension AlamofireExtended {
    /// Static Alamofire extension point.
    static var af: AlamofireExtension<Self>.Type {
        get { AlamofireExtension<Self>.self }
        set {}
    }
    
    /// Instance Alamofire extension point.
    var af: AlamofireExtension<Self> {
        get { AlamofireExtension(self) }
        set {}
    }
}
