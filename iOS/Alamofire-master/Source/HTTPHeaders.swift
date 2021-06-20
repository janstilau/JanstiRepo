import Foundation

/*
 之前用 NSDictionary <NSString *, NSString *> 表示 header, 在 Alamofire 里面, 专门有一个类, 来做相应逻辑的处理.
 之前的 header, 仅仅是在创建 HTTPRequest 的时候.
 for (NSString *headerField in headers.keyEnumerator) {
     [request addValue:headers[headerField] forHTTPHeaderField:headerField];
 }
 进行一次遍历, 将传入的 header, 添加到了 HTTPRequest 的 httpField 里面去了.
 对个各种特殊的 Header 里面的字段, 没有方法进行获取, 都是程序员手动获取该值然后输入到代码中.
 
 Alamofire 的下面两个类, 有着专门的相关逻辑函数.
 */

public struct HTTPHeaders {
    /*
     基本的数据, 就是一个数组, 这个数组里面, 是 key: value 的 pair.
     */
    private var headers: [HTTPHeader] = []
    
    public init() {}
    
    /*
     通过已有量, 来构建一个新的对象, 其实, 就是一个个提取插入的过程.
     update 作为最基本的方法, 各个方法内部尽量将对于数据改变的逻辑, 归总到这个方法的内部.
     */
    public init(_ headers: [HTTPHeader]) {
        self.init()
        headers.forEach { update($0) }
    }
    
    public init(_ dictionary: [String: String]) {
        self.init()
        dictionary.forEach { update(HTTPHeader(name: $0.key, value: $0.value)) }
    }
    
    // 归总到 Update
    public mutating func add(name: String, value: String) {
        update(HTTPHeader(name: name, value: value))
    }
    
    // 归总到 Update
    public mutating func add(_ header: HTTPHeader) {
        update(header)
    }
    
    // 归总到 Update
    public mutating func update(name: String, value: String) {
        update(HTTPHeader(name: name, value: value))
    }
    
    // 如果没有, 就进行加入, 如果有, 就替换.
    public mutating func update(_ header: HTTPHeader) {
        guard let index = headers.index(of: header.name) else {
            headers.append(header)
            return
        }
        headers.replaceSubrange(index...index, with: [header])
    }
    
    public mutating func remove(name: String) {
        guard let index = headers.index(of: name) else { return }
        headers.remove(at: index)
    }
    
