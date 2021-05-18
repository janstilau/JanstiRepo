import Foundation

/*
 Sesstion 这个类, 作用和 AFN 的 SessionManager 的作用应该差不多.
 */
open class Session {
    /*
     一个单例, 简单的网络请求使用, 里面使用默认的数据作为配置.
     */
    public static let `default` = Session()
    
    /*
     Session 这个类, 作为网络请求的管理者, 里面做了 Alamofire 的逻辑处理. 真正的网络请求, 还是要调用系统的 URLSession 进行处理.
     */
    public let session: URLSession
    /// Instance's `SessionDelegate`, which handles the `URLSessionDelegate` methods and `Request` interaction.
    public let delegate: SessionDelegate
    /// Root `DispatchQueue` for all internal callbacks and state update. **MUST** be a serial queue.
    /// rootQueue 都是调用的 async
    public let rootQueue: DispatchQueue
    
    /*
     Session 里面的各个队列, 是为各个 DataRequest 来服务的. 各个 DataRequest, 会保存这些 Queue, 将各自的任务添加到这些 Queue 里面.
     Session 提供了各个工具的来源, 避免各个 DataRequest 直接面对线程相关的资源, 减少复杂度的同时, 也解决了资源的分配.
     */
    
    /// Value determining whether this instance automatically calls `resume()` on all created `Request`s.
    // 这个值, 控制了当 DataRequest 接收到 response 的 Handler 的时候, 是否立马开启 dataTask
    public let startRequestsImmediately: Bool
    /// `DispatchQueue` on which `URLRequest`s are created asynchronously. By default this queue uses `rootQueue` as its
    /// `target`, but a separate queue can be used if request creation is determined to be a bottleneck. Always profile
    /// and test before introducing an additional queue.
    // 这个 Queue, 主要是用来, 做 Request 的初始化操作了.
    // 之所以这样说, 是 Session 里面, 各种数据的准备, 其实都是异步的.
    // 一项事情做完, 触发后续的任务, 仅仅是将后续任务的调用, 扔到一个 queue 里面.
    // 有线程池自己调用相关的任务.
    // 而相关任务被调用, 代表着网络的请求流程, 还在继续.
    public let requestQueue: DispatchQueue
    /// `DispatchQueue` passed to all `Request`s on which they perform their response serialization. By default this
    /// queue uses `rootQueue` as its `target` but a separate queue can be used if response serialization is determined
    /// to be a bottleneck. Always profile and test before introducing an additional queue.
    // 用于 Response 的反序列化的队列.
    public let serializationQueue: DispatchQueue
    
    /*
     Alamofire 将交互过程中, 各个模块都按照协议, 定义了相关的成员变量.
     将责任分化到不同的小模块内部了.
     */
    
    /// `RequestInterceptor` used for all `Request` created by the instance. `RequestInterceptor`s can also be set on a
    /// per-`Request` basis, in which case the `Request`'s interceptor takes precedence over this value.
    public let interceptor: RequestInterceptor?
    /// `ServerTrustManager` instance used to evaluate all trust challenges and provide certificate and key pinning.
    public let serverTrustManager: ServerTrustManager?
    /// `RedirectHandler` instance used to provide customization for request redirection.
    public let redirectHandler: RedirectHandler?
    /// `CachedResponseHandler` instance used to provide customization of cached response handling.
    public let cachedResponseHandler: CachedResponseHandler?
    /// `CompositeEventMonitor` used to compose Alamofire's `defaultEventMonitors` and any passed `EventMonitor`s.
    public let eventMonitor: CompositeEventMonitor
    /// `EventMonitor`s included in all instances. `[AlamofireNotifications()]` by default.
    public let defaultEventMonitors: [EventMonitor] = [AlamofireNotifications()]
    
    /// Internal map between `Request`s and any `URLSessionTasks` that may be in flight for them.
    var requestTaskMap = RequestTaskMap()
    /// `Set` of currently active `Request`s.
    
    /*
     记录了当前正在请求的 request, 在 cancelAllRequests 函数中, 里面的每个 request 会调用 cancel 方法.
     在 RequestDelegate 协议中, request cleanup 中, 会进行相应 request 的删除操作.
     */
    var activeRequests: Set<Request> = []
    
    /// Completion events awaiting `URLSessionTaskMetrics`.
    var waitingCompletions: [URLSessionTask: () -> Void] = [:]
    
    
    
    
    /// Creates a `Session` from a `URLSession` and other parameters.
    ///
    /// - Note: When passing a `URLSession`, you must create the `URLSession` with a specific `delegateQueue` value and
    ///         pass the `delegateQueue`'s `underlyingQueue` as the `rootQueue` parameter of this initializer.
    ///
    /// - Parameters:
    ///   - session:                  Underlying `URLSession` for this instance.
    ///   - delegate:                 `SessionDelegate` that handles `session`'s delegate callbacks as well as `Request`
    ///                               interaction.
    ///   - rootQueue:                Root `DispatchQueue` for all internal callbacks and state updates. **MUST** be a
    ///                               serial queue.
    ///   - startRequestsImmediately: Determines whether this instance will automatically start all `Request`s. `true`
    ///                               by default. If set to `false`, all `Request`s created must have `.resume()` called.
    ///                               on them for them to start.
    ///   - requestQueue:             `DispatchQueue` on which to perform `URLRequest` creation. By default this queue
    ///                               will use the `rootQueue` as its `target`. A separate queue can be used if it's
    ///                               determined request creation is a bottleneck, but that should only be done after
    ///                               careful testing and profiling. `nil` by default.
    ///   - serializationQueue:       `DispatchQueue` on which to perform all response serialization. By default this
    ///                               queue will use the `rootQueue` as its `target`. A separate queue can be used if
    ///                               it's determined response serialization is a bottleneck, but that should only be
    ///                               done after careful testing and profiling. `nil` by default.
    ///   - interceptor:              `RequestInterceptor` to be used for all `Request`s created by this instance. `nil`
    ///                               by default.
    ///   - serverTrustManager:       `ServerTrustManager` to be used for all trust evaluations by this instance. `nil`
    ///                               by default.
    ///   - redirectHandler:          `RedirectHandler` to be used by all `Request`s created by this instance. `nil` by
    ///                               default.
    ///   - cachedResponseHandler:    `CachedResponseHandler` to be used by all `Request`s created by this instance.
    ///                               `nil` by default.
    ///   - eventMonitors:            Additional `EventMonitor`s used by the instance. Alamofire always adds a
    ///                               `AlamofireNotifications` `EventMonitor` to the array passed here. `[]` by default.
    /*
     参数名和成员变量名相同是很常见的事情, 调用 self.name = name 这种写法, 是很常见的事情.
     */
    public init(session: URLSession,
                delegate: SessionDelegate,
                rootQueue: DispatchQueue,
                startRequestsImmediately: Bool = true,
                requestQueue: DispatchQueue? = nil,
                serializationQueue: DispatchQueue? = nil,
                interceptor: RequestInterceptor? = nil,
                serverTrustManager: ServerTrustManager? = nil,
                redirectHandler: RedirectHandler? = nil,
                cachedResponseHandler: CachedResponseHandler? = nil,
                eventMonitors: [EventMonitor] = []) {
        precondition(session.configuration.identifier == nil,
                     "Alamofire does not support background URLSessionConfigurations.")
        precondition(session.delegateQueue.underlyingQueue === rootQueue,
                     "Session(session:) initializer must be passed the DispatchQueue used as the delegateQueue's underlyingQueue as rootQueue.")
        
        self.session = session
        self.delegate = delegate
        self.rootQueue = rootQueue
        self.startRequestsImmediately = startRequestsImmediately
        self.requestQueue = requestQueue ?? DispatchQueue(label: "\(rootQueue.label).requestQueue", target: rootQueue)
        self.serializationQueue = serializationQueue ?? DispatchQueue(label: "\(rootQueue.label).serializationQueue", target: rootQueue)
        self.interceptor = interceptor
        self.serverTrustManager = serverTrustManager
        self.redirectHandler = redirectHandler
        self.cachedResponseHandler = cachedResponseHandler
        eventMonitor = CompositeEventMonitor(monitors: defaultEventMonitors + eventMonitors)
        delegate.eventMonitor = eventMonitor
        delegate.stateProvider = self
    }
    
