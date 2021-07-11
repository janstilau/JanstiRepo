import Foundation

/*
 Sesstion 这个类, 作用和 AFN 的 SessionManager 的作用应该差不多.
 */
open class Session {
    /*
     一个单例, 简单的网络请求使用, 里面使用默认的数据作为配置.
     因为 swift 里面, static 的构建, 自动加入到了 once 中, 所以, 一定是单例对象.
     */
    public static let `default` = Session()
    
    /*
        Session 这个类, 作为网络请求的管理者, 里面做了 Alamofire 的逻辑处理. 真正的网络请求, 还是要调用系统的 URLSession 进行处理.
     */
    public let session: URLSession
    /*
        Session 里面, 主要是做的各个网络任务的状态管理.
        真正面对 URLSession 的回调的时候, 是交给了 SessionDelegate 做分发操作.
        而在 SessionDelegate 内部, 又进行了分发的操作.
     */
    public let delegate: SessionDelegate
    
    /*
        所有的, 对于 Session 内部状态的修改, 都是在 rootQueue 中.
        使用 DispatchQueue 的好处在于, Queue 的 Serial 可以保证, 数据的线程安全.
        Async 的特性, 可以使得各种方法的调用, 仅仅是进行任务的提交, 真正的任务, 可以在线程池里面在进行修改.
     */
    public let rootQueue: DispatchQueue
    
    
    // 这个值, 控制了当 DataRequest 接收到 response 的 Handler 的时候, 是否立马开启 dataTask
    public let startRequestsImmediately: Bool
    
    // 这个 Queue, 主要是用来, 做 Request 的初始化操作了.
    public let requestQueue: DispatchQueue
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
        // 如果, 没有设置 requestQueue 或者 serializationQueue, 那么就将创建一个以 RootQueue 为 target 的 Queue.
        self.requestQueue = requestQueue ?? DispatchQueue(label: "\(rootQueue.label).requestQueue", target: rootQueue)
        self.serializationQueue = serializationQueue ?? DispatchQueue(label: "\(rootQueue.label).serializationQueue", target: rootQueue)
        self.interceptor = interceptor
        self.serverTrustManager = serverTrustManager
        self.redirectHandler = redirectHandler
        self.cachedResponseHandler = cachedResponseHandler
        
        // defaultEventMonitors 就是 Notification Monitor.
        // 将 Notification, 当做一个特殊的 Monitor 来进行处理, 使得抽象得到了统一.
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
        // 将, 传递过来的 delegate, 直接变为 URLSession 的 delegate.
        // 这样, Apple 的有关网络的所有的回调, 才会被传输到 SessionDelegate 对象中去.
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
        // Cancels all outstanding tasks and then invalidates the session.
        session.invalidateAndCancel()
        /*
         This method returns immediately without waiting for tasks to finish. Once a session is invalidated, new tasks cannot be created in the session, but existing tasks continue until completion. After the last task finishes and the session makes the last delegate call related to those tasks, the session calls the urlSession(_:didBecomeInvalidWithError:) method on its delegate, then breaks references to the delegate and callback objects. After invalidation, session objects cannot be reused.
         session.finishTasksAndInvalidate()
         */
    }
    
    // MARK: - Cancellation
    
    /*
        取消当前的所有的 Request
        从实现里面我们看到, 是将真正的 Cancel 操作, 交给了 Request 类里面了.
        要习惯于这样的写法, 因为 Alamofire 里面, 都是这种异步操作.
     */
    public func cancelAllRequests(completingOnQueue queue: DispatchQueue = .main,
                                  completion: (() -> Void)? = nil) {
        rootQueue.async {
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
        ParameterEncoding 提供的抽象, 是将 NSDict 填充到 Request 里面.
        这个过程, 需要 RequestConvertible 进行封装.
        然后让 RequestConvertible 来实现 URLRequestConvertible 的抽象.
     */
    struct RequestConvertible: URLRequestConvertible {
        let url: URLConvertible // 获取到了 Url
        let method: HTTPMethod // 获取到了 Method
        let parameters: Parameters? // 获取到了所需的各种参数
        let encoding: ParameterEncoding // 将 Url, 参数转化成为 Request 的工具.
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
        return request(convertible, interceptor: interceptor)
    }
    
    
    
    /*
        ParameterEncoder 可以将一个 Encodable 的对象, 编码到了 NSUrlRequest 里面/
        这个过程, 被 RequestEncodableConvertible 封装, 然后 RequestEncodableConvertible 实现
        URLRequestConvertible 的抽象.
     */
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
    
    
    
    /*
        无论, Request 是通过 URLEncode 生成的, 还是通过 Encoder 生成的. 最终都会来到这个方法.
        这是 Session 生成 Request 的一个入口函数. 在这个入口函数里面, 将 Request 添加到自己的流程控制中.
     */
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
    
    /*
        PerformRequest 里面, 都会走 performSetupOperations, 只不过是不同的 Request, 各有着自己独特的初始化操作.
     */
    func performDataRequest(_ request: DataRequest) {
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
                
                self.rootQueue.async {
                    request.didAdaptInitialRequest(initialRequest, to: adaptedRequest)
                    // 在改造结束之后, 还是会使用 didCreateURLRequest 进入到下一个流程
                    self.didCreateURLRequest(adaptedRequest, for: request)
                }
            } catch {
                self.rootQueue.async { request.didFailToAdaptURLRequest(initialRequest, withError: .requestAdaptationFailed(error: error)) }
            }
        }
    }
    
    // MARK: - Task Handling
    // 所有的这些, 都是异步操作. 由上一个异步操作的结尾进行触发.
    // 虽然在时间线上, 不是线性的, 但是在逻辑上, 是线性发生的.
    func didCreateURLRequest(_ urlRequest: URLRequest, for request: Request) {
        dispatchPrecondition(condition: .onQueue(rootQueue))
        
        request.didCreateURLRequest(urlRequest)
        guard !request.isCancelled else { return }
        
        /*
            当 URLRequest 创建出来之后, 立马就进行了 DataTask 的创建工作.
            而 Request 和 DataTask 的映射, 是在 Session 里面进行的管理.
            DataRequest 还是数据类, 存储的是各种动作.
            DataTask 是控制逻辑类. 不应该将 DataTask 的各种回调在 DataRequest 中触发.
         */
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
    
    /*
        所谓的 clean, 就是将映射进行删除.
     */
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
