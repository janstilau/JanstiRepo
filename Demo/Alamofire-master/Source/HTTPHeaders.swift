//
//  HTTPHeaders.swift
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
 HTTPHeaders, 应该是一个字典
 这里, 作者将这个东西变为了一个数组.
 在 AFN 里面, 作者仅仅是在构建 Request 的过程中, 将 header 字典里面的值, 一个个的赋值到了 forHTTPHeaderField 中去了.
 */
public struct HTTPHeaders {
    private var headers: [HTTPHeader] = []

    /// Creates an empty instance.
    public init() {}

    /// Creates an instance from an array of `HTTPHeader`s. Duplicate case-insensitive names are collapsed into the last
    /// name and value encountered.
    /*
     构造函数中, 也是使用的 update 方法进行的操作.
     */
    public init(_ headers: [HTTPHeader]) {
        self.init()
        headers.forEach { update($0) }
    }

    /// Creates an instance from a `[String: String]`. Duplicate case-insensitive names are collapsed into the last name
    /// and value encountered.
    public init(_ dictionary: [String: String]) {
        self.init()
        dictionary.forEach { update(HTTPHeader(name: $0.key, value: $0.value)) }
    }

    /// Case-insensitively updates or appends an `HTTPHeader` into the instance using the provided `name` and `value`.
    ///
    /// - Parameters:
    ///   - name:  The `HTTPHeader` name.
    ///   - value: The `HTTPHeader value.
    /*
     Update 方法, 是 primitive 方法. 所有的逻辑, 都归到这个方法, 然后 Update 的逻辑修改, 会影响到其他的所有的方法.
     */
    public mutating func add(name: String, value: String) {
        update(HTTPHeader(name: name, value: value))
    }

    /// Case-insensitively updates or appends the provided `HTTPHeader` into the instance.
    ///
    /// - Parameter header: The `HTTPHeader` to update or append.
    public mutating func add(_ header: HTTPHeader) {
        update(header)
    }

    /// Case-insensitively updates or appends an `HTTPHeader` into the instance using the provided `name` and `value`.
    ///
    /// - Parameters:
    ///   - name:  The `HTTPHeader` name.
    ///   - value: The `HTTPHeader value.
    public mutating func update(name: String, value: String) {
        update(HTTPHeader(name: name, value: value))
    }

    /// Case-insensitively updates or appends the provided `HTTPHeader` into the instance.
    ///
    /// - Parameter header: The `HTTPHeader` to update or append.
    /*
     非常 Swift 的写法. 首先, 使用 Guard 进行条件的判断.
     */
    public mutating func update(_ header: HTTPHeader) {
        guard let index = headers.index(of: header.name) else {
            headers.append(header)
            return
        }
        // Swift 版本的 Array 替换的操作.
        headers.replaceSubrange(index...index, with: [header])
    }

    /// Case-insensitively removes an `HTTPHeader`, if it exists, from the instance.
    ///
    /// - Parameter name: The name of the `HTTPHeader` to remove.
    /*
     Array 的下标访问, 是由程序员控制的安全性. 所以, 所有的下标访问, 都应该有程序员先进行校验的工作.
     */
    public mutating func remove(name: String) {
        guard let index = headers.index(of: name) else { return }

        headers.remove(at: index)
    }

    /// Sort the current instance by header name.
    public mutating func sort() {
        headers.sort { $0.name < $1.name }
    }

    /// Returns an instance sorted by header name.
    ///
    /// - Returns: A copy of the current instance sorted by name.
    /*
     sort 和 sorted 的, 对应着可变和不可变之分.
     */
    public func sorted() -> HTTPHeaders {
        HTTPHeaders(headers.sorted { $0.name < $1.name })
    }

    /// Case-insensitively find a header's value by name.
    ///
    /// - Parameter name: The name of the header to search for, case-insensitively.
    ///
    /// - Returns:        The value of header, if it exists.
    public func value(for name: String) -> String? {
        guard let index = headers.index(of: name) else { return nil }
        return headers[index].value
    }