    /*
     这是一个快捷初始化方法, 所有所需的成员变量, 都提供了默认值.
     */
    public convenience init(configuration: URLSessionConfiguration = URLSessionConfiguration.af.default,
                            delegate: SessionDelegate = SessionDelegate(),
                            rootQueue: DispatchQueue = DispatchQueue(label: "org.alamofire.session.rootQueue"),
                            startRequestsImmediately: Bool = true,
                            requestQueue: DispatchQueue? = nil,
                            serializationQueue: DispatchQueue? = nil,
                            interceptor: RequestInterceptor? = nil,
                            serverTrustManager: ServerTrustManager? = nil,
                            redirectHandler: RedirectHandler? = nil,
                            cachedResponseHandler: CachedResponseHandler? = nil,
                            eventMonitors: [EventMonitor] = []) {
        precondition(configuration.identifier == nil, "Alamofire does not support background URLSessionConfigurations.")
        
        let delegateQueue = OperationQueue(maxConcurrentOperationCount: 1,
                                           underlyingQueue: rootQueue,
                                           name: "org.alamofire.session.sessionDelegateQueue")
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        
        self.init(session: session,
                  delegate: delegate,
                  rootQueue: rootQueue,
                  startRequestsImmediately: startRequestsImmediately,
                  requestQueue: requestQueue,
                  serializationQueue: serializationQueue,
                  interceptor: interceptor,
                  serverTrustManager: serverTrustManager,
                  redirectHandler: redirectHandler,
                  cachedResponseHandler: cachedResponseHandler,
                  eventMonitors: eventMonitors)
    }
    
    deinit {
        finishRequestsForDeinit()
        session.invalidateAndCancel()
    }
    
    // MARK: - Cancellation
    
    /// Cancel all active `Request`s, optionally calling a completion handler when complete.
    ///
    /// - Note: This is an asynchronous operation and does not block the creation of future `Request`s. Cancelled
    ///         `Request`s may not cancel immediately due internal work, and may not cancel at all if they are close to
    ///         completion when cancelled.
    ///
    /// - Parameters:
    ///   - queue:      `DispatchQueue` on which the completion handler is run. `.main` by default.
    ///   - completion: Closure to be called when all `Request`s have been cancelled.
    public func cancelAllRequests(completingOnQueue queue: DispatchQueue = .main,
                                  completion: (() -> Void)? = nil) {
        rootQueue.async {
            // 队列的调度就是如此.
            // 添加一个新的任务, 在任务里面, 完成业务逻辑, 然后将新的任务, 添加到目标 queue 里面.
            // 这个方法, 就要求了 activeRequests 里面的值, 是合法的值.
            self.activeRequests.forEach { $0.cancel() }
            queue.async { completion?() }
        }
    }
    
    
    // MARK: - DataRequest
    
    /*
     RequestModifier 仅仅是一个 block 类型, 但是通过 typealias 的定义, 让他的逻辑含义, 更加的突出.
     RequestModifier 就是给外界一个自定义的机会. 例如, 这个 Request 的 timeout 要长一点, 或者某个特定 URL 的 Request 里面, cotnent-type 要改变.
     */
    public typealias RequestModifier = (inout URLRequest) throws -> Void
    
    /*
     RequestConvertible 就是一个 实现了 URLRequestConvertible 的盒子.
     这个盒子, 存储了所有构件 Request 的信息, 然后生成对应的 request.
     
     关于 Swfit 里面, Throw 相关的资料还是要看一下.
     Throw, 就代表着这个函数是一个 Result 返回值的函数. 在调用的时候, 语法用强制的方式, 让开发者必须去处理 Fail 的情况.
     */
    struct RequestConvertible: URLRequestConvertible {
        let url: URLConvertible
        let method: HTTPMethod
        let parameters: Parameters?
        let encoding: ParameterEncoding
        let headers: HTTPHeaders?
        let requestModifier: RequestModifier?
        
        func asURLRequest() throws -> URLRequest {
            /*
             显示简单的构造了 request, 然后调用 encoding 的序列化方法.
             从这个意义上来说, encoding 这个类, 类似于 AFHTTPRequestSerializer.
             */
            var request = try URLRequest(url: url, method: method, headers: headers)
            try requestModifier?(&request)
            
            return try encoding.encode(request, with: parameters)
        }
    }
    
