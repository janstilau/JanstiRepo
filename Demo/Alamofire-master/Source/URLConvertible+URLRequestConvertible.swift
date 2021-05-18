import Foundation

/*
 
 */
public protocol URLConvertible {
    func asURL() throws -> URL
}

extension String: URLConvertible {
    // 通过自身, 进行 URL 的生成,  如果失败, 抛出错误.
    public func asURL() throws -> URL {
        guard let url = URL(string: self) else { throw AFError.invalidURL(url: self) }
        return url
    }
}

extension URL: URLConvertible {
    /// Returns `self`.
    public func asURL() throws -> URL { self }
}

extension URLComponents: URLConvertible {
    /// Returns a `URL` if the `self`'s `url` is not nil, otherwise throws.
    ///
    /// - Returns: The `URL` from the `url` property.
    /// - Throws:  An `AFError.invalidURL` instance.
    public func asURL() throws -> URL {
        guard let url = url else { throw AFError.invalidURL(url: self) }
        return url
    }
}

// MARK: -

/*
 可以转化为 URLRequest 的协议
 */
public protocol URLRequestConvertible {
    // 实际上, URLSession 里面, 就是仅仅需要一个 request 而已.
    // request 其实已经包含了网络请求的所有的信息了.
    func asURLRequest() throws -> URLRequest
}

extension URLRequestConvertible {
    /// The `URLRequest` returned by discarding any `Error` encountered.
    public var urlRequest: URLRequest? { try? asURLRequest() }
}

extension URLRequest: URLRequestConvertible {
    public func asURLRequest() throws -> URLRequest { self }
}

// MARK: -

/*
 extension 里面定义的, 一定是 convenience init 方法. 需要调用其他的 init 方法, 来进行最终的初始化操作.
 
 URLConvertible 的真正使用, 也是在这里, 只有这里调用了 .asURL()
 HTTPHeaders 的真正使用, 也是在这里, 只有这里调用了 .dictionary
 HTTPMethod 的真正使用, 也是在这里, 只有这里调用了 .rawValue
 
 以上三种, 体现了三种不同的, 让代码更加稳健的途径.
 URLConvertible, 面向抽象编程, 只要传递过来的对象, 符合协议蓝本就可以.
 HTTPHeaders, 一个特殊的类, 将对于 httpHeader 的操作, 都封装到这个类里面, 提供一个 get 函数, 方便最后真正使用.
 HTTPMethod, 使用类的静态方法, 进行值的获取, 避免用户输入行为. HTTPMethod 本身也是 RawRepresentable 抽象的实现.
 
 */
extension URLRequest {
    public init(url: URLConvertible,
                method: HTTPMethod,
                headers: HTTPHeaders? = nil) throws {
        let url = try url.asURL()
        
        self.init(url: url)
        httpMethod = method.rawValue
        allHTTPHeaderFields = headers?.dictionary
    }
}
