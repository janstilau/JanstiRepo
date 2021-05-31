#if os(macOS)
import AppKit
#else
import UIKit
#endif

typealias DownloadResult = Result<ImageLoadingResult, KingfisherError>

// ImageLoadingResult, 里面存储了 Image, Data, 以及对应的 URL.
public struct ImageLoadingResult {

    /// The downloaded image.
    public let image: KFCrossPlatformImage

    /// Original URL of the image request.
    public let url: URL?

    /// The raw data received from downloader.
    public let originalData: Data
}

// DownloadTask 是一个盒子, 里面存储的是真正进行网络交互的 DataTask, 以及一个 token.
// 这个类型出现的意义, 就是这个 Token.
// 这里, 要思考明白, 引用值, 值, 引用语义, 值语义. 以及各个盒子的作用.
public struct DownloadTask {

    /// The `SessionDataTask` object bounded to this download task. Multiple `DownloadTask`s could refer
    /// to a same `sessionTask`. This is an optimization in Kingfisher to prevent multiple downloading task
    /// for the same URL resource at the same time.
    ///
    /// When you `cancel` a `DownloadTask`, this `SessionDataTask` and its cancel token will be pass through.
    /// You can use them to identify the cancelled task.
    public let sessionTask: SessionDataTask

    /// The cancel token which is used to cancel the task. This is only for identify the task when it is cancelled.
    /// To cancel a `DownloadTask`, use `cancel` instead.
    public let cancelToken: SessionDataTask.CancelToken

    /// Cancel this task if it is running. It will do nothing if this task is not running.
    ///
    /// - Note:
    /// In Kingfisher, there is an optimization to prevent starting another download task if the target URL is being
    /// downloading. However, even when internally no new session task created, a `DownloadTask` will be still created
    /// and returned when you call related methods, but it will share the session downloading task with a previous task.
    /// In this case, if multiple `DownloadTask`s share a single session download task, cancelling a `DownloadTask`
    /// does not affect other `DownloadTask`s.
    ///
    /// If you need to cancel all `DownloadTask`s of a url, use `ImageDownloader.cancel(url:)`. If you need to cancel
    /// all downloading tasks of an `ImageDownloader`, use `ImageDownloader.cancelAll()`.
    public func cancel() {
        sessionTask.cancel(token: cancelToken)
    }
}

extension DownloadTask {
    enum WrappedTask {
        case download(DownloadTask)
        case dataProviding

        func cancel() {
            switch self {
            case .download(let task): task.cancel()
            case .dataProviding: break
            }
        }

        var value: DownloadTask? {
            switch self {
            case .download(let task): return task
            case .dataProviding: return nil
            }
        }
    }
}

/// Represents a downloading manager for requesting the image with a URL from server.
// 这里, 才是真正触发了, 图片下载相关逻辑的所在. 
open class ImageDownloader {

    // MARK: Singleton
    /// The default downloader.
    public static let `default` = ImageDownloader(name: "default")

    // 这个值, 被传递到了 NSURLRequest 里面去了.
    open var downloadTimeout: TimeInterval = 15.0
    
    /// A set of trusted hosts when receiving server trust challenges. A challenge with host name contained in this
    /// set will be ignored. You can use this set to specify the self-signed site. It only will be used if you don't
    /// specify the `authenticationChallengeResponder`.
    ///
    /// If `authenticationChallengeResponder` is set, this property will be ignored and the implementation of
    /// `authenticationChallengeResponder` will be used instead.
    open var trustedHosts: Set<String>?
    
    /// Use this to set supply a configuration for the downloader. By default,
    /// NSURLSessionConfiguration.ephemeralSessionConfiguration() will be used.
    ///
    /// You could change the configuration before a downloading task starts.
    /// A configuration without persistent storage for caches is requested for downloader working correctly.
    // 这里, configure 的唯一要求, 就是不应该缓存数据.
    open var sessionConfiguration = URLSessionConfiguration.ephemeral {
        // 每次, 当 Session 相关的属性修改的时候, 都要重新生成一份
        didSet {
            session.invalidateAndCancel()
            session = URLSession(configuration: sessionConfiguration,
                                 delegate: sessionDelegate,
                                 delegateQueue: nil)
        }
    }
    
    // SessionDelegate, 是整个 Downloader 共同使用的, 而不是一个 DataTask 单独使用的.
    open var sessionDelegate: SessionDelegate {
        didSet {
            session.invalidateAndCancel()
            session = URLSession(configuration: sessionConfiguration,
                                 delegate: sessionDelegate,
                                 delegateQueue: nil)
            setupSessionHandler()
        }
    }
    
    /// Whether the download requests should use pipeline or not. Default is false.
    open var requestsUsePipelining = false

