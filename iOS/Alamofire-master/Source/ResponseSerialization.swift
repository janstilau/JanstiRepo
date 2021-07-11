import Foundation

// MARK: Protocols

/// The type to which all data response serializers must conform in order to serialize a response.
public protocol DataResponseSerializerProtocol {
    /// The type of serialized object to be created.
    associatedtype SerializedObject
    
    /// Serialize the response `Data` into the provided type..
    ///
    /// - Parameters:
    ///   - request:  `URLRequest` which was used to perform the request, if any.
    ///   - response: `HTTPURLResponse` received from the server, if any.
    ///   - data:     `Data` returned from the server, if any.
    ///   - error:    `Error` produced by Alamofire or the underlying `URLSession` during the request.
    ///
    /// - Returns:    The `SerializedObject`.
    /// - Throws:     Any `Error` produced during serialization.
    /*
     这个协议所做的事情, 就是将 data 还原成为对应的 Model
     */
    func serialize(request: URLRequest?,
                   response: HTTPURLResponse?,
                   data: Data?,
                   error: Error?) throws -> SerializedObject
}

/// The type to which all download response serializers must conform in order to serialize a response.
/*
 从已经归档的数据中, 序列化出 Model 来
 */
public protocol DownloadResponseSerializerProtocol {
    /// The type of serialized object to be created.
    associatedtype SerializedObject
    
    /// Serialize the downloaded response `Data` from disk into the provided type..
    ///
    /// - Parameters:
    ///   - request:  `URLRequest` which was used to perform the request, if any.
    ///   - response: `HTTPURLResponse` received from the server, if any.
    ///   - fileURL:  File `URL` to which the response data was downloaded.
    ///   - error:    `Error` produced by Alamofire or the underlying `URLSession` during the request.
    ///
    /// - Returns:    The `SerializedObject`.
    /// - Throws:     Any `Error` produced during serialization.
    func serializeDownload(request: URLRequest?,
                           response: HTTPURLResponse?,
                           fileURL: URL?,
                           error: Error?) throws -> SerializedObject
}

/// A serializer that can handle both data and download responses.
public protocol ResponseSerializer: DataResponseSerializerProtocol & DownloadResponseSerializerProtocol {
    /// `DataPreprocessor` used to prepare incoming `Data` for serialization.
    var dataPreprocessor: DataPreprocessor { get }
    /// `HTTPMethod`s for which empty response bodies are considered appropriate.
    var emptyRequestMethods: Set<HTTPMethod> { get }
    /// HTTP response codes for which empty response bodies are considered appropriate.
    var emptyResponseCodes: Set<Int> { get }
}

// 预处理 Data
/// Type used to preprocess `Data` before it handled by a serializer.
public protocol DataPreprocessor {
    /// Process           `Data` before it's handled by a serializer.
    /// - Parameter data: The raw `Data` to process.
    func preprocess(_ data: Data) throws -> Data
}

// 这应该是默认的预处理器, 就是不做处理.
/// `DataPreprocessor` that returns passed `Data` without any transform.
public struct PassthroughPreprocessor: DataPreprocessor {
    public init() {}
    
    public func preprocess(_ data: Data) throws -> Data { data }
}

/// `DataPreprocessor` that trims Google's typical `)]}',\n` XSSI JSON header.
public struct GoogleXSSIPreprocessor: DataPreprocessor {
    public init() {}
    
    public func preprocess(_ data: Data) throws -> Data {
        (data.prefix(6) == Data(")]}',\n".utf8)) ? data.dropFirst(6) : data
    }
}

extension ResponseSerializer {
    /*
     定义三个特殊的对象, 作为默认值.
     */
    /// Default `DataPreprocessor`. `PassthroughPreprocessor` by default.
    public static var defaultDataPreprocessor: DataPreprocessor { PassthroughPreprocessor() }
    /// Default `HTTPMethod`s for which empty response bodies are considered appropriate. `[.head]` by default.
    public static var defaultEmptyRequestMethods: Set<HTTPMethod> { [.head] }
    /// HTTP response codes for which empty response bodies are considered appropriate. `[204, 205]` by default.
    public static var defaultEmptyResponseCodes: Set<Int> { [204, 205] }
    
    // 提供协议中默认的值. 这样实现协议的时候, 不用专门去实现这几个属性的限制.
    public var dataPreprocessor: DataPreprocessor { Self.defaultDataPreprocessor }
    public var emptyRequestMethods: Set<HTTPMethod> { Self.defaultEmptyRequestMethods }
    public var emptyResponseCodes: Set<Int> { Self.defaultEmptyResponseCodes }
    
    /// Determines whether the `request` allows empty response bodies, if `request` exists.
    ///
    /// - Parameter request: `URLRequest` to evaluate.
    ///
    /// - Returns:           `Bool` representing the outcome of the evaluation, or `nil` if `request` was `nil`.
    public func requestAllowsEmptyResponseData(_ request: URLRequest?) -> Bool? {
        request.flatMap { $0.httpMethod }
            .flatMap(HTTPMethod.init)
            .map { emptyRequestMethods.contains($0) }
    }
    
    /// Determines whether the `response` allows empty response bodies, if `response` exists`.
    ///
    /// - Parameter response: `HTTPURLResponse` to evaluate.
    ///
    /// - Returns:            `Bool` representing the outcome of the evaluation, or `nil` if `response` was `nil`.
    public func responseAllowsEmptyResponseData(_ response: HTTPURLResponse?) -> Bool? {
        response.flatMap { $0.statusCode }
            .map { emptyResponseCodes.contains($0) }
    }
    
