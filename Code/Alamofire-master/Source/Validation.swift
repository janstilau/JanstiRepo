
/*
 Response Validation
 By default, Alamofire treats any completed request to be successful, regardless of the content of the response. Calling validate() before a response handler causes an error to be generated if the response had an unacceptable status code or MIME type.
 
 Automatic Validation
 The validate() API automatically validates that status codes are within the 200..<300 range, and that the Content-Type header of the response matches the Accept header of the request, if one is provided.
 
 AF.request("https://httpbin.org/get").validate().responseJSON { response in
 debugPrint(response)
 }
 Manual Validation
 AF.request("https://httpbin.org/get")
 .validate(statusCode: 200..<300)
 .validate(contentType: ["application/json"])
 .responseData { response in
 switch response.result {
 case .success:
 print("Validation Successful")
 case let .failure(error):
 print(error)
 }
 }
 */

/*
 在 MCNetwork 里面, 会在 Http 成功之后, 根据里面的 Code 值, 做业务是否成功的判断.
 ALAMOFIRE 把这一点的逻辑, 进行了封装.
 */
import Foundation

extension Request {
    // MARK: Helper Types
    
    fileprivate typealias ErrorReason = AFError.ResponseValidationFailureReason
    
    /// Used to represent whether a validation succeeded or failed.
    public typealias ValidationResult = Result<Void, Error>
    
    // 专门的一个数据类型, 来做 MimeType 的解析的工作.
    // 里面就两个值.
    fileprivate struct MIMEType {
        let type: String
        let subtype: String
        
        var isWildcard: Bool { type == "*" && subtype == "*" }
        
        init?(_ string: String) {
            // 这种, {}() 的方法, 可以将一个变量的自定义过程, 完全的包装到作用域内部.
            let components: [String] = {
                let stripped = string.trimmingCharacters(in: .whitespacesAndNewlines)
                // 这里, 这种写法好吗, 提前定义出一个变量会不会更加清晰一点.
                let split = stripped[..<(stripped.range(of: ";")?.lowerBound ?? stripped.endIndex)]
                return split.components(separatedBy: "/")
            }()
            
            if let type = components.first, let subtype = components.last {
                self.type = type
                self.subtype = subtype
            } else {
                return nil
            }
        }
        
        func matches(_ mime: MIMEType) -> Bool {
            switch (type, subtype) {
            case (mime.type, mime.subtype),
                 (mime.type, "*"),
                 ("*", mime.subtype),
                 ("*", "*"):
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: Properties
    
    // 默认的, 代表正常的 Code 值
    fileprivate var acceptableStatusCodes: Range<Int> { 200..<300 }
    // 默认的, 可接受的 contentType
    fileprivate var acceptableContentTypes: [String] {
        if let accept = request?.value(forHTTPHeaderField: "Accept") {
            return accept.components(separatedBy: ",")
        }
        
        return ["*/*"]
    }
    
    // MARK: Status Code
    
    /*
     这是, 实际进行 code 值验证的逻辑, 就是一个 Int Sequence 进行包含判断而已.
     这个函数, 被 validate {} 函数进行复用, 将真正的逻辑, 包装成为一个 Block, 添加到 Validate 数组中.
     */
    fileprivate func validate<S: Sequence>(statusCode acceptableStatusCodes: S,
                                           response: HTTPURLResponse)
    -> ValidationResult where S.Iterator.Element == Int {
        if acceptableStatusCodes.contains(response.statusCode) {
            return .success(())
        } else {
            let reason: ErrorReason = .unacceptableStatusCode(code: response.statusCode)
            return .failure(AFError.responseValidationFailed(reason: reason))
        }
    }
    
    // MARK: Content Type
    
    /*
     验证, ContentType 的逻辑.
     */
    fileprivate func validate<S: Sequence>(contentType acceptableContentTypes: S,
                                           response: HTTPURLResponse,
                                           data: Data?)
    -> ValidationResult where S.Iterator.Element == String {
        // 如果, 没有 data, 就认为是正确的.
        guard let data = data, !data.isEmpty else { return .success(()) }
        
        // 然后才是真正的验证的逻辑, 是直接进行 response 的验证, 其实就是读取 response 的 mimeType 值进行验证.
        return validate(contentType: acceptableContentTypes, response: response)
    }
    
    fileprivate func validate<S: Sequence>(contentType acceptableContentTypes: S,
                                           response: HTTPURLResponse)
    -> ValidationResult where S.Iterator.Element == String {
        /*
         首先, 要 response 能够读取到 mineType, 这个 mineType 能转化成为 MIMEType 结构体.
         */
        guard
            let responseContentType = response.mimeType,
            let responseMIMEType = MIMEType(responseContentType)
        else {
            // 到这里, 就是 response 里面的 mimetyp 有问题.
            // 但是, 如果 acceptableContentTypes 里面有通配符, 那么也算作是成功.
            for contentType in acceptableContentTypes {
                if let mimeType = MIMEType(contentType), mimeType.isWildcard {
                    return .success(())
                }
            }
            
            let error: AFError = {
                let reason: ErrorReason = .missingContentType(acceptableContentTypes: Array(acceptableContentTypes))
                return AFError.responseValidationFailed(reason: reason)
            }()
            
            return .failure(error)
        }
        
        for contentType in acceptableContentTypes {
            if let acceptableMIMEType = MIMEType(contentType), acceptableMIMEType.matches(responseMIMEType) {
                return .success(())
            }
        }
        
        let error: AFError = {
            let reason: ErrorReason = .unacceptableContentType(acceptableContentTypes: Array(acceptableContentTypes),
                                                               responseContentType: responseContentType)
            
            return AFError.responseValidationFailed(reason: reason)
        }()
        
        return .failure(error)
    }
}

// MARK: -

// 上面, 是实际的进行 code, content Type 的过程.
// 而给用户暴露出去的, 是 validate ( block ) 这个接口.
// 在这个接口之上, 由于 code, content type 的检测比较普遍, 又增加了这两个函数的定义, 就是将操作, 组装成为 block, 使用最通用的逻辑.
extension DataRequest {
    /// A closure used to validate a request that takes a URL request, a URL response and data, and returns whether the
    /// request was valid.
    // 这个类型, 就是在 Http 请求结束之后, 触发的验证 Block
    public typealias Validation = (URLRequest?, HTTPURLResponse, Data?) -> ValidationResult
    
    /// Validates that the response has a status code in the specified sequence.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - Parameter statusCode: `Sequence` of acceptable response status codes.
    ///
    /// - Returns:              The instance.
    @discardableResult
    public func validate<S: Sequence>(statusCode acceptableStatusCodes: S) -> Self where S.Iterator.Element == Int {
        validate {
            [unowned self] _, response, _ in
            self.validate(statusCode: acceptableStatusCodes, response: response)
        }
    }
    
    /// Validates that the response has a content type in the specified sequence.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter contentType: The acceptable content types, which may specify wildcard types and/or subtypes.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate<S: Sequence>(contentType acceptableContentTypes: @escaping @autoclosure () -> S) -> Self where S.Iterator.Element == String {
        validate { [unowned self] _, response, data in
            self.validate(contentType: acceptableContentTypes(), response: response, data: data)
        }
    }
    
    /// Validates that the response has a status code in the default acceptable range of 200...299, and that the content
    /// type matches any specified in the Accept HTTP header field.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - returns: The request.
    // 最简单的, 里面封装了对于 code, 对于 type 的验证.
    @discardableResult
    public func validate() -> Self {
        let contentTypes: () -> [String] = { [unowned self] in
            self.acceptableContentTypes
        }
        return validate(statusCode: acceptableStatusCodes).validate(contentType: contentTypes())
    }
}

extension DataStreamRequest {
    /// A closure used to validate a request that takes a `URLRequest` and `HTTPURLResponse` and returns whether the
    /// request was valid.
    public typealias Validation = (_ request: URLRequest?, _ response: HTTPURLResponse) -> ValidationResult
    
    /// Validates that the response has a status code in the specified sequence.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - Parameter statusCode: `Sequence` of acceptable response status codes.
    ///
    /// - Returns:              The instance.
    @discardableResult
    public func validate<S: Sequence>(statusCode acceptableStatusCodes: S) -> Self where S.Iterator.Element == Int {
        validate { [unowned self] _, response in
            self.validate(statusCode: acceptableStatusCodes, response: response)
        }
    }
    
    /// Validates that the response has a content type in the specified sequence.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter contentType: The acceptable content types, which may specify wildcard types and/or subtypes.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate<S: Sequence>(contentType acceptableContentTypes: @escaping @autoclosure () -> S) -> Self where S.Iterator.Element == String {
        validate { [unowned self] _, response in
            self.validate(contentType: acceptableContentTypes(), response: response)
        }
    }
    
    /// Validates that the response has a status code in the default acceptable range of 200...299, and that the content
    /// type matches any specified in the Accept HTTP header field.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - Returns: The instance.
    @discardableResult
    public func validate() -> Self {
        let contentTypes: () -> [String] = { [unowned self] in
            self.acceptableContentTypes
        }
        return validate(statusCode: acceptableStatusCodes).validate(contentType: contentTypes())
    }
}

// MARK: -

extension DownloadRequest {
    /// A closure used to validate a request that takes a URL request, a URL response, a temporary URL and a
    /// destination URL, and returns whether the request was valid.
    public typealias Validation = (_ request: URLRequest?,
                                   _ response: HTTPURLResponse,
                                   _ fileURL: URL?)
        -> ValidationResult
    