    /// Delegate of this `ImageDownloader` object. See `ImageDownloaderDelegate` protocol for more.
    // 这个协议, 没有找到实现类.
    open weak var delegate: ImageDownloaderDelegate?
    
    /// A responder for authentication challenge. 
    /// Downloader will forward the received authentication challenge for the downloading session to this responder.
    open weak var authenticationChallengeResponder: AuthenticationChallengeResponsable?

    private let name: String
    private var session: URLSession

    // MARK: Initializers

    /// Creates a downloader with name.
    ///
    /// - Parameter name: The name for the downloader. It should not be empty.
    public init(name: String) {
        if name.isEmpty {
            fatalError("[Kingfisher] You should specify a name for the downloader. "
                + "A downloader with empty name is not permitted.")
        }

        self.name = name

        // SessionDelegate 专门去应对 session 的各种回调方法, 在 sessionDelegate 的内部, 设置了各种业务回调.
        // 这些业务回调, 会触发 ImageDownloader 的方法.
        sessionDelegate = SessionDelegate()
        session = URLSession(
            configuration: sessionConfiguration,
            delegate: sessionDelegate,
            delegateQueue: nil)

        authenticationChallengeResponder = self
        setupSessionHandler()
    }

    deinit { session.invalidateAndCancel() }

    // 配置 SessionDelegate 的回调.
    // 这里其实就是, 设置 SessionDelegate 的 delegate, 只不过是, SessionDelegate 将自己所需要的配置点, 都变为了一个 Delegate 对象.
    // 这样做的麻烦的点就是, 每次新生成一个值, 都是要重新的设置一遍各个 OnDelegate 的回调.
    private func setupSessionHandler() {
        sessionDelegate.onReceiveSessionChallenge.delegate(on: self) { (self, invoke) in
            self.authenticationChallengeResponder?.downloader(self, didReceive: invoke.1, completionHandler: invoke.2)
        }
        sessionDelegate.onReceiveSessionTaskChallenge.delegate(on: self) { (self, invoke) in
            self.authenticationChallengeResponder?.downloader(
                self, task: invoke.1, didReceive: invoke.2, completionHandler: invoke.3)
        }
        sessionDelegate.onValidStatusCode.delegate(on: self) { (self, code) in
            return (self.delegate ?? self).isValidStatusCode(code, for: self)
        }
        sessionDelegate.onDownloadingFinished.delegate(on: self) { (self, value) in
            let (url, result) = value
            do {
                let value = try result.get()
                self.delegate?.imageDownloader(self, didFinishDownloadingImageForURL: url, with: value, error: nil)
            } catch {
                self.delegate?.imageDownloader(self, didFinishDownloadingImageForURL: url, with: nil, error: error)
            }
        }
        sessionDelegate.onDidDownloadData.delegate(on: self) { (self, task) in
            return (self.delegate ?? self).imageDownloader(self, didDownload: task.mutableData, with: task)
        }
    }

    // Wraps `completionHandler` to `onCompleted` respectively.
    private func createCompletionCallBack(_ completionHandler: ((DownloadResult) -> Void)?) -> Delegate<DownloadResult, Void>? {
        return completionHandler.map { block -> Delegate<DownloadResult, Void> in

            let delegate =  Delegate<Result<ImageLoadingResult, KingfisherError>, Void>()
            delegate.delegate(on: self) { (self, callback) in
                block(callback)
            }
            return delegate
        }
    }

    private func createTaskCallback(
        _ completionHandler: ((DownloadResult) -> Void)?,
        options: KingfisherParsedOptionsInfo
    ) -> SessionDataTask.TaskCallback
    {
        return SessionDataTask.TaskCallback(
            onCompleted: createCompletionCallBack(completionHandler),
            options: options
        )
    }