    /// Determines whether `request` and `response` allow empty response bodies.
    ///
    /// - Parameters:
    ///   - request:  `URLRequest` to evaluate.
    ///   - response: `HTTPURLResponse` to evaluate.
    ///
    /// - Returns:    `true` if `request` or `response` allow empty bodies, `false` otherwise.
    public func emptyResponseAllowed(forRequest request: URLRequest?,
                                     response: HTTPURLResponse?) -> Bool {
        (requestAllowsEmptyResponseData(request) == true) ||
            (responseAllowsEmptyResponseData(response) == true)
    }
}

/*
 默认, 还是使用 DataResponseSerializerProtocol 来进行反序列化.
 */
/// By default, any serializer declared to conform to both types will get file serialization for free, as it just feeds
/// the data read from disk into the data response serializer.
public extension DownloadResponseSerializerProtocol where Self: DataResponseSerializerProtocol {
    func serializeDownload(request: URLRequest?, response: HTTPURLResponse?, fileURL: URL?, error: Error?) throws -> Self.SerializedObject {
        guard error == nil else { throw error! }
        
        guard let fileURL = fileURL else {
            throw AFError.responseSerializationFailed(reason: .inputFileNil)
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw AFError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL))
        }
        
        do {
            return try serialize(request: request, response: response, data: data, error: error)
        } catch {
            throw error
        }
    }
}

// MARK: - Default

/*
    各种方法的调用, 其实仅仅是增加一个回调数据而已.
    但是方法还是叫做 response, 而不是 addResponseHandler
 `completionHandler: @escaping (AFDataResponse<Data?>) -> Void 里面, 其实没有做反序列化的处理.
 */

extension DataRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:             The queue on which the completion handler is dispatched. `.main` by default.
    ///   - completionHandler: The code to be executed once the request has finished.
    ///
    /// - Returns:             The request.
    
    // 注释也写的很明白, Add a handler, 是将数据添加到盒子里面, 最终, 还是返回这个盒子.
    @discardableResult
    public func response(queue: DispatchQueue = .main,
                         completionHandler: @escaping (AFDataResponse<Data?>) -> Void) -> Self {
        
        /*
         appendResponseSerializer 里面, 添加的是 data 如何反序列化到 Model 的过程.
         这个过程完成之后, responseSerializerDidComplete 中会将 completionHandler 处理 model 的过程, 添加到一个队列里.
         当 Alamofire 完成了所有的 Data 的反序列化过程之后, 才会去调用队列里面的 completionHandler
         */
        appendResponseSerializer {
            // 当, 能够到达这里的时候, 已经是网络请求达到最后阶段的时候. 所以, data, error 的值, 就是网络请求的最终状态.
            // Start work that should be on the serialization queue.
            // Result<Success, AFError> == AFResult<Data?>
            let result = AFResult<Data?>(value: self.data, error: self.error)
            // End work that should be on the serialization queue.
            
            self.underlyingQueue.async {
                let response = DataResponse(request: self.request,
                                            response: self.response,
                                            data: self.data,
                                            metrics: self.metrics,
                                            serializationDuration: 0,
                                            result: result)
                // 这里不太明白, 为什么在这里调用. 因为 Response Handler 可以添加很多个, 岂不是 eventMonitor 会重复调用到很多次.
                self.eventMonitor?.request(self, didParseResponse: response)
                
                self.responseSerializerDidComplete {
                    // 提交的闭包, 会在提交的 queue 里面进行触发.
                    queue.async { completionHandler(response) }
                }
            }
        }
        
        return self
    }
    
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:              The queue on which the completion handler is dispatched. `.main` by default
    ///   - responseSerializer: The response serializer responsible for serializing the request, response, and data.
    ///   - completionHandler:  The code to be executed once the request has finished.
    ///
    /// - Returns:              The request.
    // 这里, 提供了一个反序列化器, 所以, 最终 completionHandler 处理的是一个, 已经处理好的 Model
    @discardableResult
    public func response<Serializer: DataResponseSerializerProtocol>(queue: DispatchQueue = .main,
                                                                     responseSerializer: Serializer,
                                                                     completionHandler: @escaping (AFDataResponse<Serializer.SerializedObject>) -> Void)
        -> Self {
            appendResponseSerializer {
                // Start work that should be on the serialization queue.
                let start = ProcessInfo.processInfo.systemUptime
                
                // 这里是利用了 Result 的初始化方法, 可以传入一个 throw 的闭包, 在里面会捕获错误, 将 Result 转化为 error
                let result: AFResult<Serializer.SerializedObject> = Result {
                    // 在这里面, 通过 responseSerializer 进行了Model 的生成.
                    try responseSerializer.serialize(request: self.request,
                                                     response: self.response,
                                                     data: self.data,
                                                     error: self.error)
                }.mapError { error in
                    error.asAFError(or: .responseSerializationFailed(reason: .customSerializationFailed(error: error)))
                }
                
                let end = ProcessInfo.processInfo.systemUptime
                // End work that should be on the serialization queue.
                
                self.underlyingQueue.async {
                    // 根据当前的值, 构建出 response.
                    let response = DataResponse(request: self.request,
                                                response: self.response,
                                                data: self.data,
                                                metrics: self.metrics,
                                                serializationDuration: end - start,
                                                result: result)
                    
                    self.eventMonitor?.request(self, didParseResponse: response)
                    
                    guard let serializerError = result.failure,
                          let delegate = self.delegate else {
                        // 如果, 没有发生错误, 就添加到 responseSerializer 的队列里面.
                        self.responseSerializerDidComplete { queue.async { completionHandler(response) } }
                        return
                    }
                    
                    /*
                     错误处理.
                     Delegate 在接收到这个调用之后, 构建 retryResult 通知 Request 如何进行响应.
                     
                     这里, 如果不这样设计, 也可以是要求 delegate 返回一个 retryResult 对象.
                     不过, 这样就逼得 delegate 必须要实现了. 将闭包传出去, 到底调用还是不调用, 就是 delegate 自己来掌握了.
                     */
                    delegate.retryResult(for: self, dueTo: serializerError) { retryResult in
                        var didComplete: (() -> Void)?
                        
                        defer {
                            if let didComplete = didComplete {
                                self.responseSerializerDidComplete { queue.async { didComplete() } }
                            }
                        }
                        
                        // 如果, delegate 决定了, 不在继续, 那么就添加到 responseSerializer 队列里面.
                        switch retryResult {
                        case .doNotRetry:
                            didComplete = { completionHandler(response) }
                            
                        case let .doNotRetryWithError(retryError):
                            let result: AFResult<Serializer.SerializedObject> = .failure(retryError.asAFError(orFailWith: "Received retryError was not already AFError"))
                            
                            let response = DataResponse(request: self.request,
                                                        response: self.response,
                                                        data: self.data,
                                                        metrics: self.metrics,
                                                        serializationDuration: end - start,
                                                        result: result)
                            
                            didComplete = { completionHandler(response) }
                            
                        case .retry, .retryWithDelay:
                            // 交给 delegate. 这里没有 responseSerializer 队列的添加, 所以整个网络请求过程, 有可能结束了.
                            delegate.retryRequest(self, withDelay: retryResult.delay)
                        }
                    }
                }
            }
            
            return self
    }
}