    /// Creates a `DataRequest` from a `URLRequest` created using the passed components and a `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - convertible:     `URLConvertible` value to be used as the `URLRequest`'s `URL`.  实际的 URL 地址
    ///   - method:          `HTTPMethod` for the `URLRequest`. `.get` by default. 实际的 HTTP 方法.
    ///   - parameters:      `Parameters` (a.k.a. `[String: Any]`) value to be encoded into the `URLRequest`. `nil` by
    ///                      default. 各种参数信息
    ///   - encoding:        `ParameterEncoding` to be used to encode the `parameters` value into the `URLRequest`.
    ///                      `URLEncoding.default` by default. 各种参数, 如何序列化到 Request 的功能
    ///   - headers:         `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default. 各种 header 信息.
    ///   - interceptor:     `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - requestModifier: `RequestModifier` which will be applied to the `URLRequest` created from the provided
    ///                      parameters. `nil` by default. 一个闭包, 用于对于 request 进行个性化定制.
    ///
    /// - Returns:       The created `DataRequest`.
    open func request(_ convertible: URLConvertible,
                      method: HTTPMethod = .get,
                      parameters: Parameters? = nil,
                      encoding: ParameterEncoding = URLEncoding.default,
                      headers: HTTPHeaders? = nil,
                      interceptor: RequestInterceptor? = nil,
                      requestModifier: RequestModifier? = nil) -> DataRequest {
        let convertible = RequestConvertible(url: convertible,
                                             method: method,
                                             parameters: parameters,
                                             encoding: encoding,
                                             headers: headers,
                                             requestModifier: requestModifier)
        
        /*
         Session 有两种 request 方法, 一种是提供各种原始信息. 一种是直接提供一个 URLRequestConvertible
         可以看到, 提供原始材料的这种, 还是在内部构建了一个 RequestConvertible.
         所以, 整个 Session 的内部, 其实是建立在 RequestConvertible 的基础上进行的运转.
         */
        return request(convertible, interceptor: interceptor)
    }
    
    
    
    // 除了 AFN 那种提供 Parameter 方式进行网络的反问, Alamofire 提供了对于 Encodable 对象相关网络的访问
    struct RequestEncodableConvertible<Parameters: Encodable>: URLRequestConvertible {
        let url: URLConvertible
        let method: HTTPMethod
        let parameters: Parameters?
        let encoder: ParameterEncoder
        let headers: HTTPHeaders?
        let requestModifier: RequestModifier?
        
        func asURLRequest() throws -> URLRequest {
            var request = try URLRequest(url: url, method: method, headers: headers)
            try requestModifier?(&request)
            
            return try parameters.map { try encoder.encode($0, into: request) } ?? request
        }
    }
    
    /// Creates a `DataRequest` from a `URLRequest` created using the passed components, `Encodable` parameters, and a
    /// `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - convertible: `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:      `HTTPMethod` for the `URLRequest`. `.get` by default.
    ///   - parameters:  `Encodable` value to be encoded into the `URLRequest`. `nil` by default.
    ///   - encoder:     `ParameterEncoder` to be used to encode the `parameters` value into the `URLRequest`.
    ///                  `URLEncodedFormParameterEncoder.default` by default.
    ///   - headers:     `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///
    /// - Returns:       The created `DataRequest`.
    open func request<Parameters: Encodable>(_ convertible: URLConvertible,
                                             method: HTTPMethod = .get,
                                             parameters: Parameters? = nil,
                                             encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                             headers: HTTPHeaders? = nil,
                                             interceptor: RequestInterceptor? = nil,
                                             requestModifier: RequestModifier? = nil) -> DataRequest {
        let convertible = RequestEncodableConvertible(url: convertible,
                                                      method: method,
                                                      parameters: parameters,
                                                      encoder: encoder,
                                                      headers: headers,
                                                      requestModifier: requestModifier)
        
        return request(convertible, interceptor: interceptor)
    }
    
    /// Creates a `DataRequest` from a `URLRequestConvertible` value and a `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - convertible: `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///
    /// - Returns:       The created `DataRequest`.
    open func request(_ convertible: URLRequestConvertible,
                      interceptor: RequestInterceptor? = nil) -> DataRequest {
        /*
         DataRequest 是一个网络请求的容器, 控制类.
         它的各种属性, 在 Session 中就可以获取.
         而需要外界提供的, 就是 Request.
         */
        // 在 Session 里面, 创建的 DataRequest, 都是 Session 充当 Request 的 delegate
        let request = DataRequest(convertible: convertible,
                                  underlyingQueue: rootQueue,
                                  serializationQueue: serializationQueue,
                                  eventMonitor: eventMonitor,
                                  interceptor: interceptor,
                                  delegate: self)
        
        perform(request)
        return request
    }
    
    // MARK: - DataStreamRequest
    
    /// Creates a `DataStreamRequest` from the passed components, `Encodable` parameters, and `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - convertible:                      `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:                           `HTTPMethod` for the `URLRequest`. `.get` by default.
    ///   - parameters:                       `Encodable` value to be encoded into the `URLRequest`. `nil` by default.
    ///   - encoder:                          `ParameterEncoder` to be used to encode the `parameters` value into the
    ///                                       `URLRequest`.
    ///                                       `URLEncodedFormParameterEncoder.default` by default.
    ///   - headers:                          `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - automaticallyCancelOnStreamError: `Bool` indicating whether the instance should be canceled when an `Error`
    ///                                       is thrown while serializing stream `Data`. `false` by default.
    ///   - interceptor:                      `RequestInterceptor` value to be used by the returned `DataRequest`. `nil`
    ///                                       by default.
    ///   - requestModifier:                  `RequestModifier` which will be applied to the `URLRequest` created from
    ///                                       the provided parameters. `nil` by default.
    ///
    /// - Returns:       The created `DataStream` request.
    open func streamRequest<Parameters: Encodable>(_ convertible: URLConvertible,
                                                   method: HTTPMethod = .get,
                                                   parameters: Parameters? = nil,
                                                   encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                                   headers: HTTPHeaders? = nil,
                                                   automaticallyCancelOnStreamError: Bool = false,
                                                   interceptor: RequestInterceptor? = nil,
                                                   requestModifier: RequestModifier? = nil) -> DataStreamRequest {
        let convertible = RequestEncodableConvertible(url: convertible,
                                                      method: method,
                                                      parameters: parameters,
                                                      encoder: encoder,
                                                      headers: headers,
                                                      requestModifier: requestModifier)
        
        return streamRequest(convertible,
                             automaticallyCancelOnStreamError: automaticallyCancelOnStreamError,
                             interceptor: interceptor)
    }
    
