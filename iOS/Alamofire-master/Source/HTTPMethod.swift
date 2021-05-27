/// Type representing HTTP methods. Raw `String` value is stored and compared case-sensitively, so
/// `HTTPMethod.get != HTTPMethod(rawValue: "get")`.
///
/// See https://tools.ietf.org/html/rfc7231#section-4.3
/*
 AFN 里面, 直接使用了 Get, Post 这些基本的字符串值, 实际上, HTTPRequest 里面, 也是 String 类型的值.
 但是, 作为数据一定固定的类型值, API 的设计者应该提供一个类, 通过类的方式去获取某个固定值.
 
 RawRepresentable 的提出, 使得该值和原始值的转换, 有了一个统一的接口, 也就是对于使用者非常简便.
 所以, 之后这种固定数据的值, 应该由专门的类进行包装, 而不是让使用者, 再去输入 GET, POST 这些原始数据了.
 直接使用原始数据的后果:
 1. 用户很容易写错, 因为没有 IDE 的支持.
 2. 大小写怎么处理, 有空格怎么处理, 这都给 API 的设计者提供了难题, 而提供一个稳定的数据获取的 API, 能够略去大部分的烦恼问题.
 
 在最终, 变换成为 HTTPRequest 的属性的时候, 还是用的 HTTPRequest 里面规定的数据类型, 也就是 String.
 这里, 直接使用 HTTPMethod RawValue 方法就可以了. RawRepresentable 提供了稳定的抽象.
 */
public struct HTTPMethod: RawRepresentable, Equatable, Hashable {
    /// `CONNECT` method.
    public static let connect = HTTPMethod(rawValue: "CONNECT")
    /// `DELETE` method.
    public static let delete = HTTPMethod(rawValue: "DELETE")
    /// `GET` method.
    public static let get = HTTPMethod(rawValue: "GET")
    /// `HEAD` method.
    public static let head = HTTPMethod(rawValue: "HEAD")
    /// `OPTIONS` method.
    public static let options = HTTPMethod(rawValue: "OPTIONS")
    /// `PATCH` method.
    public static let patch = HTTPMethod(rawValue: "PATCH")
    /// `POST` method.
    public static let post = HTTPMethod(rawValue: "POST")
    /// `PUT` method.
    public static let put = HTTPMethod(rawValue: "PUT")
    /// `TRACE` method.
    public static let trace = HTTPMethod(rawValue: "TRACE")
    
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
