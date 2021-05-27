
/*
    这种写法, 在各个类库已经是非常的流行了.
    通过 af, 获取到一个特殊的值, 这个值里面, 存储了 self.
    然后, 在 af 这个类型上, 进行各种扩展方法和扩展的定义, 限制调教, 是 ExtendedType 的判断.
    
    通过一个明显的值, 给与了外界按时, 后面得到的功能, 是和这个模块息息相关的, 而不是一个到处可以使用的通用方法.
 */


// Type that acts as a generic extension point for all `AlamofireExtended` types.
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


// 协议, 提供一个默认的实现, 就是把自己装进入.
// 固定下 ExtendedType 的类型. 然后根据 ExtendedType 的类型, 编译器可以确定到底有多少扩展方法可以使用.
// 使用效果看来, 和直接在 ExtendedType 上定义方法属性没有太大的区别.
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