    /// Creates a `DataStreamRequest` from the passed components and `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - convertible:                      `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:                           `HTTPMethod` for the `URLRequest`. `.get` by default.
    ///   - headers:                          `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - automaticallyCancelOnStreamError: `Bool` indicating whether the instance should be canceled when an `Error`
    ///                                       is thrown while serializing stream `Data`. `false` by default.
    ///   - interceptor:                      `RequestInterceptor` value to be used by the returned `DataRequest`. `nil`
    ///                                       by default.
    ///   - requestModifier:                  `RequestModifier` which will be applied to the `URLRequest` created from
    ///                                       the provided parameters. `nil` by default.
    ///
    /// - Returns:       The created `DataStream` request.
    open func streamRequest(_ convertible: URLConvertible,
                            method: HTTPMethod = .get,
                            headers: HTTPHeaders? = nil,
                            automaticallyCancelOnStreamError: Bool = false,
                            interceptor: RequestInterceptor? = nil,
                            requestModifier: RequestModifier? = nil) -> DataStreamRequest {
        let convertible = RequestEncodableConvertible(url: convertible,
                                                      method: method,
                                                      parameters: Optional<Empty>.none,
                                                      encoder: URLEncodedFormParameterEncoder.default,
                                                      headers: headers,
                                                      requestModifier: requestModifier)
        
        return streamRequest(convertible,
                             automaticallyCancelOnStreamError: automaticallyCancelOnStreamError,
                             interceptor: interceptor)
    }
    
    /// Creates a `DataStreamRequest` from the passed `URLRequestConvertible` value and `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - convertible:                      `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - automaticallyCancelOnStreamError: `Bool` indicating whether the instance should be canceled when an `Error`
    ///                                       is thrown while serializing stream `Data`. `false` by default.
    ///   - interceptor:                      `RequestInterceptor` value to be used by the returned `DataRequest`. `nil`
    ///                                        by default.
    ///
    /// - Returns:       The created `DataStreamRequest`.
    open func streamRequest(_ convertible: URLRequestConvertible,
                            automaticallyCancelOnStreamError: Bool = false,
                            interceptor: RequestInterceptor? = nil) -> DataStreamRequest {
        let request = DataStreamRequest(convertible: convertible,
                                        automaticallyCancelOnStreamError: automaticallyCancelOnStreamError,
                                        underlyingQueue: rootQueue,
                                        serializationQueue: serializationQueue,
                                        eventMonitor: eventMonitor,
                                        interceptor: interceptor,
                                        delegate: self)
        
        perform(request)
        
        return request
    }
    
    // MARK: - DownloadRequest
    
    /// Creates a `DownloadRequest` using a `URLRequest` created using the passed components, `RequestInterceptor`, and
    /// `Destination`.
    ///
    /// - Parameters:
    ///   - convertible:     `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:          `HTTPMethod` for the `URLRequest`. `.get` by default.
    ///   - parameters:      `Parameters` (a.k.a. `[String: Any]`) value to be encoded into the `URLRequest`. `nil` by
    ///                      default.
    ///   - encoding:        `ParameterEncoding` to be used to encode the `parameters` value into the `URLRequest`.
    ///                      Defaults to `URLEncoding.default`.
    ///   - headers:         `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:     `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - requestModifier: `RequestModifier` which will be applied to the `URLRequest` created from the provided
    ///                      parameters. `nil` by default.
    ///   - destination:     `DownloadRequest.Destination` closure used to determine how and where the downloaded file
    ///                      should be moved. `nil` by default.
    ///
    /// - Returns:           The created `DownloadRequest`.
    open func download(_ convertible: URLConvertible,
                       method: HTTPMethod = .get,
                       parameters: Parameters? = nil,
                       encoding: ParameterEncoding = URLEncoding.default,
                       headers: HTTPHeaders? = nil,
                       interceptor: RequestInterceptor? = nil,
                       requestModifier: RequestModifier? = nil,
                       to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let convertible = RequestConvertible(url: convertible,
                                             method: method,
                                             parameters: parameters,
                                             encoding: encoding,
                                             headers: headers,
                                             requestModifier: requestModifier)
        
        return download(convertible, interceptor: interceptor, to: destination)
    }
    
    /// Creates a `DownloadRequest` from a `URLRequest` created using the passed components, `Encodable` parameters, and
    /// a `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - convertible:     `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:          `HTTPMethod` for the `URLRequest`. `.get` by default.
    ///   - parameters:      Value conforming to `Encodable` to be encoded into the `URLRequest`. `nil` by default.
    ///   - encoder:         `ParameterEncoder` to be used to encode the `parameters` value into the `URLRequest`.
    ///                      Defaults to `URLEncodedFormParameterEncoder.default`.
    ///   - headers:         `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:     `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - requestModifier: `RequestModifier` which will be applied to the `URLRequest` created from the provided
    ///                      parameters. `nil` by default.
    ///   - destination:     `DownloadRequest.Destination` closure used to determine how and where the downloaded file
    ///                      should be moved. `nil` by default.
    ///
    /// - Returns:           The created `DownloadRequest`.
    open func download<Parameters: Encodable>(_ convertible: URLConvertible,
                                              method: HTTPMethod = .get,
                                              parameters: Parameters? = nil,
                                              encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                              headers: HTTPHeaders? = nil,
                                              interceptor: RequestInterceptor? = nil,
                                              requestModifier: RequestModifier? = nil,
                                              to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let convertible = RequestEncodableConvertible(url: convertible,
                                                      method: method,
                                                      parameters: parameters,
                                                      encoder: encoder,
                                                      headers: headers,
                                                      requestModifier: requestModifier)
        
        return download(convertible, interceptor: interceptor, to: destination)
    }
    
    /// Creates a `DownloadRequest` from a `URLRequestConvertible` value, a `RequestInterceptor`, and a `Destination`.
    ///
    /// - Parameters:
    ///   - convertible: `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - destination: `DownloadRequest.Destination` closure used to determine how and where the downloaded file
    ///                  should be moved. `nil` by default.
    ///
    /// - Returns:       The created `DownloadRequest`.
    open func download(_ convertible: URLRequestConvertible,
                       interceptor: RequestInterceptor? = nil,
                       to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let request = DownloadRequest(downloadable: .request(convertible),
                                      underlyingQueue: rootQueue,
                                      serializationQueue: serializationQueue,
                                      eventMonitor: eventMonitor,
                                      interceptor: interceptor,
                                      delegate: self,
                                      destination: destination ?? DownloadRequest.defaultDestination)
        
        perform(request)
        
        return request
    }
    
