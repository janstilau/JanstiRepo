import Foundation

// 这个类, 是用来序列化 Encodable 对象的.
// 把这个对象, 添加到 Request 的数据中去.

/// A type that can encode any `Encodable` type into a `URLRequest`.
public protocol ParameterEncoder {
    /// Encode the provided `Encodable` parameters into `request`.
    ///
    /// - Parameters:
    ///   - parameters: The `Encodable` parameter value.
    ///   - request:    The `URLRequest` into which to encode the parameters.
    ///
    /// - Returns:      A `URLRequest` with the result of the encoding.
    /// - Throws:       An `Error` when encoding fails. For Alamofire provided encoders, this will be an instance of
    ///                 `AFError.parameterEncoderFailed` with an associated `ParameterEncoderFailureReason`.
    func encode<Parameters: Encodable>(_ parameters: Parameters?, into request: URLRequest) throws -> URLRequest
}



// 用 JSON 的方式, 去序列化对象.
/// A `ParameterEncoder` that encodes types as JSON body data.
///
/// If no `Content-Type` header is already set on the provided `URLRequest`s, it's set to `application/json`.
open class JSONParameterEncoder: ParameterEncoder {
    // 几个方便外界使用的静态对象. lazy 创建.
    public static var `default`: JSONParameterEncoder { JSONParameterEncoder() }
    public static var prettyPrinted: JSONParameterEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return JSONParameterEncoder(encoder: encoder)
    }
    @available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    public static var sortedKeys: JSONParameterEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return JSONParameterEncoder(encoder: encoder)
    }
    
    // 真正进行序列化的工作的对象.
    public let encoder: JSONEncoder
    
    /// Creates an instance with the provided `JSONEncoder`.
    ///
    /// - Parameter encoder: The `JSONEncoder`. `JSONEncoder()` by default.
    public init(encoder: JSONEncoder = JSONEncoder()) {
        self.encoder = encoder
    }
    
    // 实际上, 序列化是通过 JSON Encoder 完成的. 序列化出 data 之后, 作为 request 的 body 存在.
    // 在 AFN 里面, 是传过来的是 NSDictionary, 变为 data 之后, 放到 request 的 body 里面.
    // 使用这种方式, 也就代表着, 只能是 post 请求了.
    open func encode<Parameters: Encodable>(_ parameters: Parameters?,
                                            into request: URLRequest) throws -> URLRequest {
        guard let parameters = parameters else { return request }
        
        var request = request
        
        do {
            let data = try encoder.encode(parameters)
            request.httpBody = data
            if request.headers["Content-Type"] == nil {
                request.headers.update(.contentType("application/json"))
            }
        } catch {
            throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
        }
        
        return request
    }
}

//
open class URLEncodedFormParameterEncoder: ParameterEncoder {
    // 一个特殊的类, 标识应该怎么携带 parameter 的数据.
    public enum Destination {
        /// Applies the encoded query string to any existing query string for `.get`, `.head`, and `.delete` request.
        /// Sets it to the `httpBody` for all other methods.
        case methodDependent
        /// Applies the encoded query string to any existing query string from the `URLRequest`.
        case queryString
        /// Applies the encoded query string to the `httpBody` of the `URLRequest`.
        case httpBody
        
        /// Determines whether the URL-encoded string should be applied to the `URLRequest`'s `url`.
        ///
        /// - Parameter method: The `HTTPMethod`.
        ///
        /// - Returns:          Whether the URL-encoded string should be applied to a `URL`.
        func encodesParametersInURL(for method: HTTPMethod) -> Bool {
            switch self {
            case .methodDependent: return [.get, .head, .delete].contains(method)
            case .queryString: return true
            case .httpBody: return false
            }
        }
    }
    
    public static var `default`: URLEncodedFormParameterEncoder { URLEncodedFormParameterEncoder() }
    
    // URLEncodedFormEncoder, 真正做序列化工作的类.
    public let encoder: URLEncodedFormEncoder
    public let destination: Destination
    
    /// Creates an instance with the provided `URLEncodedFormEncoder` instance and `Destination` value.
    ///
    /// - Parameters:
    ///   - encoder:     The `URLEncodedFormEncoder`. `URLEncodedFormEncoder()` by default.
    ///   - destination: The `Destination`. `.methodDependent` by default.
    public init(encoder: URLEncodedFormEncoder = URLEncodedFormEncoder(), destination: Destination = .methodDependent) {
        self.encoder = encoder
        self.destination = destination
    }
    
    //
    open func encode<Parameters: Encodable>(_ parameters: Parameters?,
                                            into request: URLRequest) throws -> URLRequest {
        guard let parameters = parameters else { return request }
        
        var request = request
        
        guard let url = request.url else {
            throw AFError.parameterEncoderFailed(reason: .missingRequiredComponent(.url))
        }
        
        guard let method = request.method else {
            let rawValue = request.method?.rawValue ?? "nil"
            throw AFError.parameterEncoderFailed(reason: .missingRequiredComponent(.httpMethod(rawValue: rawValue)))
        }
        
        // 如果, 配置显示应该在 URL 中存储这些 parater
        if destination.encodesParametersInURL(for: method),
           var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            
            // 这里, 没有处理 error. 因为方法的调用者应该处理.
            // 使用了  Result, 是因为要将错误, 转化成为 AFN 的错误.
            let query: String = try Result<String, Error> { try encoder.encode(parameters) }
                .mapError { AFError.parameterEncoderFailed(reason: .encoderFailed(error: $0)) }
                .get()
            // 拼接工作
            let newQueryString = [components.percentEncodedQuery, query]
                .compactMap { $0 }
                .joinedWithAmpersands()
            components.percentEncodedQuery = newQueryString.isEmpty ? nil : newQueryString
            
            guard let newURL = components.url else {
                throw AFError.parameterEncoderFailed(reason: .missingRequiredComponent(.url))
            }
            
            request.url = newURL
        } else {
            if request.headers["Content-Type"] == nil {
                request.headers.update(.contentType("application/x-www-form-urlencoded; charset=utf-8"))
            }
            
            // 使用 encode 序列化成为 data 之后, 赋值给 HttpBody.
            request.httpBody = try Result<Data, Error> { try encoder.encode(parameters) }
                .mapError { AFError.parameterEncoderFailed(reason: .encoderFailed(error: $0)) }
                .get()
        }
        
        return request
    }
}
