//
//  URLConvertible+URLRequestConvertible.swift
//
//  Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

/*
 不再是, 传递一个 URLString, 而是一个对象, 只要这个对象可以变成 URL 就可以了.
 可能是 Swift 中, 对于面向协议编程的推崇.
 面向协议编程, 就是设计者和使用者的一种协调. 使用者不在去按照设计者需要的类型, 提供数据. 而是按照设计者提供的协议, 提供实现了这个协议的数据.
 */

/// Types adopting the `URLConvertible` protocol can be used to construct `URL`s, which can then be used to construct
/// `URLRequests`.
public protocol URLConvertible {
    /// Returns a `URL` from the conforming instance or throws.
    ///
    /// - Returns: The `URL` created from the instance.
    /// - Throws:  Any error thrown while creating the `URL`.
    func asURL() throws -> URL
}

/*
 对于常用的几种数据类型, 协议的提供者, 有责任提供他们的 URLConvertible 实现.
 */

extension String: URLConvertible {
    /// Returns a `URL` if `self` can be used to initialize a `URL` instance, otherwise throws.
    ///
    /// - Returns: The `URL` initialized with `self`.
    /// - Throws:  An `AFError.invalidURL` instance.
    public func asURL() throws -> URL {
        /*
         这个过程可能出错, 所以, 进行了 throw 的处理.
         */
        guard let url = URL(string: self) else { throw AFError.invalidURL(url: self) }

        return url
    }
}

extension URL: URLConvertible {
    /// Returns `self`.
    /*
     这个过程不会出错, 但是协议实现的 throws 不可以丢弃.
     */
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

/// Types adopting the `URLRequestConvertible` protocol can be used to safely construct `URLRequest`s.
/*
 这个的思路和上面一直, URLRequest 的生成, 变成了各个对象的能力. 只要拥有这个能力, 就能传递到对应的 API 上.
 */
public protocol URLRequestConvertible {
    /// Returns a `URLRequest` or throws if an `Error` was encountered.
    ///
    /// - Returns: A `URLRequest`.
    /// - Throws:  Any error thrown while constructing the `URLRequest`.
    func asURLRequest() throws -> URLRequest
}

extension URLRequestConvertible {
    /// The `URLRequest` returned by discarding any `Error` encountered.
    public var urlRequest: URLRequest? { try? asURLRequest() }
}

extension URLRequest: URLRequestConvertible {
    /// Returns `self`.
    public func asURLRequest() throws -> URLRequest { self }
}

// MARK: -

/*
 URLRequest 的便捷的生成方法.
 上面的三个协议, 就是在这里使用.
 URLRequest 生成的时候, 直接调用协议的方法, 拿取对应的值, 构造对应的 URLRequest 对象.
 */

extension URLRequest {
    /// Creates an instance with the specified `url`, `method`, and `headers`.
    ///
    /// - Parameters:
    ///   - url:     The `URLConvertible` value.
    ///   - method:  The `HTTPMethod`.
    ///   - headers: The `HTTPHeaders`, `nil` by default.
    /// - Throws:    Any error thrown while converting the `URLConvertible` to a `URL`.
    public init(url: URLConvertible, method: HTTPMethod, headers: HTTPHeaders? = nil) throws {
        let url = try url.asURL()
        self.init(url: url)
        httpMethod = method.rawValue
        // 这里, 直接将 headers 所代表的字典, 赋值给了 allHTTPHeaderFields.
        allHTTPHeaderFields = headers?.dictionary
    }
}