    /// Case-insensitively access the header with the given name.
    ///
    /// - Parameter name: The name of the header.
    /*
     因为, Swift 可以复写下标方法, 所以, 这个类就如同字典来进行操作.
     在 Set 方法里面, 根据 value 的 nil 与否, 来判断是进行删除操作, 还是更新操作.
     */
    public subscript(_ name: String) -> String? {
        get { value(for: name) }
        set {
            if let value = newValue {
                update(name: name, value: value)
            } else {
                remove(name: name)
            }
        }
    }

    /// The dictionary representation of all headers.
    ///
    /// This representation does not preserve the current order of the instance.
    public var dictionary: [String: String] {
        let namesAndValues = headers.map { ($0.name, $0.value) }

        return Dictionary(namesAndValues, uniquingKeysWith: { _, last in last })
    }
}

/*
 init(dictionaryLiteral elements: (Self.Key, Self.Value)...)
 从这里可以看出来, 字典字面量初始化, 就是一个 元组 的数组, 这个元组的第一个值是 key, 这个元组的第二个值是 value.
 因为, 这个初始化方法, 限制了类型, 编译器会帮助我们, 只有是 (String, String) 类型的元组组成的数组, 才会调用下面的构造方法.
 */
extension HTTPHeaders: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, String)...) {
        self.init()

        elements.forEach { update(name: $0.0, value: $0.1) }
    }
}

/*
 只有, HTTPHeader 组成的数组, 才会调用下面的初始化方法.
 */
extension HTTPHeaders: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: HTTPHeader...) {
        self.init(elements)
    }
}

extension HTTPHeaders: Sequence {
    public func makeIterator() -> IndexingIterator<[HTTPHeader]> {
        headers.makeIterator()
    }
}

extension HTTPHeaders: Collection {
    public var startIndex: Int {
        headers.startIndex
    }

    public var endIndex: Int {
        headers.endIndex
    }

    public subscript(position: Int) -> HTTPHeader {
        headers[position]
    }

    public func index(after i: Int) -> Int {
        headers.index(after: i)
    }
}

/*
 所以, HTTPHeaders 中, 对于不同协议的支持, 完完全全的写到了各个扩展里面, 这样就使得代码逻辑更加的清除.
 */

extension HTTPHeaders: CustomStringConvertible {
    public var description: String {
        headers.map { $0.description }
            .joined(separator: "\n")
    }
}

// MARK: - HTTPHeader

/// A representation of a single HTTP header's name / value pair.
public struct HTTPHeader: Hashable {
    /// Name of the header.
    // Name 直接用的字符串
    public let name: String
    
    // value 也是直接用的字符串
    /// Value of the header.
    public let value: String

    /// Creates an instance from the given `name` and `value`.
    ///
    /// - Parameters:
    ///   - name:  The name of the header.
    ///   - value: The value of the header.
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

extension HTTPHeader: CustomStringConvertible {
    public var description: String {
        "\(name): \(value)"
    }
}

/*
 类型的重要性就在这里.
 用静态方法, 生成了各种 HTTPHeader 实例.
 在这里, 定义了各种特殊的 HTTPHeader 对象. 要比HTTPHeader(name: "Accept", value: "AcceptValue")的方式更加的安全, 更加方便调用者来使用.
 */

extension HTTPHeader {
    /// Returns an `Accept` header.
    ///
    /// - Parameter value: The `Accept` value.
    /// - Returns:         The header.
    public static func accept(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Accept", value: value)
    }

    /// Returns an `Accept-Charset` header.
    ///
    /// - Parameter value: The `Accept-Charset` value.
    /// - Returns:         The header.
    public static func acceptCharset(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Accept-Charset", value: value)
    }

    /// Returns an `Accept-Language` header.
    ///
    /// Alamofire offers a default Accept-Language header that accumulates and encodes the system's preferred languages.
    /// Use `HTTPHeader.defaultAcceptLanguage`.
    ///
    /// - Parameter value: The `Accept-Language` value.
    ///
    /// - Returns:         The header.
    public static func acceptLanguage(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Accept-Language", value: value)
    }

