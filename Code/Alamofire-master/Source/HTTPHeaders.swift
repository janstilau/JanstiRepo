import Foundation

/*
 在 AFN 里面, 是 @property (readwrite, nonatomic, strong) NSMutableDictionary *mutableHTTPRequestHeaders;
 也就是一个简单的字典, 作为了网络请求 header 中的数据的载体.
 然后在序列化的时候, 将这个字典里面的值, 一个个赋值到 request 的 header 上.
 */
/*
 Alamofire 中, 专门有一个数据结构来处理. 其实, 最重要的就是 dictionary 函数, 最终 request 也是调用该函数, 来完成最后的数据的提取.
 专门让一个类型来处理相关业务, 可以更加清晰.
 */
/// An order-preserving and case-insensitive representation of HTTP headers.
public struct HTTPHeaders {
    private var headers: [HTTPHeader] = []
    
    /// Creates an empty instance.
    public init() {}
    
    /// Creates an instance from an array of `HTTPHeader`s. Duplicate case-insensitive names are collapsed into the last
    /// name and value encountered.
    /*
     这里, 有序有了意义, 就是后出现的会覆盖前面出现的.
     */
    public init(_ headers: [HTTPHeader]) {
        self.init()
        // 根据场景, 选用 forEach 进行遍历. 中途不会有停止的行为.
        headers.forEach { update($0) }
    }
    
    /// Creates an instance from a `[String: String]`. Duplicate case-insensitive names are collapsed into the last name
    /// and value encountered.
    public init(_ dictionary: [String: String]) {
        self.init()
        // 根据场景, 选用 forEach 进行遍历. 中途不会有停止的行为.
        dictionary.forEach { update(HTTPHeader(name: $0.key, value: $0.value)) }
    }
    
    /// Case-insensitively updates or appends an `HTTPHeader` into the instance using the provided `name` and `value`.
    ///
    /// - Parameters:
    ///   - name:  The `HTTPHeader` name.
    ///   - value: The `HTTPHeader value.
    /*
     函数, 体现了业务的方向, 但是依赖 primitive 点完成业务.
     */
    public mutating func add(name: String, value: String) {
        update(HTTPHeader(name: name, value: value))
    }
    
    /// Case-insensitively updates or appends the provided `HTTPHeader` into the instance.
    ///
    /// - Parameter header: The `HTTPHeader` to update or append.
    /*
     函数, 体现了业务的方向, 但是依赖 primitive 点完成业务.
     */
    public mutating func add(_ header: HTTPHeader) {
        update(header)
    }
    
    /// Case-insensitively updates or appends an `HTTPHeader` into the instance using the provided `name` and `value`.
    ///
    /// - Parameters:
    ///   - name:  The `HTTPHeader` name.
    ///   - value: The `HTTPHeader value.
    /*
     函数, 体现了业务的方向, 但是依赖 primitive 点完成业务.
     */
    public mutating func update(name: String, value: String) {
        update(HTTPHeader(name: name, value: value))
    }
    
    /// Case-insensitively updates or appends the provided `HTTPHeader` into the instance.
    ///
    /// - Parameter header: The `HTTPHeader` to update or append.
    /*
     primitive method. 许多操作的基础点.
     有序, 所以选用数组, 因为 header 里面的数据不会太多, 所以直接使用的数组的查找.
     */
    public mutating func update(_ header: HTTPHeader) {
        guard let index = headers.index(of: header.name) else {
            headers.append(header)
            return
        }
        
        headers.replaceSubrange(index...index, with: [header])
    }
    
    /// Case-insensitively removes an `HTTPHeader`, if it exists, from the instance.
    ///
    /// - Parameter name: The name of the `HTTPHeader` to remove.
    public mutating func remove(name: String) {
        guard let index = headers.index(of: name) else { return }
        
        headers.remove(at: index)
    }
    
    /// Sort the current instance by header name, case insensitively.
    public mutating func sort() {
        headers.sort { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    /// Returns an instance sorted by header name.
    ///
    /// - Returns: A copy of the current instance sorted by name.
    public func sorted() -> HTTPHeaders {
        var headers = self
        headers.sort()
        
        return headers
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
    public subscript(_ name: String) -> String? {
        get { value(for: name) }
        set {
            // nil 作为删除的标志, 已经是很常规了.
            // 更何况 swift 专门把 nil 提高到表示空的高度, 更能体现应该删除的特质.
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
    /*
     最重要的方法, request 序列化的时候, 实际就是使用该函数取值.
     copy, 不暴露自身数据出去.
     */
    public var dictionary: [String: String] {
        let namesAndValues = headers.map { ($0.name, $0.value) }
        
        return Dictionary(namesAndValues, uniquingKeysWith: { _, last in last })
    }
}

// 当, 类里面主要的数据就是 dict 或者 Array 的时候, 应该实现 literal 协议.
extension HTTPHeaders: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, String)...) {
        self.init()
        elements.forEach { update(name: $0.0, value: $0.1) }
    }
}

extension HTTPHeaders: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: HTTPHeader...) {
        self.init(elements)
    }
}