    public mutating func sort() {
        headers.sort { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    /*
     基本上, 返回一个新值的函数, 都可以遵从一个逻辑.
     self 的复制操作.
     复制后的对象, 调用 mutating 方法, 改变自身的值.
     返回这个已经进行了改变的复制后的对象.
     */
    public func sorted() -> HTTPHeaders {
        var headers = self
        headers.sort()
        return headers
    }
    
    public func value(for name: String) -> String? {
        guard let index = headers.index(of: name) else { return nil }
        return headers[index].value
    }
    
    /*
     传入的值为 nil, 进行删除, 是一个非常非常通用的做法.
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
    
    // 最终, 和 Apple 的 Request 系统进行交互的方法.
    public var dictionary: [String: String] {
        let namesAndValues = headers.map { ($0.name, $0.value) }
        return Dictionary(namesAndValues, uniquingKeysWith: { _, last in last })
    }
}

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
/*
 本身, HttpHeader, 就是一个 pair 的概念.
 */
/*
 数据部分, designated Init 方法, 在一个代码区块里面.
 其他对于协议的适配部分, 放在了另外的区块里面.
 */
public struct HTTPHeader: Hashable {
    public let name: String
    public let value: String
    /*
     只能通过初始化方法, 来确定里面的值
     */
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

extension HTTPHeader: CustomStringConvertible {
    // String 的插值技术, 让代码少了占位符的配置. 不过, 如何进行格式化输出是个问题.
    public var description: String {
        "\(name): \(value)"
    }
}

/*
 HTTPHeader 封装了常用的 HttpHeader 的 name 调用.
 类的设计者, 主动提供相应的 API, 让数据更加安全.
 */
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
    
    // 用户名密码就是 basic, 但是使用者不应该知道这些. 专门的方法, 隐藏这些细节.
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

/*
 参数是外来值, 不能控制规格是否正确. 需要在程序内部, 进行 lowercased 的处理. 这些值都只存在函数内部, 不会影响到原始值.
 */
extension Array where Element == HTTPHeader {
    func index(of name: String) -> Int? {
        let lowercasedName = name.lowercased()
        return firstIndex { $0.name.lowercased() == lowercasedName }
    }
}

// MARK: - Defaults

public extension HTTPHeaders {
    /*
     之所以, 可以用 [] 这种方式初始化, 是因为 HTTPHeaders 这个类, 有着数组初始化的协议的遵守.
     */
    static let `default`: HTTPHeaders = [.defaultAcceptEncoding,
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
        return .acceptEncoding(encodings.qualityEncoded())
    }()
    
    public static let defaultAcceptLanguage: HTTPHeader = {
        .acceptLanguage(Locale.preferredLanguages.prefix(6).qualityEncoded())
    }()
    
    public static let defaultUserAgent: HTTPHeader = {
        let info = Bundle.main.infoDictionary
        let executable = (info?[kCFBundleExecutableKey as String] as? String) ??
            (ProcessInfo.processInfo.arguments.first?.split(separator: "/").last.map(String.init)) ??
        "Unknown"
        let bundle = info?[kCFBundleIdentifierKey as String] as? String ?? "Unknown"
        let appVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBuild = info?[kCFBundleVersionKey as String] as? String ?? "Unknown"
        
        /*
         这种, 闭包调用的写法, 将某些值的构建过程, 从其他区域进行了切割, 让代码更加的明确.
         */
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

/*
 一定要熟悉以下的函数式写法, 虽然, 内部会有多次的迭代过程, 但是每个方法有着自己明确的任务, 让代码更加简练.
 */
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
 URLRequest 对于 HTTPHeaders 的适配.
 */

extension URLRequest {
    public var headers: HTTPHeaders {
        /*
         有着多种 init 方法, 在这里也可以正常的被识别出来. 这也是因为 swift 的强类型的优势.
         这里这个 map, 不是 collection 的 map, 而是 Optional 的 map.
         如果有值, 抽取值进行 HTTPHeaders 的初始化处理.
         如果没有, 返回默认的数据.
         */
        get { allHTTPHeaderFields.map(HTTPHeaders.init) ?? HTTPHeaders() }
        set { allHTTPHeaderFields = newValue.dictionary }
    }
}

/*
 HTTPURLResponse 对于 HTTPHeaders 的适配.
 allHeaderFields 的返回值类型是  [AnyHashable : Any]  所以, 这里有个转换的过程.
*/
extension HTTPURLResponse {
    /// Returns `allHeaderFields` as `HTTPHeaders`.
    public var headers: HTTPHeaders {
        (allHeaderFields as? [String: String]).map(HTTPHeaders.init) ?? HTTPHeaders()
    }
}

/*
 This property specifies additional headers that are added to all tasks within sessions based on this configuration. For example, you might set the User-Agent header so that it is automatically included in every request your app makes through sessions based on this configuration.
 从上面的描述, 我们也可以看出, URLSessionConfiguration 这个类的作用就是, 将通用的配置数据, 放到这个类里面.
 在网络请求过程中的各个 request 中, 通过 URLSessionConfiguration 中的配置, 进行 request 的配置.
 */
public extension URLSessionConfiguration {
    
    /*
     httpAdditionalHeaders
     A dictionary of additional headers to send with requests.
     This property specifies additional headers that are added to all tasks within sessions based on this configuration. For example, you might set the User-Agent header so that it is automatically included in every request your app makes through sessions based on this configuration.
     这里, 体现出了 URLSessionConfiguration 这个类的意义. 就是一个数据类, 供 Session 在合适的时候, 去一个固定的数据源里面, 读取相应的数据而已.
     */
    var headers: HTTPHeaders {
        get {
            (httpAdditionalHeaders as? [String: String]).map(HTTPHeaders.init) ?? HTTPHeaders()
        }
        set { httpAdditionalHeaders = newValue.dictionary }
    }
}