    /// Validates that the response has a status code in the specified sequence.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - Parameter statusCode: `Sequence` of acceptable response status codes.
    ///
    /// - Returns:              The instance.
    @discardableResult
    public func validate<S: Sequence>(statusCode acceptableStatusCodes: S) -> Self where S.Iterator.Element == Int {
        validate { [unowned self] _, response, _ in
            self.validate(statusCode: acceptableStatusCodes, response: response)
        }
    }
    
    /// Validates that the response has a content type in the specified sequence.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter contentType: The acceptable content types, which may specify wildcard types and/or subtypes.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate<S: Sequence>(contentType acceptableContentTypes: @escaping @autoclosure () -> S) -> Self where S.Iterator.Element == String {
        validate { [unowned self] _, response, fileURL in
            guard let validFileURL = fileURL else {
                return .failure(AFError.responseValidationFailed(reason: .dataFileNil))
            }
            
            do {
                let data = try Data(contentsOf: validFileURL)
                return self.validate(contentType: acceptableContentTypes(), response: response, data: data)
            } catch {
                return .failure(AFError.responseValidationFailed(reason: .dataFileReadFailed(at: validFileURL)))
            }
        }
    }
    
    /// Validates that the response has a status code in the default acceptable range of 200...299, and that the content
    /// type matches any specified in the Accept HTTP header field.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate() -> Self {
        let contentTypes = { [unowned self] in
            self.acceptableContentTypes
        }
        return validate(statusCode: acceptableStatusCodes).validate(contentType: contentTypes())
    }
}