    /// Creates a `DownloadRequest` from the `resumeData` produced from a previously cancelled `DownloadRequest`, as
    /// well as a `RequestInterceptor`, and a `Destination`.
    ///
    /// - Note: If `destination` is not specified, the download will be moved to a temporary location determined by
    ///         Alamofire. The file will not be deleted until the system purges the temporary files.
    ///
    /// - Note: On some versions of all Apple platforms (iOS 10 - 10.2, macOS 10.12 - 10.12.2, tvOS 10 - 10.1, watchOS 3 - 3.1.1),
    /// `resumeData` is broken on background URL session configurations. There's an underlying bug in the `resumeData`
    /// generation logic where the data is written incorrectly and will always fail to resume the download. For more
    /// information about the bug and possible workarounds, please refer to the [this Stack Overflow post](http://stackoverflow.com/a/39347461/1342462).
    ///
    /// - Parameters:
    ///   - data:        The resume data from a previously cancelled `DownloadRequest` or `URLSessionDownloadTask`.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - destination: `DownloadRequest.Destination` closure used to determine how and where the downloaded file
    ///                  should be moved. `nil` by default.
    ///
    /// - Returns:       The created `DownloadRequest`.
    open func download(resumingWith data: Data,
                       interceptor: RequestInterceptor? = nil,
                       to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let request = DownloadRequest(downloadable: .resumeData(data),
                                      underlyingQueue: rootQueue,
                                      serializationQueue: serializationQueue,
                                      eventMonitor: eventMonitor,
                                      interceptor: interceptor,
                                      delegate: self,
                                      destination: destination ?? DownloadRequest.defaultDestination)
        
        perform(request)
        
        return request
    }
    
    // MARK: - UploadRequest
    
    struct ParameterlessRequestConvertible: URLRequestConvertible {
        let url: URLConvertible
        let method: HTTPMethod
        let headers: HTTPHeaders?
        let requestModifier: RequestModifier?
        
        func asURLRequest() throws -> URLRequest {
            var request = try URLRequest(url: url, method: method, headers: headers)
            try requestModifier?(&request)
            
            return request
        }
    }
    
    struct Upload: UploadConvertible {
        let request: URLRequestConvertible
        let uploadable: UploadableConvertible
        
        func createUploadable() throws -> UploadRequest.Uploadable {
            try uploadable.createUploadable()
        }
        
        func asURLRequest() throws -> URLRequest {
            try request.asURLRequest()
        }
    }
    
    // MARK: Data
    
    /// Creates an `UploadRequest` for the given `Data`, `URLRequest` components, and `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - data:            The `Data` to upload.
    ///   - convertible:     `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:          `HTTPMethod` for the `URLRequest`. `.post` by default.
    ///   - headers:         `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:     `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager:     `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                      default.
    ///   - requestModifier: `RequestModifier` which will be applied to the `URLRequest` created from the provided
    ///                      parameters. `nil` by default.
    ///
    /// - Returns:           The created `UploadRequest`.
    open func upload(_ data: Data,
                     to convertible: URLConvertible,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil,
                     interceptor: RequestInterceptor? = nil,
                     fileManager: FileManager = .default,
                     requestModifier: RequestModifier? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: convertible,
                                                          method: method,
                                                          headers: headers,
                                                          requestModifier: requestModifier)
        