extension DownloadRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:             The queue on which the completion handler is dispatched. `.main` by default.
    ///   - completionHandler: The code to be executed once the request has finished.
    ///
    /// - Returns:             The request.
    @discardableResult
    public func response(queue: DispatchQueue = .main,
                         completionHandler: @escaping (AFDownloadResponse<URL?>) -> Void)
        -> Self {
            appendResponseSerializer {
                // Start work that should be on the serialization queue.
                let result = AFResult<URL?>(value: self.fileURL, error: self.error)
                // End work that should be on the serialization queue.
                
                self.underlyingQueue.async {
                    let response = DownloadResponse(request: self.request,
                                                    response: self.response,
                                                    fileURL: self.fileURL,
                                                    resumeData: self.resumeData,
                                                    metrics: self.metrics,
                                                    serializationDuration: 0,
                                                    result: result)
                    
                    self.eventMonitor?.request(self, didParseResponse: response)
                    
                    self.responseSerializerDidComplete { queue.async { completionHandler(response) } }
                }
            }
            
            return self
    }
    
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:              The queue on which the completion handler is dispatched. `.main` by default.
    ///   - responseSerializer: The response serializer responsible for serializing the request, response, and data
    ///                         contained in the destination `URL`.
    ///   - completionHandler:  The code to be executed once the request has finished.
    ///
    /// - Returns:              The request.
    @discardableResult
    public func response<Serializer: DownloadResponseSerializerProtocol>(queue: DispatchQueue = .main,
                                                                         responseSerializer: Serializer,
                                                                         completionHandler: @escaping (AFDownloadResponse<Serializer.SerializedObject>) -> Void)
        -> Self {
            appendResponseSerializer {
                // Start work that should be on the serialization queue.
                let start = ProcessInfo.processInfo.systemUptime
                let result: AFResult<Serializer.SerializedObject> = Result {
                    try responseSerializer.serializeDownload(request: self.request,
                                                             response: self.response,
                                                             fileURL: self.fileURL,
                                                             error: self.error)
                }.mapError { error in
                    error.asAFError(or: .responseSerializationFailed(reason: .customSerializationFailed(error: error)))
                }
                let end = ProcessInfo.processInfo.systemUptime
                // End work that should be on the serialization queue.
                
                self.underlyingQueue.async {
                    let response = DownloadResponse(request: self.request,
                                                    response: self.response,
                                                    fileURL: self.fileURL,
                                                    resumeData: self.resumeData,
                                                    metrics: self.metrics,
                                                    serializationDuration: end - start,
                                                    result: result)
                    
                    self.eventMonitor?.request(self, didParseResponse: response)
                    
                    guard let serializerError = result.failure, let delegate = self.delegate else {
                        self.responseSerializerDidComplete { queue.async { completionHandler(response) } }
                        return
                    }
                    
                    delegate.retryResult(for: self, dueTo: serializerError) { retryResult in
                        var didComplete: (() -> Void)?
                        
                        defer {
                            if let didComplete = didComplete {
                                self.responseSerializerDidComplete { queue.async { didComplete() } }
                            }
                        }
                        
                        switch retryResult {
                        case .doNotRetry:
                            didComplete = { completionHandler(response) }
                            
                        case let .doNotRetryWithError(retryError):
                            let result: AFResult<Serializer.SerializedObject> = .failure(retryError.asAFError(orFailWith: "Received retryError was not already AFError"))
                            
                            let response = DownloadResponse(request: self.request,
                                                            response: self.response,
                                                            fileURL: self.fileURL,
                                                            resumeData: self.resumeData,
                                                            metrics: self.metrics,
                                                            serializationDuration: end - start,
                                                            result: result)
                            
                            didComplete = { completionHandler(response) }
                            
                        case .retry, .retryWithDelay:
                            delegate.retryRequest(self, withDelay: retryResult.delay)
                        }
                    }
                }
            }
            
            return self
    }
}

// MARK: - Data