    /// Returns an `Accept-Encoding` header.
    ///
    /// Alamofire offers a default accept encoding value that provides the most common values. Use
    /// `HTTPHeader.defaultAcceptEncoding`.
    ///
    /// - Parameter value: The `Accept-Encoding` value.
    ///
    /// - Returns:         The header
    public static func acceptEncoding(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Accept-Encoding", value: value)
    }

    /// Returns a `Basic` `Authorization` header using the `username` and `password` provided.
    ///
    /// - Parameters:
    ///   - username: The username of the header.
    ///   - password: The password of the header.
    ///
    /// - Returns:    The header.
    public static func authorization(username: String, password: String) -> HTTPHeader {
        let credential = Data("\(username):\(password)".utf8).base64EncodedString()

        return authorization("Basic \(credential)")
    }

    /// Returns a `Bearer` `Authorization` header using the `bearerToken` provided
    ///
    /// - Parameter bearerToken: The bearer token.
    ///
    /// - Returns:               The header.
    public static func authorization(bearerToken: String) -> HTTPHeader {
        authorization("Bearer \(bearerToken)")
    }

    /// Returns an `Authorization` header.
    ///
    /// Alamofire provides built-in methods to produce `Authorization` headers. For a Basic `Authorization` header use
    /// `HTTPHeader.authorization(username:password:)`. For a Bearer `Authorization` header, use
    /// `HTTPHeader.authorization(bearerToken:)`.
    ///
    /// - Parameter value: The `Authorization` value.
    ///
    /// - Returns:         The header.
    public static func authorization(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Authorization", value: value)
    }

    /// Returns a `Content-Disposition` header.
    ///
    /// - Parameter value: The `Content-Disposition` value.
    ///
    /// - Returns:         The header.
    public static func contentDisposition(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Content-Disposition", value: value)
    }

    /// Returns a `Content-Type` header.
    ///
    /// All Alamofire `ParameterEncoding`s and `ParameterEncoder`s set the `Content-Type` of the request, so it may not be necessary to manually
    /// set this value.
    ///
    /// - Parameter value: The `Content-Type` value.
    ///
    /// - Returns:         The header.
    public static func contentType(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Content-Type", value: value)
    }

    /// Returns a `User-Agent` header.
    ///
    /// - Parameter value: The `User-Agent` value.
    ///
    /// - Returns:         The header.
    public static func userAgent(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "User-Agent", value: value)
    }
}

/*
 这里, 通过 Element 的限制, 为 Array[Element] 增加了一个方法.
 一个函数和方法, 泛型程度越高, 那么它能够做的事情越少.
 多用 let, 表示常量.
 多用已经存在的方法, 这样代码逻辑统一, 只要修改 primitive method 的话, 就可以影响到对应的逻辑.
 */
extension Array where Element == HTTPHeader {
    /// Case-insensitively finds the index of an `HTTPHeader` with the provided name, if it exists.
    func index(of name: String) -> Int? {
        let lowercasedName = name.lowercased()
        /*
         多使用闭包的省略形式, 如果熟悉了这种写法, 可以体会到 Swift 的设计美感.
         */
        return firstIndex { $0.name.lowercased() == lowercasedName }
    }
}

// MARK: - Defaults
/*
 定义一个, 类属性, 来返回公用的属性.
 这个生成方式, 1. 使用了前面的定义的数组初始化方法.
 2. 使用了下面各个 HttpHeader 的类属性. 这里用 .直接就可以进行类属性的提取.
 3. 'default' 这个值, 初始化不在编译时, 不在项目启动是, 而应该是在项目使用到这个值的时候才进行, 实验证明也确实是如此的.
 */
public extension HTTPHeaders {
    /// The default set of `HTTPHeaders` used by Alamofire. Includes `Accept-Encoding`, `Accept-Language`, and
    /// `User-Agent`.
    static let `default`: HTTPHeaders = [.defaultAcceptEncoding,
                                         .defaultAcceptLanguage,
                                         .defaultUserAgent]
}