        return upload(data, with: convertible, interceptor: interceptor, fileManager: fileManager)
    }
    
    /// Creates an `UploadRequest` for the given `Data` using the `URLRequestConvertible` value and `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - data:        The `Data` to upload.
    ///   - convertible: `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager: `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                  default.
    ///
    /// - Returns:       The created `UploadRequest`.
    open func upload(_ data: Data,
                     with convertible: URLRequestConvertible,
                     interceptor: RequestInterceptor? = nil,
                     fileManager: FileManager = .default) -> UploadRequest {
        upload(.data(data), with: convertible, interceptor: interceptor, fileManager: fileManager)
    }
    
    // MARK: File
    
    /// Creates an `UploadRequest` for the file at the given file `URL`, using a `URLRequest` from the provided
    /// components and `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - fileURL:         The `URL` of the file to upload.
    ///   - convertible:     `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:          `HTTPMethod` for the `URLRequest`. `.post` by default.
    ///   - headers:         `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:     `RequestInterceptor` value to be used by the returned `UploadRequest`. `nil` by default.
    ///   - fileManager:     `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                      default.
    ///   - requestModifier: `RequestModifier` which will be applied to the `URLRequest` created from the provided
    ///                      parameters. `nil` by default.
    ///
    /// - Returns:           The created `UploadRequest`.
    open func upload(_ fileURL: URL,
                     to convertible: URLConvertible,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil,
                     interceptor: RequestInterceptor? = nil,
                     fileManager: FileManager = .default,
                     requestModifier: RequestModifier? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: convertible,
                                                          method: method,
                                                          headers: headers,
                                                          requestModifier: requestModifier)
        
        return upload(fileURL, with: convertible, interceptor: interceptor, fileManager: fileManager)
    }
    
    /// Creates an `UploadRequest` for the file at the given file `URL` using the `URLRequestConvertible` value and
    /// `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - fileURL:     The `URL` of the file to upload.
    ///   - convertible: `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager: `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                  default.
    ///
    /// - Returns:       The created `UploadRequest`.
    open func upload(_ fileURL: URL,
                     with convertible: URLRequestConvertible,
                     interceptor: RequestInterceptor? = nil,
                     fileManager: FileManager = .default) -> UploadRequest {
        upload(.file(fileURL, shouldRemove: false), with: convertible, interceptor: interceptor, fileManager: fileManager)
    }
    
    // MARK: InputStream
    
    /// Creates an `UploadRequest` from the `InputStream` provided using a `URLRequest` from the provided components and
    /// `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - stream:          The `InputStream` that provides the data to upload.
    ///   - convertible:     `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - method:          `HTTPMethod` for the `URLRequest`. `.post` by default.
    ///   - headers:         `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:     `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager:     `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                      default.
    ///   - requestModifier: `RequestModifier` which will be applied to the `URLRequest` created from the provided
    ///                      parameters. `nil` by default.
    ///
    /// - Returns:           The created `UploadRequest`.
    open func upload(_ stream: InputStream,
                     to convertible: URLConvertible,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil,
                     interceptor: RequestInterceptor? = nil,
                     fileManager: FileManager = .default,
                     requestModifier: RequestModifier? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: convertible,
                                                          method: method,
                                                          headers: headers,
                                                          requestModifier: requestModifier)
        
        return upload(stream, with: convertible, interceptor: interceptor, fileManager: fileManager)
    }
    
    /// Creates an `UploadRequest` from the provided `InputStream` using the `URLRequestConvertible` value and
    /// `RequestInterceptor`.
    ///
    /// - Parameters:
    ///   - stream:      The `InputStream` that provides the data to upload.
    ///   - convertible: `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - interceptor: `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager: `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                  default.
    ///
    /// - Returns:       The created `UploadRequest`.
    open func upload(_ stream: InputStream,
                     with convertible: URLRequestConvertible,
                     interceptor: RequestInterceptor? = nil,
                     fileManager: FileManager = .default) -> UploadRequest {
        upload(.stream(stream), with: convertible, interceptor: interceptor, fileManager: fileManager)
    }
    
    // MARK: MultipartFormData
    
    /// Creates an `UploadRequest` for the multipart form data built using a closure and sent using the provided
    /// `URLRequest` components and `RequestInterceptor`.
    ///
    /// It is important to understand the memory implications of uploading `MultipartFormData`. If the cumulative
    /// payload is small, encoding the data in-memory and directly uploading to a server is the by far the most
    /// efficient approach. However, if the payload is too large, encoding the data in-memory could cause your app to
    /// be terminated. Larger payloads must first be written to disk using input and output streams to keep the memory
    /// footprint low, then the data can be uploaded as a stream from the resulting file. Streaming from disk MUST be
    /// used for larger payloads such as video content.
    ///
    /// The `encodingMemoryThreshold` parameter allows Alamofire to automatically determine whether to encode in-memory
    /// or stream from disk. If the content length of the `MultipartFormData` is below the `encodingMemoryThreshold`,
    /// encoding takes place in-memory. If the content length exceeds the threshold, the data is streamed to disk
    /// during the encoding process. Then the result is uploaded as data or as a stream depending on which encoding
    /// technique was used.
    ///
    /// - Parameters:
    ///   - multipartFormData:       `MultipartFormData` building closure.
    ///   - convertible:             `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - encodingMemoryThreshold: Byte threshold used to determine whether the form data is encoded into memory or
    ///                              onto disk before being uploaded. `MultipartFormData.encodingMemoryThreshold` by
    ///                              default.
    ///   - method:                  `HTTPMethod` for the `URLRequest`. `.post` by default.
    ///   - headers:                 `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:             `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager:             `FileManager` to be used if the form data exceeds the memory threshold and is
    ///                              written to disk before being uploaded. `.default` instance by default.
    ///   - requestModifier:         `RequestModifier` which will be applied to the `URLRequest` created from the
    ///                              provided parameters. `nil` by default.
    ///
    /// - Returns:                   The created `UploadRequest`.
    open func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                     to url: URLConvertible,
                     usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil,
                     interceptor: RequestInterceptor? = nil,
                     fileManager: FileManager = .default,
                     requestModifier: RequestModifier? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: url,
                                                          method: method,
                                                          headers: headers,
                                                          requestModifier: requestModifier)
        
        let formData = MultipartFormData(fileManager: fileManager)
        multipartFormData(formData)
        
        return upload(multipartFormData: formData,
                      with: convertible,
                      usingThreshold: encodingMemoryThreshold,
                      interceptor: interceptor,
                      fileManager: fileManager)
    }
    
    /// Creates an `UploadRequest` using a `MultipartFormData` building closure, the provided `URLRequestConvertible`
    /// value, and a `RequestInterceptor`.
    ///
    /// It is important to understand the memory implications of uploading `MultipartFormData`. If the cumulative
    /// payload is small, encoding the data in-memory and directly uploading to a server is the by far the most
    /// efficient approach. However, if the payload is too large, encoding the data in-memory could cause your app to
    /// be terminated. Larger payloads must first be written to disk using input and output streams to keep the memory
    /// footprint low, then the data can be uploaded as a stream from the resulting file. Streaming from disk MUST be
    /// used for larger payloads such as video content.
    ///
    /// The `encodingMemoryThreshold` parameter allows Alamofire to automatically determine whether to encode in-memory
    /// or stream from disk. If the content length of the `MultipartFormData` is below the `encodingMemoryThreshold`,
    /// encoding takes place in-memory. If the content length exceeds the threshold, the data is streamed to disk
    /// during the encoding process. Then the result is uploaded as data or as a stream depending on which encoding
    /// technique was used.
    ///
    /// - Parameters:
    ///   - multipartFormData:       `MultipartFormData` building closure.
    ///   - request:                 `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - encodingMemoryThreshold: Byte threshold used to determine whether the form data is encoded into memory or
    ///                              onto disk before being uploaded. `MultipartFormData.encodingMemoryThreshold` by
    ///                              default.
    ///   - interceptor:             `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager:             `FileManager` to be used if the form data exceeds the memory threshold and is
    ///                              written to disk before being uploaded. `.default` instance by default.
    ///
    /// - Returns:                   The created `UploadRequest`.
    open func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                     with request: URLRequestConvertible,
                     usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
                     interceptor: RequestInterceptor? = nil,
                     fileManager: FileManager = .default) -> UploadRequest {
        let formData = MultipartFormData(fileManager: fileManager)
        multipartFormData(formData)
        
        return upload(multipartFormData: formData,
                      with: request,
                      usingThreshold: encodingMemoryThreshold,
                      interceptor: interceptor,
                      fileManager: fileManager)
    }
    
    /// Creates an `UploadRequest` for the prebuilt `MultipartFormData` value using the provided `URLRequest` components
    /// and `RequestInterceptor`.
    ///
    /// It is important to understand the memory implications of uploading `MultipartFormData`. If the cumulative
    /// payload is small, encoding the data in-memory and directly uploading to a server is the by far the most
    /// efficient approach. However, if the payload is too large, encoding the data in-memory could cause your app to
    /// be terminated. Larger payloads must first be written to disk using input and output streams to keep the memory
    /// footprint low, then the data can be uploaded as a stream from the resulting file. Streaming from disk MUST be
    /// used for larger payloads such as video content.
    ///
    /// The `encodingMemoryThreshold` parameter allows Alamofire to automatically determine whether to encode in-memory
    /// or stream from disk. If the content length of the `MultipartFormData` is below the `encodingMemoryThreshold`,
    /// encoding takes place in-memory. If the content length exceeds the threshold, the data is streamed to disk
    /// during the encoding process. Then the result is uploaded as data or as a stream depending on which encoding
    /// technique was used.
    ///
    /// - Parameters:
    ///   - multipartFormData:       `MultipartFormData` instance to upload.
    ///   - url:                     `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - encodingMemoryThreshold: Byte threshold used to determine whether the form data is encoded into memory or
    ///                              onto disk before being uploaded. `MultipartFormData.encodingMemoryThreshold` by
    ///                              default.
    ///   - method:                  `HTTPMethod` for the `URLRequest`. `.post` by default.
    ///   - headers:                 `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - interceptor:             `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager:             `FileManager` to be used if the form data exceeds the memory threshold and is
    ///                              written to disk before being uploaded. `.default` instance by default.
    ///   - requestModifier:         `RequestModifier` which will be applied to the `URLRequest` created from the
    ///                              provided parameters. `nil` by default.
    ///
    /// - Returns:                   The created `UploadRequest`.
    open func upload(multipartFormData: MultipartFormData,
                     to url: URLConvertible,
                     usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil,
                     interceptor: RequestInterceptor? = nil,
                     fileManager: FileManager = .default,
                     requestModifier: RequestModifier? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: url,
                                                          method: method,
                                                          headers: headers,
                                                          requestModifier: requestModifier)
        
        let multipartUpload = MultipartUpload(isInBackgroundSession: session.configuration.identifier != nil,
                                              encodingMemoryThreshold: encodingMemoryThreshold,
                                              request: convertible,
                                              multipartFormData: multipartFormData)
        
        return upload(multipartUpload, interceptor: interceptor, fileManager: fileManager)
    }
    
    /// Creates an `UploadRequest` for the prebuilt `MultipartFormData` value using the providing `URLRequestConvertible`
    /// value and `RequestInterceptor`.
    ///
    /// It is important to understand the memory implications of uploading `MultipartFormData`. If the cumulative
    /// payload is small, encoding the data in-memory and directly uploading to a server is the by far the most
    /// efficient approach. However, if the payload is too large, encoding the data in-memory could cause your app to
    /// be terminated. Larger payloads must first be written to disk using input and output streams to keep the memory
    /// footprint low, then the data can be uploaded as a stream from the resulting file. Streaming from disk MUST be
    /// used for larger payloads such as video content.
    ///
    /// The `encodingMemoryThreshold` parameter allows Alamofire to automatically determine whether to encode in-memory
    /// or stream from disk. If the content length of the `MultipartFormData` is below the `encodingMemoryThreshold`,
    /// encoding takes place in-memory. If the content length exceeds the threshold, the data is streamed to disk
    /// during the encoding process. Then the result is uploaded as data or as a stream depending on which encoding
    /// technique was used.
    ///
    /// - Parameters:
    ///   - multipartFormData:       `MultipartFormData` instance to upload.
    ///   - request:                 `URLRequestConvertible` value to be used to create the `URLRequest`.
    ///   - encodingMemoryThreshold: Byte threshold used to determine whether the form data is encoded into memory or
    ///                              onto disk before being uploaded. `MultipartFormData.encodingMemoryThreshold` by
    ///                              default.
    ///   - interceptor:             `RequestInterceptor` value to be used by the returned `DataRequest`. `nil` by default.
    ///   - fileManager:             `FileManager` instance to be used by the returned `UploadRequest`. `.default` instance by
    ///                              default.
    ///
    /// - Returns:                   The created `UploadRequest`.
    open func upload(multipartFormData: MultipartFormData,
                     with request: URLRequestConvertible,
                     usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
                     interceptor: RequestInterceptor? = nil,
                     fileManager: FileManager = .default) -> UploadRequest {
        let multipartUpload = MultipartUpload(isInBackgroundSession: session.configuration.identifier != nil,
                                              encodingMemoryThreshold: encodingMemoryThreshold,
                                              request: request,
                                              multipartFormData: multipartFormData)
        
        return upload(multipartUpload, interceptor: interceptor, fileManager: fileManager)
    }
    
    // MARK: - Internal API
    
    // MARK: Uploadable
    
    func upload(_ uploadable: UploadRequest.Uploadable,
                with convertible: URLRequestConvertible,
                interceptor: RequestInterceptor?,
                fileManager: FileManager) -> UploadRequest {
        let uploadable = Upload(request: convertible, uploadable: uploadable)
        
        return upload(uploadable, interceptor: interceptor, fileManager: fileManager)
    }
    
    
    
    
    func upload(_ upload: UploadConvertible, interceptor: RequestInterceptor?, fileManager: FileManager) -> UploadRequest {
        let request = UploadRequest(convertible: upload,
                                    underlyingQueue: rootQueue,
                                    serializationQueue: serializationQueue,
                                    eventMonitor: eventMonitor,
                                    interceptor: interceptor,
                                    fileManager: fileManager,
                                    delegate: self)
        
        perform(request)
        
        return request
    }
    
    /*
        各种 DataRequest, UPLoadRequest, DownloadRequest 最终都是到达 perform 这个函数.
        这个函数, 会最终生成 DataRequest 对象, 这个对象, 是整个网络交互的控制类.
     */
    func perform(_ request: Request) {
        rootQueue.async {
            guard !request.isCancelled else { return }
            
            self.activeRequests.insert(request)
            self.requestQueue.async {
                // Leaf types must come first, otherwise they will cast as their superclass.
                switch request {
                case let r as UploadRequest: self.performUploadRequest(r)
                case let r as DataRequest: self.performDataRequest(r)
                case let r as DownloadRequest: self.performDownloadRequest(r)
                case let r as DataStreamRequest: self.performDataStreamRequest(r)
                default: fatalError("Attempted to perform unsupported Request subclass: \(type(of: request))")
                }
            }
        }
    }
    
    func performDataRequest(_ request: DataRequest) {
        /*
         dispatchPrecondition 的功能暂且搁置.
         */
        dispatchPrecondition(condition: .onQueue(requestQueue))
        
        performSetupOperations(for: request, convertible: request.convertible)
    }
    
    func performDataStreamRequest(_ request: DataStreamRequest) {
        dispatchPrecondition(condition: .onQueue(requestQueue))
        
        performSetupOperations(for: request, convertible: request.convertible)
    }
    
    func performUploadRequest(_ request: UploadRequest) {
        dispatchPrecondition(condition: .onQueue(requestQueue))
        
        do {
            let uploadable = try request.upload.createUploadable()
            rootQueue.async { request.didCreateUploadable(uploadable) }
            
            performSetupOperations(for: request, convertible: request.convertible)
        } catch {
            rootQueue.async { request.didFailToCreateUploadable(with: error.asAFError(or: .createUploadableFailed(error: error))) }
        }
    }
    
    func performDownloadRequest(_ request: DownloadRequest) {
        dispatchPrecondition(condition: .onQueue(requestQueue))
        
        switch request.downloadable {
        case let .request(convertible):
            performSetupOperations(for: request, convertible: convertible)
        case let .resumeData(resumeData):
            rootQueue.async { self.didReceiveResumeData(resumeData, for: request) }
        }
    }
    
    func performSetupOperations(for request: Request,
                                convertible: URLRequestConvertible) {
        dispatchPrecondition(condition: .onQueue(requestQueue))
        
        
        
        /*
         首选, 通过 URLRequestConvertible 创建出一个 URLRequest 出来.
         */
        let initialRequest: URLRequest
        do {
            initialRequest = try convertible.asURLRequest()
            try initialRequest.validate()
        } catch {
            rootQueue.async { request.didFailToCreateURLRequest(with: error.asAFError(or: .createURLRequestFailed(error: error))) }
            return
        }
        
        // 通知外界.
        rootQueue.async { request.didCreateInitialURLRequest(initialRequest) }
        
        guard !request.isCancelled else { return }
        
        guard let adapter = adapter(for: request) else {
            // 如果没有改造器, 就调用 didCreateURLRequest 进入下面的流程.
            rootQueue.async { self.didCreateURLRequest(initialRequest, for: request) }
            return
        }
        
        // 改造其改造 request,
        adapter.adapt(initialRequest, for: self) { result in
            do {
                let adaptedRequest = try result.get()
                try adaptedRequest.validate()
                
                // 在改造结束后, 调用 didCreateURLRequest 进入下一个流程.
                self.rootQueue.async {
                    request.didAdaptInitialRequest(initialRequest, to: adaptedRequest)
                    self.didCreateURLRequest(adaptedRequest, for: request)
                }
            } catch {
                self.rootQueue.async { request.didFailToAdaptURLRequest(initialRequest, withError: .requestAdaptationFailed(error: error)) }
            }
        }
    }
    
    // MARK: - Task Handling
    
    func didCreateURLRequest(_ urlRequest: URLRequest, for request: Request) {
        dispatchPrecondition(condition: .onQueue(rootQueue))
        
        request.didCreateURLRequest(urlRequest)
        guard !request.isCancelled else { return }
        
        // 使用 Request 的 task 方法, 不同的 Request 创建出不同的 DataTask 出来.
        // 真正执行网络交互的, 还是系统的 SessionTask 对象.
        let task = request.task(for: urlRequest, using: session)
        requestTaskMap[request] = task
        request.didCreateTask(task)
        updateStatesForTask(task, request: request)
    }
    
    func didReceiveResumeData(_ data: Data, for request: DownloadRequest) {
        dispatchPrecondition(condition: .onQueue(rootQueue))
        
        guard !request.isCancelled else { return }
        
        let task = request.task(forResumeData: data, using: session)
        requestTaskMap[request] = task
        request.didCreateTask(task)
        
        updateStatesForTask(task, request: request)
    }
    
    func updateStatesForTask(_ task: URLSessionTask, request: Request) {
        dispatchPrecondition(condition: .onQueue(rootQueue))
        
        request.withState { state in
            switch state {
            case .initialized, .finished:
                // Do nothing.
                break
            case .resumed:
                task.resume()
                rootQueue.async { request.didResumeTask(task) }
            case .suspended:
                task.suspend()
                rootQueue.async { request.didSuspendTask(task) }
            case .cancelled:
                // Resume to ensure metrics are gathered.
                task.resume()
                task.cancel()
                rootQueue.async { request.didCancelTask(task) }
            }
        }
    }
    
    /*
        整个过程, 都没有看到, 网络交互相关方法的实现.
        这说明, Session 并不关心这些业务.
        真正控制这些的代码, 在 DataRequest 之中.
     */
    
    // MARK: - Adapters and Retriers
    
    func adapter(for request: Request) -> RequestAdapter? {
        if let requestInterceptor = request.interceptor,
           let sessionInterceptor = interceptor {
            return Interceptor(adapters: [requestInterceptor, sessionInterceptor])
        } else {
            return request.interceptor ?? interceptor
        }
    }
    
    func retrier(for request: Request) -> RequestRetrier? {
        if let requestInterceptor = request.interceptor, let sessionInterceptor = interceptor {
            return Interceptor(retriers: [requestInterceptor, sessionInterceptor])
        } else {
            return request.interceptor ?? interceptor
        }
    }
    
    // MARK: - Invalidation
    
    func finishRequestsForDeinit() {
        requestTaskMap.requests.forEach { request in
            rootQueue.async {
                request.finish(error: AFError.sessionDeinitialized)
            }
        }
    }
}