// 不太明白, 这个类实现集合协议的意义在哪里.
// 如果, 是 OC 实现这个类, 可能会提供上面所有的方法, 但是不会提供遍历的功能.
// 但是 Swfit 里面, 实现协议是组成积木的一个环节, 不能用面向对象去限制.
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

extension HTTPHeaders: CustomStringConvertible {
    public var description: String {
        headers.map { $0.description }
            .joined(separator: "\n")
    }
}

// MARK: - HTTPHeader

// 这个类, 本身仅仅是 KeyValue 两个字符串的包装.
// 这个类, 设计出来主要是为了提供那些常见的值出来. 这些值有着特定的 key, 需要的仅仅是外界 value. 不应该让外界去记忆这些特殊值.

/// A representation of a single HTTP header's name / value pair.
public struct HTTPHeader: Hashable {
    /// Name of the header.
    public let name: String
    
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

extension HTTPHeader {
    public static func accept(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Accept", value: value)
    }
    public static func acceptCharset(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Accept-Charset", value: value)
    }
    public static func acceptLanguage(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Accept-Language", value: value)
    }
    public static func acceptEncoding(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Accept-Encoding", value: value)
    }
    public static func authorization(username: String, password: String) -> HTTPHeader {
        let credential = Data("\(username):\(password)".utf8).base64EncodedString()
        return authorization("Basic \(credential)")
    }
    public static func authorization(bearerToken: String) -> HTTPHeader {
        authorization("Bearer \(bearerToken)")
    }
    public static func authorization(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Authorization", value: value)
    }
    public static func contentDisposition(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Content-Disposition", value: value)
    }
    public static func contentType(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Content-Type", value: value)
    }
    public static func userAgent(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "User-Agent", value: value)
    }
}

extension Array where Element == HTTPHeader {
    func index(of name: String) -> Int? {
        let lowercasedName = name.lowercased()
        return firstIndex { $0.name.lowercased() == lowercasedName }
    }
}

// MARK: - Defaults

/*
 作为类的设计者, 可以提供一些默认值, 供外界可以更加方便的使用.
 */

extension HTTPHeaders {
    public static let `default`: HTTPHeaders = [.defaultAcceptEncoding,
                                                .defaultAcceptLanguage,
                                                .defaultUserAgent]
}

extension HTTPHeader {
    public static let defaultAcceptEncoding: HTTPHeader = {
        let encodings: [String]
        if #available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, *) {
            encodings = ["br", "gzip", "deflate"]
        } else {
            encodings = ["gzip", "deflate"]
        }
        // 在类的内部, 可以直接使用类的方法
        return .acceptEncoding(encodings.qualityEncoded())
    }()
    
    /// Returns Alamofire's default `Accept-Language` header, generated by querying `Locale` for the user's
    /// `preferredLanguages`.
    ///
    /// See the [Accept-Language HTTP header documentation](https://tools.ietf.org/html/rfc7231#section-5.3.5).
    public static let defaultAcceptLanguage: HTTPHeader = {
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
        
        let osNameVersion: String = {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            let osName: String = {
                #if os(iOS)
                #if targetEnvironment(macCatalyst)
                return "macOS(Catalyst)"
                #else
                return "iOS"
                #endif
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

// 专门为整个 Protocol 添加一个方法, 当 Element 是 String 的时候.
// 这个可以作为, 添加私有方法, 私有属性的惯例
// private 限制范围, 然后给 String, Int 添加对应的属性或者方法
extension Collection where Element == String {
    func qualityEncoded() -> String {
        enumerated().map { index, encoding in
            let quality = 1.0 - (Double(index) * 0.1)
            return "\(encoding);q=\(quality)"
        }.joined(separator: ", ")
    }
}

// MARK: - System Type Extensions

// URL Request 和 HTTPHeader 类进行交互.
extension URLRequest {
    /// Returns `allHTTPHeaderFields` as `HTTPHeaders`.
    public var headers: HTTPHeaders {
        get { allHTTPHeaderFields.map(HTTPHeaders.init) ?? HTTPHeaders() }
        set { allHTTPHeaderFields = newValue.dictionary }
    }
}

// URL Response 和 HTTPHeader 类进行交互.
extension HTTPURLResponse {
    /// Returns `allHeaderFields` as `HTTPHeaders`.
    public var headers: HTTPHeaders {
        (allHeaderFields as? [String: String]).map(HTTPHeaders.init) ?? HTTPHeaders()
    }
}

extension URLSessionConfiguration {
    /// Returns `httpAdditionalHeaders` as `HTTPHeaders`.
    public var headers: HTTPHeaders {
        get { (httpAdditionalHeaders as? [String: String]).map(HTTPHeaders.init) ?? HTTPHeaders() }
        set { httpAdditionalHeaders = newValue.dictionary }
    }
}