/// A `ResponseSerializer` that performs minimal response checking and returns any response `Data` as-is. By default, a
/// request returning `nil` or no data is considered an error. However, if the request has an `HTTPMethod` or the
/// response has an  HTTP status code valid for empty responses, then an empty `Data` value is returned.
public final class DataResponseSerializer: ResponseSerializer {
    public let dataPreprocessor: DataPreprocessor
    public let emptyResponseCodes: Set<Int>
    public let emptyRequestMethods: Set<HTTPMethod>
    
    /// Creates an instance using the provided values.
    ///
    /// - Parameters:
    ///   - dataPreprocessor:    `DataPreprocessor` used to prepare the received `Data` for serialization.
    ///   - emptyResponseCodes:  The HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods: The HTTP request methods for which empty responses are allowed. `[.head]` by default.
    public init(dataPreprocessor: DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
                emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
                emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods) {
        self.dataPreprocessor = dataPreprocessor
        self.emptyResponseCodes = emptyResponseCodes
        self.emptyRequestMethods = emptyRequestMethods
    }
    
    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> Data {
        guard error == nil else { throw error! }
        
        guard var data = data, !data.isEmpty else {
            guard emptyResponseAllowed(forRequest: request, response: response) else {
                throw AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
            }
            
            return Data()
        }
        
        data = try dataPreprocessor.preprocess(data)
        
        return data
    }
}

extension DataRequest {
    /// Adds a handler using a `DataResponseSerializer` to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:               The queue on which the completion handler is called. `.main` by default.
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the
    ///                          `completionHandler`. `PassthroughPreprocessor()` by default.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///   - completionHandler:   A closure to be executed once the request has finished.
    ///
    /// - Returns:               The request.
    @discardableResult
    public func responseData(queue: DispatchQueue = .main,
                             dataPreprocessor: DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
                             emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
                             emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods,
                             completionHandler: @escaping (AFDataResponse<Data>) -> Void) -> Self {
        response(queue: queue,
                 responseSerializer: DataResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                            emptyResponseCodes: emptyResponseCodes,
                                                            emptyRequestMethods: emptyRequestMethods),
                 completionHandler: completionHandler)
    }
}

extension DownloadRequest {
    /// Adds a handler using a `DataResponseSerializer` to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:               The queue on which the completion handler is called. `.main` by default.
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the
    ///                          `completionHandler`. `PassthroughPreprocessor()` by default.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///   - completionHandler:   A closure to be executed once the request has finished.
    ///
    /// - Returns:               The request.
    @discardableResult
    public func responseData(queue: DispatchQueue = .main,
                             dataPreprocessor: DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
                             emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
                             emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods,
                             completionHandler: @escaping (AFDownloadResponse<Data>) -> Void) -> Self {
        response(queue: queue,
                 responseSerializer: DataResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                            emptyResponseCodes: emptyResponseCodes,
                                                            emptyRequestMethods: emptyRequestMethods),
                 completionHandler: completionHandler)
    }
}

// MARK: - String

/// A `ResponseSerializer` that decodes the response data as a `String`. By default, a request returning `nil` or no
/// data is considered an error. However, if the request has an `HTTPMethod` or the response has an  HTTP status code
/// valid for empty responses, then an empty `String` is returned.
public final class StringResponseSerializer: ResponseSerializer {
    public let dataPreprocessor: DataPreprocessor
    /// Optional string encoding used to validate the response.
    public let encoding: String.Encoding?
    public let emptyResponseCodes: Set<Int>
    public let emptyRequestMethods: Set<HTTPMethod>
    
    /// Creates an instance with the provided values.
    ///
    /// - Parameters:
    ///   - dataPreprocessor:    `DataPreprocessor` used to prepare the received `Data` for serialization.
    ///   - encoding:            A string encoding. Defaults to `nil`, in which case the encoding will be determined
    ///                          from the server response, falling back to the default HTTP character set, `ISO-8859-1`.
    ///   - emptyResponseCodes:  The HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods: The HTTP request methods for which empty responses are allowed. `[.head]` by default.
    public init(dataPreprocessor: DataPreprocessor = StringResponseSerializer.defaultDataPreprocessor,
                encoding: String.Encoding? = nil,
                emptyResponseCodes: Set<Int> = StringResponseSerializer.defaultEmptyResponseCodes,
                emptyRequestMethods: Set<HTTPMethod> = StringResponseSerializer.defaultEmptyRequestMethods) {
        self.dataPreprocessor = dataPreprocessor
        self.encoding = encoding
        self.emptyResponseCodes = emptyResponseCodes
        self.emptyRequestMethods = emptyRequestMethods
    }
    
    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> String {
        guard error == nil else { throw error! }
        
        guard var data = data, !data.isEmpty else {
            guard emptyResponseAllowed(forRequest: request, response: response) else {
                throw AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
            }
            
            return ""
        }
        
        data = try dataPreprocessor.preprocess(data)
        
        var convertedEncoding = encoding
        
        if let encodingName = response?.textEncodingName, convertedEncoding == nil {
            convertedEncoding = String.Encoding(ianaCharsetName: encodingName)
        }
        
        let actualEncoding = convertedEncoding ?? .isoLatin1
        
        guard let string = String(data: data, encoding: actualEncoding) else {
            throw AFError.responseSerializationFailed(reason: .stringSerializationFailed(encoding: actualEncoding))
        }
        
        return string
    }
}

