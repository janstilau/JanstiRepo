import Foundation

/*
 AFN 里面, url 都是通过 Stirng 进行传递的.
 但是, 实际上使用的是 URL 类.
 框架并不关心, 到底怎么得到 URL, 只要传递过来的对象, 可以生产出一个 URL 就可以了.
 注意, 这个方法是 throws, 在使用的时候, 都要增加 try 处理.
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
 */
extension URLRequest {
    public init(url: URLConvertible, method: HTTPMethod, headers: HTTPHeaders? = nil) throws {
        let url = try url.asURL()
        
        self.init(url: url)
        
        httpMethod = method.rawValue
        allHTTPHeaderFields = headers?.dictionary
    }
}