    // 这里, 其实就是生成 Request 的操作.
    private func createDownloadContext(
        with url: URL,
        options: KingfisherParsedOptionsInfo,
        done: @escaping ((Result<DownloadingContext, KingfisherError>) -> Void)
    )
    {
        // 这里, 需要提前定义, 仅仅是因为后面有复用的需求.
        func checkRequestAndDone(r: URLRequest) {
            // There is a possibility that request modifier changed the url to `nil` or empty.
            // In this case, throw an error.
            guard let url = r.url,
                  !url.absoluteString.isEmpty else {
                done(.failure(KingfisherError.requestError(reason: .invalidURL(request: r))))
                return
            }

            done(.success(DownloadingContext(url: url, request: r, options: options)))
        }

        // Creates default request.
        var request = URLRequest(url: url,
                                 cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: downloadTimeout)
        request.httpShouldUsePipelining = requestsUsePipelining
 
        // 如果, 在 Options 里面设置了 requestModifier, 那么就有最后一个机会, 去修改 Request 的内容.
        // 在修改了之后, 调用传递过去的闭包, 来真正的触发图片的下载操作.
        // 在设计 RequestModifier 这个接口的时候, API 的设计者, 就按照异步的方式设计的.
        // 一个协议, 如果要实现的方法, 是接受一个闭包, 然后在做完协议的自己业务之后, 去调用这个闭包, 都可以认为, 这是一个异步协议.
        if let requestModifier = options.requestModifier {
            // 这里, 传递过去的闭包就是, 在 modify 一个 Request 之后, 还是继续走 check and done 的逻辑.
            requestModifier.modified(for: request) { result in
                guard let finalRequest = result else {
                    done(.failure(KingfisherError.requestError(reason: .emptyRequest)))
                    return
                }
                checkRequestAndDone(r: finalRequest)
            }
        } else {
            checkRequestAndDone(r: request)
        }
    }

    private func addDownloadTask(
        context: DownloadingContext,
        callback: SessionDataTask.TaskCallback
    ) -> DownloadTask
    {
        // Ready to start download. Add it to session task manager (`sessionHandler`)
        let downloadTask: DownloadTask
        if let existingTask = sessionDelegate.task(for: context.url) {
            downloadTask = sessionDelegate.append(existingTask, url: context.url, callback: callback)
        } else {
            // 这里的命名思路, 和自己在写 MCNetwork 的时候是一样的, 根据具体的业务, 给相关的对象增加前缀.
            let sessionDataTask = session.dataTask(with: context.request)
            sessionDataTask.priority = context.options.downloadPriority
            downloadTask = sessionDelegate.add(sessionDataTask, url: context.url, callback: callback)
        }
        return downloadTask
    }


    private func reportWillDownloadImage(url: URL, request: URLRequest) {
        delegate?.imageDownloader(self, willDownloadImageForURL: url, with: request)
    }

    private func reportDidDownloadImageData(result: Result<(Data, URLResponse?), KingfisherError>, url: URL) {
        var response: URLResponse?
        var err: Error?
        do {
            response = try result.get().1
        } catch {
            err = error
        }
        self.delegate?.imageDownloader(
            self,
            didFinishDownloadingImageForURL: url,
            with: response,
            error: err
        )
    }

    private func reportDidProcessImage(
        result: Result<KFCrossPlatformImage, KingfisherError>, url: URL, response: URLResponse?
    )
    {
        if let image = try? result.get() {
            self.delegate?.imageDownloader(self, didDownload: image, for: url, with: response)
        }

    }

    private func startDownloadTask(
        context: DownloadingContext,
        callback: SessionDataTask.TaskCallback
    ) -> DownloadTask
    {

        let downloadTask = addDownloadTask(context: context, callback: callback)

        let sessionTask = downloadTask.sessionTask
        guard !sessionTask.started else {
            return downloadTask
        }

        // 将, DataTask 的代理回调, 设置到了 Downloader 上.
        sessionTask.onTaskDone.delegate(on: self) { (self, done) in
            // Underlying downloading finishes.
            // result: Result<(Data, URLResponse?)>, callbacks: [TaskCallback]
            let (result, callbacks) = done

            // Before processing the downloaded data.
            self.reportDidDownloadImageData(result: result, url: context.url)

            switch result {
            // Download finished. Now process the data to an image.
            case .success(let (data, response)):
                let processor = ImageDataProcessor(
                    data: data,
                    callbacks: callbacks,
                    processingQueue: context.options.processingQueue
                )
                processor.onImageProcessed.delegate(on: self) { (self, done) in
                    // `onImageProcessed` will be called for `callbacks.count` times, with each
                    // `SessionDataTask.TaskCallback` as the input parameter.
                    // result: Result<Image>, callback: SessionDataTask.TaskCallback
                    let (result, callback) = done

                    self.reportDidProcessImage(result: result, url: context.url, response: response)

                    let imageResult = result.map { ImageLoadingResult(image: $0, url: context.url, originalData: data) }
                    let queue = callback.options.callbackQueue
                    queue.execute { callback.onCompleted?.call(imageResult) }
                }
                processor.process()

            case .failure(let error):
                callbacks.forEach { callback in
                    let queue = callback.options.callbackQueue
                    queue.execute { callback.onCompleted?.call(.failure(error)) }
                }
            }
        }

        reportWillDownloadImage(url: context.url, request: context.request)
        sessionTask.resume()
        return downloadTask
    }

