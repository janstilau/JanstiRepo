import Foundation

// Represents the delegate object of downloader session. It also behave like a task manager for downloading.
// 对于 OC 来说, 因为命名空间只有一个, 所以应该加上前缀.
@objc(KFSessionDelegate) // Fix for ObjC header name conflicting. https://github.com/onevcat/Kingfisher/issues/1530



open class SessionDelegate: NSObject {

    typealias SessionChallengeFunc = (
        URLSession,
        URLAuthenticationChallenge,
        (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    )

    typealias SessionTaskChallengeFunc = (
        URLSession,
        URLSessionTask,
        URLAuthenticationChallenge,
        (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    )
    
    // 这个类, 是管理着所有的图片下载任务的.
    // 所以, 在里面会有这样的一个映射表, 存储这 URL 和对应的 DataTask 对象的.
    private var tasks: [URL: SessionDataTask] = [:]
    private let lock = NSLock()

    // 各种, Delegate 对象, 其实就是一个 input -> output 的闭包的封装而已.
    let onValidStatusCode = Delegate<Int, Bool>()
    let onDownloadingFinished = Delegate<(URL, Result<URLResponse, KingfisherError>), Void>()
    let onDidDownloadData = Delegate<SessionDataTask, Data?>()

    let onReceiveSessionChallenge = Delegate<SessionChallengeFunc, Void>()
    let onReceiveSessionTaskChallenge = Delegate<SessionTaskChallengeFunc, Void>()

    // 这是开启一个新的下载任务的方法.
    // 触发的时机就是, 缓存内没图, 需要进行网络的交互.
    // 反会一个 DataTask 对象.
    func add(
        _ dataTask: URLSessionDataTask,
        url: URL,
        callback: SessionDataTask.TaskCallback) -> DownloadTask
    {
        lock.lock()
        defer { lock.unlock() }

        // Create a new task if necessary.
        let task = SessionDataTask(task: dataTask)
        task.onCallbackCancelled.delegate(on: self) { [weak task] (self, value) in
            guard let task = task else { return }

            let (token, callback) = value

            let error = KingfisherError.requestError(reason: .taskCancelled(task: task, token: token))
            task.onTaskDone.call((.failure(error), [callback]))
            // No other callbacks waiting, we can clear the task now.
            if !task.containsCallbacks {
                let dataTask = task.task

                self.cancelTask(dataTask)
                self.remove(task)
            }
        }
        let token = task.addCallback(callback)
        tasks[url] = task
        return DownloadTask(sessionTask: task, cancelToken: token)
    }

    private func cancelTask(_ dataTask: URLSessionDataTask) {
        lock.lock()
        defer { lock.unlock() }
        dataTask.cancel()
    }

    // 如果, 已经有了 DataTask, 那么一个新的回调就是, 将回调存储到对应的 DataTask 上.
    func append(
        _ task: SessionDataTask,
        url: URL,
        callback: SessionDataTask.TaskCallback) -> DownloadTask
    {
        let token = task.addCallback(callback)
        return DownloadTask(sessionTask: task, cancelToken: token)
    }

    private func remove(_ task: SessionDataTask) {
        lock.lock()
        defer { lock.unlock() }

        guard let url = task.originalURL else {
            return
        }
        tasks[url] = nil
    }

    private func task(for task: URLSessionTask) -> SessionDataTask? {
        lock.lock()
        defer { lock.unlock() }

        guard let url = task.originalRequest?.url else {
            return nil
        }
        guard let sessionTask = tasks[url] else {
            return nil
        }
        guard sessionTask.task.taskIdentifier == task.taskIdentifier else {
            return nil
        }
        return sessionTask
    }

    func task(for url: URL) -> SessionDataTask? {
        lock.lock()
        defer { lock.unlock() }
        return tasks[url]
    }

    func cancelAll() {
        lock.lock()
        let taskValues = tasks.values
        lock.unlock()
        for task in taskValues {
            task.forceCancel()
        }
    }

    func cancel(url: URL) {
        lock.lock()
        let task = tasks[url]
        lock.unlock()
        task?.forceCancel()
    }
}

// 这个类, 就是 URLSessionDataDelegate 的实现类.
// 并且, 在合适的时机, 去调用对应的 on 对象的各种方法.

extension SessionDelegate: URLSessionDataDelegate {

    open func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void)
    {
        guard let httpResponse = response as? HTTPURLResponse else {
            let error = KingfisherError.responseError(reason: .invalidURLResponse(response: response))
            onCompleted(task: dataTask, result: .failure(error))
            completionHandler(.cancel)
            return
        }

        let httpStatusCode = httpResponse.statusCode
        guard onValidStatusCode.call(httpStatusCode) == true else {
            let error = KingfisherError.responseError(reason: .invalidHTTPStatusCode(response: httpResponse))
            onCompleted(task: dataTask, result: .failure(error))
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let task = self.task(for: dataTask) else {
            return
        }
        
        task.didReceiveData(data)
        
        task.callbacks.forEach { callback in
            callback.options.onDataReceived?.forEach { sideEffect in
                sideEffect.onDataReceived(session, task: task, data: data)
            }
        }
    }

    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let sessionTask = self.task(for: task) else { return }

        if let url = sessionTask.originalURL {
            let result: Result<URLResponse, KingfisherError>
            if let error = error {
                result = .failure(KingfisherError.responseError(reason: .URLSessionError(error: error)))
            } else if let response = task.response {
                result = .success(response)
            } else {
                result = .failure(KingfisherError.responseError(reason: .noURLResponse(task: sessionTask)))
            }
            onDownloadingFinished.call((url, result))
        }

        let result: Result<(Data, URLResponse?), KingfisherError>
        if let error = error {
            result = .failure(KingfisherError.responseError(reason: .URLSessionError(error: error)))
        } else {
            if let data = onDidDownloadData.call(sessionTask) {
                result = .success((data, task.response))
            } else {
                result = .failure(KingfisherError.responseError(reason: .dataModifyingFailed(task: sessionTask)))
            }
        }
        onCompleted(task: task, result: result)
    }

    open func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    {
        onReceiveSessionChallenge.call((session, challenge, completionHandler))
    }

    open func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    {
        onReceiveSessionTaskChallenge.call((session, task, challenge, completionHandler))
    }
    
    open func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void)
    {
        guard let sessionDataTask = self.task(for: task),
              let redirectHandler = Array(sessionDataTask.callbacks).last?.options.redirectHandler else
        {
            completionHandler(request)
            return
        }
        
        redirectHandler.handleHTTPRedirection(
            for: sessionDataTask,
            response: response,
            newRequest: request,
            completionHandler: completionHandler)
    }

    private func onCompleted(task: URLSessionTask,
                             result: Result<(Data, URLResponse?), KingfisherError>) {
        guard let sessionTask = self.task(for: task) else {
            return
        }
        remove(sessionTask)
        sessionTask.onTaskDone.call((result, sessionTask.callbacks))
    }
}