extension DataRequest {
    /// Adds a handler using a `StringResponseSerializer` to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:               The queue on which the completion handler is dispatched. `.main` by default.
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the
    ///                          `completionHandler`. `PassthroughPreprocessor()` by default.
    ///   - encoding:            The string encoding. Defaults to `nil`, in which case the encoding will be determined
    ///                          from the server response, falling back to the default HTTP character set, `ISO-8859-1`.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///   - completionHandler:   A closure to be executed once the request has finished.
    ///
    /// - Returns:               The request.
    @discardableResult
    public func responseString(queue: DispatchQueue = .main,
                               dataPreprocessor: DataPreprocessor = StringResponseSerializer.defaultDataPreprocessor,
                               encoding: String.Encoding? = nil,
                               emptyResponseCodes: Set<Int> = StringResponseSerializer.defaultEmptyResponseCodes,
                               emptyRequestMethods: Set<HTTPMethod> = StringResponseSerializer.defaultEmptyRequestMethods,
                               completionHandler: @escaping (AFDataResponse<String>) -> Void) -> Self {
        response(queue: queue,
                 responseSerializer: StringResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                              encoding: encoding,
                                                              emptyResponseCodes: emptyResponseCodes,
                                                              emptyRequestMethods: emptyRequestMethods),
                 completionHandler: completionHandler)
    }
}

extension DownloadRequest {
    /// Adds a handler using a `StringResponseSerializer` to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:               The queue on which the completion handler is dispatched. `.main` by default.
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the
    ///                          `completionHandler`. `PassthroughPreprocessor()` by default.
    ///   - encoding:            The string encoding. Defaults to `nil`, in which case the encoding will be determined
    ///                          from the server response, falling back to the default HTTP character set, `ISO-8859-1`.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///   - completionHandler:   A closure to be executed once the request has finished.
    ///
    /// - Returns:               The request.
    @discardableResult
    public func responseString(queue: DispatchQueue = .main,
                               dataPreprocessor: DataPreprocessor = StringResponseSerializer.defaultDataPreprocessor,
                               encoding: String.Encoding? = nil,
                               emptyResponseCodes: Set<Int> = StringResponseSerializer.defaultEmptyResponseCodes,
                               emptyRequestMethods: Set<HTTPMethod> = StringResponseSerializer.defaultEmptyRequestMethods,
                               completionHandler: @escaping (AFDownloadResponse<String>) -> Void) -> Self {
        response(queue: queue,
                 responseSerializer: StringResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                              encoding: encoding,
                                                              emptyResponseCodes: emptyResponseCodes,
                                                              emptyRequestMethods: emptyRequestMethods),
                 completionHandler: completionHandler)
    }
}

// MARK: - JSON

/// A `ResponseSerializer` that decodes the response data using `JSONSerialization`. By default, a request returning
/// `nil` or no data is considered an error. However, if the request has an `HTTPMethod` or the response has an
/// HTTP status code valid for empty responses, then an `NSNull` value is returned.
public final class JSONResponseSerializer: ResponseSerializer {
    public let dataPreprocessor: DataPreprocessor
    public let emptyResponseCodes: Set<Int>
    public let emptyRequestMethods: Set<HTTPMethod>
    /// `JSONSerialization.ReadingOptions` used when serializing a response.
    public let options: JSONSerialization.ReadingOptions
    
    /// Creates an instance with the provided values.
    ///
    /// - Parameters:
    ///   - dataPreprocessor:    `DataPreprocessor` used to prepare the received `Data` for serialization.
    ///   - emptyResponseCodes:  The HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods: The HTTP request methods for which empty responses are allowed. `[.head]` by default.
    ///   - options:             The options to use. `.allowFragments` by default.
    public init(dataPreprocessor: DataPreprocessor = JSONResponseSerializer.defaultDataPreprocessor,
                emptyResponseCodes: Set<Int> = JSONResponseSerializer.defaultEmptyResponseCodes,
                emptyRequestMethods: Set<HTTPMethod> = JSONResponseSerializer.defaultEmptyRequestMethods,
                options: JSONSerialization.ReadingOptions = .allowFragments) {
        self.dataPreprocessor = dataPreprocessor
        self.emptyResponseCodes = emptyResponseCodes
        self.emptyRequestMethods = emptyRequestMethods
        self.options = options
    }
    
    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> Any {
        guard error == nil else { throw error! }
        
        guard var data = data, !data.isEmpty else {
            guard emptyResponseAllowed(forRequest: request, response: response) else {
                throw AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
            }
            
            return NSNull()
        }
        
        data = try dataPreprocessor.preprocess(data)
        
        do {
            return try JSONSerialization.jsonObject(with: data, options: options)
        } catch {
            throw AFError.responseSerializationFailed(reason: .jsonSerializationFailed(error: error))
        }
    }
}

extension DataRequest {
    /// Adds a handler using a `JSONResponseSerializer` to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:               The queue on which the completion handler is dispatched. `.main` by default.
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the
    ///                          `completionHandler`. `PassthroughPreprocessor()` by default.
    ///   - encoding:            The string encoding. Defaults to `nil`, in which case the encoding will be determined
    ///                          from the server response, falling back to the default HTTP character set, `ISO-8859-1`.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///   - options:             `JSONSerialization.ReadingOptions` used when parsing the response. `.allowFragments`
    ///                          by default.
    ///   - completionHandler:   A closure to be executed once the request has finished.
    ///
    /// - Returns:               The request.
    /*
     由于有 argumentLabel, 和 默认参数的存在, Swift 的方法, 在调用的时候, 可以得到大大的简化.
     */
    @discardableResult
    public func responseJSON(queue: DispatchQueue = .main,
                             dataPreprocessor: DataPreprocessor = JSONResponseSerializer.defaultDataPreprocessor,
                             emptyResponseCodes: Set<Int> = JSONResponseSerializer.defaultEmptyResponseCodes,
                             emptyRequestMethods: Set<HTTPMethod> = JSONResponseSerializer.defaultEmptyRequestMethods,
                             options: JSONSerialization.ReadingOptions = .allowFragments,
                             completionHandler: @escaping (AFDataResponse<Any>) -> Void) -> Self {
        // 所谓的 ResponseJSON, 就是用 JSONResponseSerializer 来处理 data
        response(queue: queue,
                 responseSerializer: JSONResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                            emptyResponseCodes: emptyResponseCodes,
                                                            emptyRequestMethods: emptyRequestMethods,
                                                            options: options),
                 completionHandler: completionHandler)
    }
}