    // MARK: Downloading Task
    /// Downloads an image with a URL and option. Invoked internally by Kingfisher. Subclasses must invoke super.
    ///
    /// - Parameters:
    ///   - url: Target URL.
    ///   - options: The options could control download behavior. See `KingfisherOptionsInfo`.
    ///   - completionHandler: Called when the download progress finishes. This block will be called in the queue
    ///                        defined in `.callbackQueue` in `options` parameter.
    /// - Returns: A downloading task. You could call `cancel` on it to stop the download task.
    @discardableResult
    open func downloadImage(
        with url: URL,
        options: KingfisherParsedOptionsInfo,
        completionHandler: ((Result<ImageLoadingResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        var downloadTask: DownloadTask?
        // 调用一个方法, 然后在方法调用的 complete 回调里面, 进行相关数据的修改.
        // 最后返回相关的数据.
        // 之前自己一直很抵触这种方法, 但是现在想一下, 这种写法有着更强的灵活性.
        createDownloadContext(with: url, options: options) { result in
            switch result {
            case .success(let context):
                // `downloadTask` will be set if the downloading started immediately. This is the case when no request
                // modifier or a sync modifier (`ImageDownloadRequestModifier`) is used. Otherwise, when an
                // `AsyncImageDownloadRequestModifier` is used the returned `downloadTask` of this method will be `nil`
                // and the actual "delayed" task is given in `AsyncImageDownloadRequestModifier.onDownloadTaskStarted`
                // callback.
                downloadTask = self.startDownloadTask(
                    context: context,
                    callback: self.createTaskCallback(completionHandler, options: options)
                )
                if let modifier = options.requestModifier {
                    modifier.onDownloadTaskStarted?(downloadTask)
                }
            case .failure(let error):
                options.callbackQueue.execute {
                    completionHandler?(.failure(error))
                }
            }
        }

        return downloadTask
    }

    /// Downloads an image with a URL and option.
    ///
    /// - Parameters:
    ///   - url: Target URL.
    ///   - options: The options could control download behavior. See `KingfisherOptionsInfo`.
    ///   - progressBlock: Called when the download progress updated. This block will be always be called in main queue.
    ///   - completionHandler: Called when the download progress finishes. This block will be called in the queue
    ///                        defined in `.callbackQueue` in `options` parameter.
    /// - Returns: A downloading task. You could call `cancel` on it to stop the download task.
    @discardableResult
    open func downloadImage(
        with url: URL,
        options: KingfisherOptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<ImageLoadingResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        var info = KingfisherParsedOptionsInfo(options)
        if let block = progressBlock {
            info.onDataReceived = (info.onDataReceived ?? []) + [ImageLoadingProgressSideEffect(block)]
        }
        return downloadImage(
            with: url,
            options: info,
            completionHandler: completionHandler)
    }

    /// Downloads an image with a URL and option.
    ///
    /// - Parameters:
    ///   - url: Target URL.
    ///   - options: The options could control download behavior. See `KingfisherOptionsInfo`.
    ///   - completionHandler: Called when the download progress finishes. This block will be called in the queue
    ///                        defined in `.callbackQueue` in `options` parameter.
    /// - Returns: A downloading task. You could call `cancel` on it to stop the download task.
    @discardableResult
    open func downloadImage(
        with url: URL,
        options: KingfisherOptionsInfo? = nil,
        completionHandler: ((Result<ImageLoadingResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        downloadImage(
            with: url,
            options: KingfisherParsedOptionsInfo(options),
            completionHandler: completionHandler
        )
    }
}

// MARK: Cancelling Task
extension ImageDownloader {

    /// Cancel all downloading tasks for this `ImageDownloader`. It will trigger the completion handlers
    /// for all not-yet-finished downloading tasks.
    ///
    /// If you need to only cancel a certain task, call `cancel()` on the `DownloadTask`
    /// returned by the downloading methods. If you need to cancel all `DownloadTask`s of a certain url,
    /// use `ImageDownloader.cancel(url:)`.
    public func cancelAll() {
        sessionDelegate.cancelAll()
    }

    /// Cancel all downloading tasks for a given URL. It will trigger the completion handlers for
    /// all not-yet-finished downloading tasks for the URL.
    ///
    /// - Parameter url: The URL which you want to cancel downloading.
    public func cancel(url: URL) {
        sessionDelegate.cancel(url: url)
    }
}

// Use the default implementation from extension of `AuthenticationChallengeResponsable`.
extension ImageDownloader: AuthenticationChallengeResponsable {}

// Use the default implementation from extension of `ImageDownloaderDelegate`.
extension ImageDownloader: ImageDownloaderDelegate {}

extension ImageDownloader {
    struct DownloadingContext {
        let url: URL
        let request: URLRequest
        let options: KingfisherParsedOptionsInfo
    }
}