// MARK: - RequestDelegate

extension Session: RequestDelegate {
    public var sessionConfiguration: URLSessionConfiguration {
        session.configuration
    }
    
    public var startImmediately: Bool { startRequestsImmediately }
    
    public func cleanup(after request: Request) {
        activeRequests.remove(request)
    }
    
    public func retryResult(for request: Request, dueTo error: AFError, completion: @escaping (RetryResult) -> Void) {
        // 首先, 查找有没有注册 retrier 来处理重试这种情况.
        guard let retrier = retrier(for: request) else {
            rootQueue.async { completion(.doNotRetry) }
            return
        }
        
        retrier.retry(request, for: self, dueTo: error) { retryResult in
            self.rootQueue.async {
                guard let retryResultError = retryResult.error else {
                    completion(retryResult);
                    return
                }
                let retryError = AFError.requestRetryFailed(retryError: retryResultError, originalError: error)
                completion(.doNotRetryWithError(retryError))
            }
        }
    }
    
    /*
     session 重启一个 Request, 就是将 Request 提交到 perform 方法里面.
     */
    public func retryRequest(_ request: Request, withDelay timeDelay: TimeInterval?) {
        rootQueue.async {
            let retry: () -> Void = {
                guard !request.isCancelled else { return }
                
                request.prepareForRetry()
                self.perform(request)
            }
            
            if let retryDelay = timeDelay {
                self.rootQueue.after(retryDelay) { retry() }
            } else {
                retry()
            }
        }
    }
}