extension DownloadRequest {
    /// Adds a handler using a `JSONResponseSerializer` to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:               The queue on which the completion handler is dispatched. `.main` by default.
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the
    ///                          `completionHandler`. `PassthroughPreprocessor()` by default.
    ///   - encoding:            The string encoding. Defaults to `nil`, in which case the encoding will be determined
    ///                          from the server response, falling back to the default HTTP character set, `ISO-8859-1`.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///   - options:             `JSONSerialization.ReadingOptions` used when parsing the response. `.allowFragments`
    ///                          by default.
    ///   - completionHandler:   A closure to be executed once the request has finished.
    ///
    /// - Returns:               The request.
    @discardableResult
    public func responseJSON(queue: DispatchQueue = .main,
                             dataPreprocessor: DataPreprocessor = JSONResponseSerializer.defaultDataPreprocessor,
                             emptyResponseCodes: Set<Int> = JSONResponseSerializer.defaultEmptyResponseCodes,
                             emptyRequestMethods: Set<HTTPMethod> = JSONResponseSerializer.defaultEmptyRequestMethods,
                             options: JSONSerialization.ReadingOptions = .allowFragments,
                             completionHandler: @escaping (AFDownloadResponse<Any>) -> Void) -> Self {
        response(queue: queue,
                 responseSerializer: JSONResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                            emptyResponseCodes: emptyResponseCodes,
                                                            emptyRequestMethods: emptyRequestMethods,
                                                            options: options),
                 completionHandler: completionHandler)
    }
}

// MARK: - Empty

/// Protocol representing an empty response. Use `T.emptyValue()` to get an instance.
public protocol EmptyResponse {
    /// Empty value for the conforming type.
    ///
    /// - Returns: Value of `Self` to use for empty values.
    static func emptyValue() -> Self
}

/// Type representing an empty value. Use `Empty.value` to get the static instance.
public struct Empty: Codable {
    /// Static `Empty` instance used for all `Empty` responses.
    public static let value = Empty()
}

extension Empty: EmptyResponse {
    public static func emptyValue() -> Empty {
        value
    }
}

// MARK: - DataDecoder Protocol

/// Any type which can decode `Data` into a `Decodable` type.
public protocol DataDecoder {
    /// Decode `Data` into the provided type.
    ///
    /// - Parameters:
    ///   - type:  The `Type` to be decoded.
    ///   - data:  The `Data` to be decoded.
    ///
    /// - Returns: The decoded value of type `D`.
    /// - Throws:  Any error that occurs during decode.
    func decode<D: Decodable>(_ type: D.Type, from data: Data) throws -> D
}

/// `JSONDecoder` automatically conforms to `DataDecoder`.
extension JSONDecoder: DataDecoder {}
/// `PropertyListDecoder` automatically conforms to `DataDecoder`.
extension PropertyListDecoder: DataDecoder {}

// MARK: - Decodable

/// A `ResponseSerializer` that decodes the response data as a generic value using any type that conforms to
/// `DataDecoder`. By default, this is an instance of `JSONDecoder`. Additionally, a request returning `nil` or no data
/// is considered an error. However, if the request has an `HTTPMethod` or the response has an HTTP status code valid
/// for empty responses then an empty value will be returned. If the decoded type conforms to `EmptyResponse`, the
/// type's `emptyValue()` will be returned. If the decoded type is `Empty`, the `.value` instance is returned. If the
/// decoded type *does not* conform to `EmptyResponse` and isn't `Empty`, an error will be produced.
public final class DecodableResponseSerializer<T: Decodable>: ResponseSerializer {
    public let dataPreprocessor: DataPreprocessor
    /// The `DataDecoder` instance used to decode responses.
    public let decoder: DataDecoder
    public let emptyResponseCodes: Set<Int>
    public let emptyRequestMethods: Set<HTTPMethod>
    
    /// Creates an instance using the values provided.
    ///
    /// - Parameters:
    ///   - dataPreprocessor:    `DataPreprocessor` used to prepare the received `Data` for serialization.
    ///   - decoder:             The `DataDecoder`. `JSONDecoder()` by default.
    ///   - emptyResponseCodes:  The HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods: The HTTP request methods for which empty responses are allowed. `[.head]` by default.
    public init(dataPreprocessor: DataPreprocessor = DecodableResponseSerializer.defaultDataPreprocessor,
                decoder: DataDecoder = JSONDecoder(),
                emptyResponseCodes: Set<Int> = DecodableResponseSerializer.defaultEmptyResponseCodes,
                emptyRequestMethods: Set<HTTPMethod> = DecodableResponseSerializer.defaultEmptyRequestMethods) {
        self.dataPreprocessor = dataPreprocessor
        self.decoder = decoder
        self.emptyResponseCodes = emptyResponseCodes
        self.emptyRequestMethods = emptyRequestMethods
    }
    
    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> T {
        guard error == nil else { throw error! }
        
        guard var data = data, !data.isEmpty else {
            guard emptyResponseAllowed(forRequest: request, response: response) else {
                throw AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
            }
            
            guard let emptyResponseType = T.self as? EmptyResponse.Type, let emptyValue = emptyResponseType.emptyValue() as? T else {
                throw AFError.responseSerializationFailed(reason: .invalidEmptyResponse(type: "\(T.self)"))
            }
            
            return emptyValue
        }
        
        data = try dataPreprocessor.preprocess(data)
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AFError.responseSerializationFailed(reason: .decodingFailed(error: error))
        }
    }
}