extension HTTPHeader {
    /// Returns Alamofire's default `Accept-Encoding` header, appropriate for the encodings supported by particular OS
    /// versions.
    ///
    /// See the [Accept-Encoding HTTP header documentation](https://tools.ietf.org/html/rfc7230#section-4.2.3) .
    public static let defaultAcceptEncoding: HTTPHeader = {
        let encodings: [String]
        print("init defaultAcceptEncoding")
        if #available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, *) {
            encodings = ["br", "gzip", "deflate"]
        } else {
            encodings = ["gzip", "deflate"]
        }
        /*
         前面是制作业务信息, 后面是直接调用自己定义的方法, 来处理这些业务信息.
         */
        return .acceptEncoding(encodings.qualityEncoded())
    }()

    /// Returns Alamofire's default `Accept-Language` header, generated by querying `Locale` for the user's
    /// `preferredLanguages`.
    ///
    /// See the [Accept-Language HTTP header documentation](https://tools.ietf.org/html/rfc7231#section-5.3.5).
    public static let defaultAcceptLanguage: HTTPHeader = {
        /*
         就和 Enum 一样, 可以直接用 .acceptLanguage 来进行对象的生成操作.
         */
        .acceptLanguage(Locale.preferredLanguages.prefix(6).qualityEncoded())
    }()

    /// Returns Alamofire's default `User-Agent` header.
    ///
    /// See the [User-Agent header documentation](https://tools.ietf.org/html/rfc7231#section-5.5.3).
    ///
    /// Example: `iOS Example/1.0 (org.alamofire.iOS-Example; build:1; iOS 13.0.0) Alamofire/5.0.0`
    public static let defaultUserAgent: HTTPHeader = {
        let info = Bundle.main.infoDictionary
        let executable = (info?[kCFBundleExecutableKey as String] as? String) ??
            (ProcessInfo.processInfo.arguments.first?.split(separator: "/").last.map(String.init)) ??
            "Unknown"
        let bundle = info?[kCFBundleIdentifierKey as String] as? String ?? "Unknown"
        let appVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBuild = info?[kCFBundleVersionKey as String] as? String ?? "Unknown"

        // 这里, 用懒加载的方式, 将 OSNameVersion 的生成过程, 封装到了一个单元里面. 
        let osNameVersion: String = {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            let osName: String = {
                #if os(iOS)
                return "iOS"
                #elseif os(watchOS)
                return "watchOS"
                #elseif os(tvOS)
                return "tvOS"
                #elseif os(macOS)
                return "macOS"
                #elseif os(Linux)
                return "Linux"
                #elseif os(Windows)
                return "Windows"
                #else
                return "Unknown"
                #endif
            }()

            return "\(osName) \(versionString)"
        }()

        let alamofireVersion = "Alamofire/\(version)"

        let userAgent = "\(executable)/\(appVersion) (\(bundle); build:\(appBuild); \(osNameVersion)) \(alamofireVersion)"

        return .userAgent(userAgent)
    }()
}

extension Collection where Element == String {
    func qualityEncoded() -> String {
        enumerated().map { index, encoding in
            let quality = 1.0 - (Double(index) * 0.1)
            return "\(encoding);q=\(quality)"
        }.joined(separator: ", ")
    }
}

// MARK: - System Type Extensions
/*
 这里不是太明白.
 */
extension URLRequest {
    /// Returns `allHTTPHeaderFields` as `HTTPHeaders`.
    public var headers: HTTPHeaders {
        get { allHTTPHeaderFields.map(HTTPHeaders.init) ?? HTTPHeaders() }
        set { allHTTPHeaderFields = newValue.dictionary }
    }
}

extension HTTPURLResponse {
    /// Returns `allHeaderFields` as `HTTPHeaders`.
    public var headers: HTTPHeaders {
        (allHeaderFields as? [String: String]).map(HTTPHeaders.init) ?? HTTPHeaders()
    }
}

public extension URLSessionConfiguration {
    /// Returns `httpAdditionalHeaders` as `HTTPHeaders`.
    var headers: HTTPHeaders {
        get { (httpAdditionalHeaders as? [String: String]).map(HTTPHeaders.init) ?? HTTPHeaders() }
        set { httpAdditionalHeaders = newValue.dictionary }
    }
}