// MARK: - SessionStateProvider

extension Session: SessionStateProvider {
    func request(for task: URLSessionTask) -> Request? {
        dispatchPrecondition(condition: .onQueue(rootQueue))
        
        return requestTaskMap[task]
    }
    
    func didGatherMetricsForTask(_ task: URLSessionTask) {
        dispatchPrecondition(condition: .onQueue(rootQueue))
        
        let didDisassociate = requestTaskMap.disassociateIfNecessaryAfterGatheringMetricsForTask(task)
        
        if didDisassociate {
            waitingCompletions[task]?()
            waitingCompletions[task] = nil
        }
    }
    
    func didCompleteTask(_ task: URLSessionTask, completion: @escaping () -> Void) {
        dispatchPrecondition(condition: .onQueue(rootQueue))
        
        let didDisassociate = requestTaskMap.disassociateIfNecessaryAfterCompletingTask(task)
        
        if didDisassociate {
            completion()
        } else {
            waitingCompletions[task] = completion
        }
    }
    
    func credential(for task: URLSessionTask, in protectionSpace: URLProtectionSpace) -> URLCredential? {
        dispatchPrecondition(condition: .onQueue(rootQueue))
        
        return requestTaskMap[task]?.credential ??
            session.configuration.urlCredentialStorage?.defaultCredential(for: protectionSpace)
    }
    
    func cancelRequestsForSessionInvalidation(with error: Error?) {
        dispatchPrecondition(condition: .onQueue(rootQueue))
        
        requestTaskMap.requests.forEach { $0.finish(error: AFError.sessionInvalidated(error: error)) }
    }
}
