import Foundation

/// Represents a session data task in `ImageDownloader`.
/// It consists of an underlying `URLSessionDataTask` and
/// an array of `TaskCallback`. Multiple `TaskCallback`s could be added for a single downloading data task.
public class SessionDataTask {

    /// Represents the type of token which used for cancelling a task.
    public typealias CancelToken = Int

    // 将回调这件事, 当做数据进行了存储.
    struct TaskCallback {
        let onCompleted: Delegate<Result<ImageLoadingResult, KingfisherError>, Void>?
        let options: KingfisherParsedOptionsInfo
    }

    /// Downloaded raw data of current task.
    public private(set) var mutableData: Data

    // This is a copy of `task.originalRequest?.url`. It is for getting a race-safe behavior for a pitfall on iOS 13.
    // Ref: https://github.com/onevcat/Kingfisher/issues/1511
    public let originalURL: URL?

    /// The underlying download task. It is only for debugging purpose when you encountered an error. You should not
    /// modify the content of this task or start it yourself.
    public let task: URLSessionDataTask
    private var callbacksStore = [CancelToken: TaskCallback]()

    var callbacks: [SessionDataTask.TaskCallback] {
        lock.lock()
        defer { lock.unlock() }
        
        return Array(callbacksStore.values)
    }

    private var currentToken = 0
    private let lock = NSLock()

    let onTaskDone = Delegate<(Result<(Data, URLResponse?), KingfisherError>, [TaskCallback]), Void>()
    let onCallbackCancelled = Delegate<(CancelToken, TaskCallback), Void>()

    var started = false
    var containsCallbacks: Bool {
        // We should be able to use `task.state != .running` to check it.
        // However, in some rare cases, cancelling the task does not change
        // task state to `.cancelling` immediately, but still in `.running`.
        // So we need to check callbacks count to for sure that it is safe to remove the
        // task in delegate.
        return !callbacks.isEmpty
    }

    init(task: URLSessionDataTask) {
        self.task = task
        self.originalURL = task.originalRequest?.url
        mutableData = Data()
    }

    func addCallback(_ callback: TaskCallback) -> CancelToken {
        lock.lock()
        defer { lock.unlock() }
        callbacksStore[currentToken] = callback
        defer { currentToken += 1 }
        return currentToken
    }

    func removeCallback(_ token: CancelToken) -> TaskCallback? {
        lock.lock()
        defer { lock.unlock() }
        if let callback = callbacksStore[token] {
            callbacksStore[token] = nil
            return callback
        }
        return nil
    }

    func resume() {
        guard !started else { return }
        started = true
        task.resume()
    }

    func cancel(token: CancelToken) {
        guard let callback = removeCallback(token) else {
            return
        }
        onCallbackCancelled.call((token, callback))
    }

    func forceCancel() {
        for token in callbacksStore.keys {
            cancel(token: token)
        }
    }

    func didReceiveData(_ data: Data) {
        mutableData.append(data)
    }
}
