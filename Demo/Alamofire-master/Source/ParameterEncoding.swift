import Foundation

/// A dictionary of parameters to apply to a `URLRequest`.
public typealias Parameters = [String: Any]

/*
 这个类的主要作用, 就是将 params 序列化到 request 里面去.
 */
public protocol ParameterEncoding {
    func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest
}

// MARK: -

/*
 最常见的一种, 序列化器
 */
public struct URLEncoding: ParameterEncoding {
    // MARK: Helper Types
    
    /// Defines whether the url-encoded query string is applied to the existing query string or HTTP body of the
    /// resulting URL request.
    public enum Destination {
        /*
         通过 request 的 http method 进行判断. 感觉这是最合理的方式啊.
         */
        case methodDependent
        /// Sets or appends encoded query string result to existing query string.
        case queryString
        /// Sets encoded query string result as the HTTP body of the URL request.
        case httpBody
        
        func encodesParametersInURL(for method: HTTPMethod) -> Bool {
            switch self {
            case .methodDependent: return [.get, .head, .delete].contains(method)
            case .queryString: return true
            case .httpBody: return false
            }
        }
    }
    
    /// Configures how `Array` parameters are encoded.
    public enum ArrayEncoding {
        /// An empty set of square brackets is appended to the key for every value. This is the default behavior.
        case brackets
        /// No brackets are appended. The key is encoded as is.
        case noBrackets
        
        func encode(key: String) -> String {
            switch self {
            case .brackets:
                return "\(key)[]"
            case .noBrackets:
                return key
            }
        }
    }
    
    /// Configures how `Bool` parameters are encoded.
    public enum BoolEncoding {
        /// Encode `true` as `1` and `false` as `0`. This is the default behavior.
        case numeric
        /// Encode `true` and `false` as string literals.
        case literal
        
        func encode(value: Bool) -> String {
            switch self {
            case .numeric:
                return value ? "1" : "0"
            case .literal:
                return value ? "true" : "false"
            }
        }
    }
    
    // MARK: Properties
    
    /// Returns a default `URLEncoding` instance with a `.methodDependent` destination.
    public static var `default`: URLEncoding { URLEncoding() }
    
    /// Returns a `URLEncoding` instance with a `.queryString` destination.
    public static var queryString: URLEncoding { URLEncoding(destination: .queryString) }
    
    /// Returns a `URLEncoding` instance with an `.httpBody` destination.
    public static var httpBody: URLEncoding { URLEncoding(destination: .httpBody) }
    
    /*
     参数值, 应该到添加到 request 的哪个部分
     */
    public let destination: Destination
    /*
     如何进行 array 的序列化.
     */
    public let arrayEncoding: ArrayEncoding
    /*
     如何进行 Bool 的序列化.
     */
    public let boolEncoding: BoolEncoding
    
    // MARK: Initialization
    
    public init(destination: Destination = .methodDependent, // 默认, 也是通过 HttpMethod 分辨, 进行 params 的位置的确定.
                arrayEncoding: ArrayEncoding = .brackets,
                boolEncoding: BoolEncoding = .numeric) {
        self.destination = destination
        self.arrayEncoding = arrayEncoding
        self.boolEncoding = boolEncoding
    }
    
    // MARK: Encoding
    
    public func encode(_ urlRequest: URLRequestConvertible,
                       with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()
        
        guard let parameters = parameters else { return urlRequest }
        
        /*
         如果, 是要在 URL 里面, 添加 parameters 的话,
         */
        if let method = urlRequest.method,
            destination.encodesParametersInURL(for: method) {
            guard let url = urlRequest.url else {
                throw AFError.parameterEncodingFailed(reason: .missingURL)
            }
            
            /*
             URLComponents 就是一个专门做 url 处理的一个类.
             */
            if var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false), !parameters.isEmpty {
                let percentEncodedQuery = (urlComponents.percentEncodedQuery.map { $0 + "&" } ?? "") + query(parameters)
                urlComponents.percentEncodedQuery = percentEncodedQuery
                urlRequest.url = urlComponents.url
            }
        } else {
            if urlRequest.headers["Content-Type"] == nil {
                urlRequest.headers.update(.contentType("application/x-www-form-urlencoded; charset=utf-8"))
            }
            
            urlRequest.httpBody = Data(query(parameters).utf8)
        }
        