extension DataRequest {
    /// Adds a handler using a `DecodableResponseSerializer` to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - type:                `Decodable` type to decode from response data.
    ///   - queue:               The queue on which the completion handler is dispatched. `.main` by default.
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the
    ///                          `completionHandler`. `PassthroughPreprocessor()` by default.
    ///   - decoder:             `DataDecoder` to use to decode the response. `JSONDecoder()` by default.
    ///   - encoding:            The string encoding. Defaults to `nil`, in which case the encoding will be determined
    ///                          from the server response, falling back to the default HTTP character set, `ISO-8859-1`.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///   - options:             `JSONSerialization.ReadingOptions` used when parsing the response. `.allowFragments`
    ///                          by default.
    ///   - completionHandler:   A closure to be executed once the request has finished.
    ///
    /// - Returns:               The request.
    @discardableResult
    public func responseDecodable<T: Decodable>(of type: T.Type = T.self,
                                                queue: DispatchQueue = .main,
                                                dataPreprocessor: DataPreprocessor = DecodableResponseSerializer<T>.defaultDataPreprocessor,
                                                decoder: DataDecoder = JSONDecoder(),
                                                emptyResponseCodes: Set<Int> = DecodableResponseSerializer<T>.defaultEmptyResponseCodes,
                                                emptyRequestMethods: Set<HTTPMethod> = DecodableResponseSerializer<T>.defaultEmptyRequestMethods,
                                                completionHandler: @escaping (AFDataResponse<T>) -> Void) -> Self {
        response(queue: queue,
                 responseSerializer: DecodableResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                                 decoder: decoder,
                                                                 emptyResponseCodes: emptyResponseCodes,
                                                                 emptyRequestMethods: emptyRequestMethods),
                 completionHandler: completionHandler)
    }
}

extension DownloadRequest {
    /// Adds a handler using a `DecodableResponseSerializer` to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - type:                `Decodable` type to decode from response data.
    ///   - queue:               The queue on which the completion handler is dispatched. `.main` by default.
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the
    ///                          `completionHandler`. `PassthroughPreprocessor()` by default.
    ///   - decoder:             `DataDecoder` to use to decode the response. `JSONDecoder()` by default.
    ///   - encoding:            The string encoding. Defaults to `nil`, in which case the encoding will be determined
    ///                          from the server response, falling back to the default HTTP character set, `ISO-8859-1`.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///   - options:             `JSONSerialization.ReadingOptions` used when parsing the response. `.allowFragments`
    ///                          by default.
    ///   - completionHandler:   A closure to be executed once the request has finished.
    ///
    /// - Returns:               The request.
    @discardableResult
    public func responseDecodable<T: Decodable>(of type: T.Type = T.self,
                                                queue: DispatchQueue = .main,
                                                dataPreprocessor: DataPreprocessor = DecodableResponseSerializer<T>.defaultDataPreprocessor,
                                                decoder: DataDecoder = JSONDecoder(),
                                                emptyResponseCodes: Set<Int> = DecodableResponseSerializer<T>.defaultEmptyResponseCodes,
                                                emptyRequestMethods: Set<HTTPMethod> = DecodableResponseSerializer<T>.defaultEmptyRequestMethods,
                                                completionHandler: @escaping (AFDownloadResponse<T>) -> Void) -> Self {
        response(queue: queue,
                 responseSerializer: DecodableResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                                 decoder: decoder,
                                                                 emptyResponseCodes: emptyResponseCodes,
                                                                 emptyRequestMethods: emptyRequestMethods),
                 completionHandler: completionHandler)
    }
}

// MARK: - DataStreamRequest

/// A type which can serialize incoming `Data`.
public protocol DataStreamSerializer {
    /// Type produced from the serialized `Data`.
    associatedtype SerializedObject
    
    /// Serializes incoming `Data` into a `SerializedObject` value.
    ///
    /// - Parameter data: `Data` to be serialized.
    ///
    /// - Throws: Any error produced during serialization.
    func serialize(_ data: Data) throws -> SerializedObject
}

/// `DataStreamSerializer` which uses the provided `DataPreprocessor` and `DataDecoder` to serialize the incoming `Data`.
public struct DecodableStreamSerializer<T: Decodable>: DataStreamSerializer {
    /// `DataDecoder` used to decode incoming `Data`.
    public let decoder: DataDecoder
    /// `DataPreprocessor` incoming `Data` is passed through before being passed to the `DataDecoder`.
    public let dataPreprocessor: DataPreprocessor
    
    /// Creates an instance with the provided `DataDecoder` and `DataPreprocessor`.
    /// - Parameters:
    ///   - decoder: `        DataDecoder` used to decode incoming `Data`.
    ///   - dataPreprocessor: `DataPreprocessor` used to process incoming `Data` before it's passed through the `decoder`.
    public init(decoder: DataDecoder = JSONDecoder(), dataPreprocessor: DataPreprocessor = PassthroughPreprocessor()) {
        self.decoder = decoder
        self.dataPreprocessor = dataPreprocessor
    }
    
    public func serialize(_ data: Data) throws -> T {
        let processedData = try dataPreprocessor.preprocess(data)
        do {
            return try decoder.decode(T.self, from: processedData)
        } catch {
            throw AFError.responseSerializationFailed(reason: .decodingFailed(error: error))
        }
    }
}

/// `DataStreamSerializer` which performs no serialization on incoming `Data`.
public struct PassthroughStreamSerializer: DataStreamSerializer {
    public func serialize(_ data: Data) throws -> Data { data }
}

/// `DataStreamSerializer` which serializes incoming stream `Data` into `UTF8`-decoded `String` values.
public struct StringStreamSerializer: DataStreamSerializer {
    public func serialize(_ data: Data) throws -> String {
        String(decoding: data, as: UTF8.self)
    }
}

extension DataStreamRequest {
    /// Adds a `StreamHandler` which performs no parsing on incoming `Data`.
    ///
    /// - Parameters:
    ///   - queue:  `DispatchQueue` on which to perform `StreamHandler` closure.
    ///   - stream: `StreamHandler` closure called as `Data` is received. May be called multiple times.
    ///
    /// - Returns:  The `DataStreamRequest`.
    @discardableResult
    public func responseStream(on queue: DispatchQueue = .main, stream: @escaping Handler<Data, Never>) -> Self {
        let parser = { [unowned self] (data: Data) in
            queue.async {
                self.capturingError {
                    try stream(.init(event: .stream(.success(data)), token: .init(self)))
                }
                
                self.updateAndCompleteIfPossible()
            }
        }
        
        $streamMutableState.write { $0.streams.append(parser) }
        appendStreamCompletion(on: queue, stream: stream)
        
        return self
    }
    
    /// Adds a `StreamHandler` which uses the provided `DataStreamSerializer` to process incoming `Data`.
    ///
    /// - Parameters:
    ///   - serializer: `DataStreamSerializer` used to process incoming `Data`. Its work is done on the `serializationQueue`.
    ///   - queue:      `DispatchQueue` on which to perform `StreamHandler` closure.
    ///   - stream:     `StreamHandler` closure called as `Data` is received. May be called multiple times.
    ///
    /// - Returns:      The `DataStreamRequest`.
    @discardableResult
    public func responseStream<Serializer: DataStreamSerializer>(using serializer: Serializer,
                                                                 on queue: DispatchQueue = .main,
                                                                 stream: @escaping Handler<Serializer.SerializedObject, AFError>) -> Self {
        let parser = { [unowned self] (data: Data) in
            self.serializationQueue.async {
                // Start work on serialization queue.
                let result = Result { try serializer.serialize(data) }
                    .mapError { $0.asAFError(or: .responseSerializationFailed(reason: .customSerializationFailed(error: $0))) }
                // End work on serialization queue.
                self.underlyingQueue.async {
                    self.eventMonitor?.request(self, didParseStream: result)
                    
                    if result.isFailure, self.automaticallyCancelOnStreamError {
                        self.cancel()
                    }
                    
                    queue.async {
                        self.capturingError {
                            try stream(.init(event: .stream(result), token: .init(self)))
                        }
                        
                        self.updateAndCompleteIfPossible()
                    }
                }
            }
        }
        
        $streamMutableState.write { $0.streams.append(parser) }
        appendStreamCompletion(on: queue, stream: stream)
        
        return self
    }
    
    /// Adds a `StreamHandler` which parses incoming `Data` as a UTF8 `String`.
    ///
    /// - Parameters:
    ///   - queue:      `DispatchQueue` on which to perform `StreamHandler` closure.
    ///   - stream:     `StreamHandler` closure called as `Data` is received. May be called multiple times.
    ///
    /// - Returns:  The `DataStreamRequest`.
    @discardableResult
    public func responseStreamString(on queue: DispatchQueue = .main,
                                     stream: @escaping Handler<String, Never>) -> Self {
        let parser = { [unowned self] (data: Data) in
            self.serializationQueue.async {
                // Start work on serialization queue.
                let string = String(decoding: data, as: UTF8.self)
                // End work on serialization queue.
                self.underlyingQueue.async {
                    self.eventMonitor?.request(self, didParseStream: .success(string))
                    
                    queue.async {
                        self.capturingError {
                            try stream(.init(event: .stream(.success(string)), token: .init(self)))
                        }
                        
                        self.updateAndCompleteIfPossible()
                    }
                }
            }
        }
        
        $streamMutableState.write { $0.streams.append(parser) }
        appendStreamCompletion(on: queue, stream: stream)
        
        return self
    }
    
    private func updateAndCompleteIfPossible() {
        $streamMutableState.write { state in
            state.numberOfExecutingStreams -= 1
            
            guard state.numberOfExecutingStreams == 0, !state.enqueuedCompletionEvents.isEmpty else { return }
            
            let completionEvents = state.enqueuedCompletionEvents
            self.underlyingQueue.async { completionEvents.forEach { $0() } }
            state.enqueuedCompletionEvents.removeAll()
        }
    }
    
    /// Adds a `StreamHandler` which parses incoming `Data` using the provided `DataDecoder`.
    ///
    /// - Parameters:
    ///   - type:         `Decodable` type to parse incoming `Data` into.
    ///   - queue:        `DispatchQueue` on which to perform `StreamHandler` closure.
    ///   - decoder:      `DataDecoder` used to decode the incoming `Data`.
    ///   - preprocessor: `DataPreprocessor` used to process the incoming `Data` before it's passed to the `decoder`.
    ///   - stream:       `StreamHandler` closure called as `Data` is received. May be called multiple times.
    ///
    /// - Returns: The `DataStreamRequest`.
    @discardableResult
    public func responseStreamDecodable<T: Decodable>(of type: T.Type = T.self,
                                                      on queue: DispatchQueue = .main,
                                                      using decoder: DataDecoder = JSONDecoder(),
                                                      preprocessor: DataPreprocessor = PassthroughPreprocessor(),
                                                      stream: @escaping Handler<T, AFError>) -> Self {
        responseStream(using: DecodableStreamSerializer<T>(decoder: decoder, dataPreprocessor: preprocessor),
                       stream: stream)
    }
}