        return urlRequest
    }
    
    /// Creates a percent-escaped, URL encoded query string components from the given key-value pair recursively.
    ///
    /// - Parameters:
    ///   - key:   Key of the query component.
    ///   - value: Value of the query component.
    ///
    /// - Returns: The percent-escaped, URL encoded query string components.
    /*
     这个序列化的过程, 已经是非常常见了.
     */
    public func queryComponents(fromKey key: String, value: Any) -> [(String, String)] {
        var components: [(String, String)] = []
        switch value {
        case let dictionary as [String: Any]:
            for (nestedKey, value) in dictionary {
                components += queryComponents(fromKey: "\(key)[\(nestedKey)]", value: value)
            }
        case let array as [Any]:
            for value in array {
                components += queryComponents(fromKey: arrayEncoding.encode(key: key), value: value)
            }
        case let number as NSNumber:
            if number.isBool {
                components.append((escape(key), escape(boolEncoding.encode(value: number.boolValue))))
            } else {
                components.append((escape(key), escape("\(number)")))
            }
        case let bool as Bool:
            components.append((escape(key), escape(boolEncoding.encode(value: bool))))
        default:
            components.append((escape(key), escape("\(value)")))
        }
        return components
    }
    
    /// Creates a percent-escaped string following RFC 3986 for a query string key or value.
    ///
    /// - Parameter string: `String` to be percent-escaped.
    ///
    /// - Returns:          The percent-escaped `String`.
    public func escape(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .afURLQueryAllowed) ?? string
    }
    
    private func query(_ parameters: [String: Any]) -> String {
        var components: [(String, String)] = []
        
        for key in parameters.keys.sorted(by: <) {
            let value = parameters[key]!
            components += queryComponents(fromKey: key, value: value)
        }
        return components.map { "\($0)=\($1)" }.joined(separator: "&")
    }
}

// MARK: -

/// Uses `JSONSerialization` to create a JSON representation of the parameters object, which is set as the body of the
/// request. The `Content-Type` HTTP header field of an encoded request is set to `application/json`.
public struct JSONEncoding: ParameterEncoding {
    // MARK: Properties
    
    /// Returns a `JSONEncoding` instance with default writing options.
    public static var `default`: JSONEncoding { JSONEncoding() }
    
    /// Returns a `JSONEncoding` instance with `.prettyPrinted` writing options.
    public static var prettyPrinted: JSONEncoding { JSONEncoding(options: .prettyPrinted) }
    
    /// The options for writing the parameters as JSON data.
    public let options: JSONSerialization.WritingOptions
    
    // MARK: Initialization
    
    /// Creates an instance using the specified `WritingOptions`.
    ///
    /// - Parameter options: `JSONSerialization.WritingOptions` to use.
    public init(options: JSONSerialization.WritingOptions = []) {
        self.options = options
    }
    
    // MARK: Encoding
    
    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()
        
        guard let parameters = parameters else { return urlRequest }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: parameters, options: options)
            
            if urlRequest.headers["Content-Type"] == nil {
                urlRequest.headers.update(.contentType("application/json"))
            }
            /*
             对于 JSON 的 encoder 来说 ,他生成的, 一定就是放到了 body 里面
             */
            urlRequest.httpBody = data
        } catch {
            throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
        }
        
        return urlRequest
    }
    
    /// Encodes any JSON compatible object into a `URLRequest`.
    ///
    /// - Parameters:
    ///   - urlRequest: `URLRequestConvertible` value into which the object will be encoded.
    ///   - jsonObject: `Any` value (must be JSON compatible` to be encoded into the `URLRequest`. `nil` by default.
    ///
    /// - Returns:      The encoded `URLRequest`.
    /// - Throws:       Any `Error` produced during encoding.
    public func encode(_ urlRequest: URLRequestConvertible, withJSONObject jsonObject: Any? = nil) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()
        
        guard let jsonObject = jsonObject else { return urlRequest }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: jsonObject, options: options)
            
            if urlRequest.headers["Content-Type"] == nil {
                urlRequest.headers.update(.contentType("application/json"))
            }
            
            urlRequest.httpBody = data
        } catch {
            throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
        }
        
        return urlRequest
    }
}

// MARK: -

extension NSNumber {
    fileprivate var isBool: Bool {
        // Use Obj-C type encoding to check whether the underlying type is a `Bool`, as it's guaranteed as part of
        // swift-corelibs-foundation, per [this discussion on the Swift forums](https://forums.swift.org/t/alamofire-on-linux-possible-but-not-release-ready/34553/22).
        String(cString: objCType) == "c"
    }
}
