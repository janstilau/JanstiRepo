import Foundation

/*
 RawRepresentable 这个协议, 彻底的将原始值, 和类型值进行了区分.
 一个专门的类型, 表达一个含义, 虽然, Notification.Name 里面仅仅是一个 string, 但是它是一个专门的类型, 在各个 API 传入的时候, 都有类型的检查操作.
 专门建立一个 static 类型的全局量, 表示某个值, 和专门建立一个 原始类型的全局量, 表达这个值, 在使用上没有什么差别, 但是 类型值带有类型信息, 让使用者更加明确自己操作的是什么东西.
 extension 不仅仅是 category 的作用, 更多的是用于了区块的划分.
 之前 category 没有办法添加静态量, 导致的问题是, 必须将这些量, 作为一个全局量进行使用, 用 extern 在头文件里面进行表示.
 extension 的引入, 将这些全局量, 归并到一个合适的区块里面.
 */
public extension Request {
    /// Posted when a `Request` is resumed. The `Notification` contains the resumed `Request`.
    static let didResumeNotification = Notification.Name(rawValue: "org.alamofire.notification.name.request.didResume")
    /// Posted when a `Request` is suspended. The `Notification` contains the suspended `Request`.
    static let didSuspendNotification = Notification.Name(rawValue: "org.alamofire.notification.name.request.didSuspend")
    /// Posted when a `Request` is cancelled. The `Notification` contains the cancelled `Request`.
    static let didCancelNotification = Notification.Name(rawValue: "org.alamofire.notification.name.request.didCancel")
    /// Posted when a `Request` is finished. The `Notification` contains the completed `Request`.
    static let didFinishNotification = Notification.Name(rawValue: "org.alamofire.notification.name.request.didFinish")
    
    /// Posted when a `URLSessionTask` is resumed. The `Notification` contains the `Request` associated with the `URLSessionTask`.
    static let didResumeTaskNotification = Notification.Name(rawValue: "org.alamofire.notification.name.request.didResumeTask")
    /// Posted when a `URLSessionTask` is suspended. The `Notification` contains the `Request` associated with the `URLSessionTask`.
    static let didSuspendTaskNotification = Notification.Name(rawValue: "org.alamofire.notification.name.request.didSuspendTask")
    /// Posted when a `URLSessionTask` is cancelled. The `Notification` contains the `Request` associated with the `URLSessionTask`.
    static let didCancelTaskNotification = Notification.Name(rawValue: "org.alamofire.notification.name.request.didCancelTask")
    /// Posted when a `URLSessionTask` is completed. The `Notification` contains the `Request` associated with the `URLSessionTask`.
    static let didCompleteTaskNotification = Notification.Name(rawValue: "org.alamofire.notification.name.request.didCompleteTask")
}

// MARK: -

/*
 就算有特殊的 key, 但是通过 key 去 userInfo 检索的过程, 还是要写在代码里面
 如果能用方法来进行组装, 是最适合不过的了.
 方法应该定义在相关的位置上, 这样相关的逻辑, 也比较紧密.
 extension 简单的定义格式, 不需要 hm 文件的区分, 并且可以定义 init 方法, 将代码的划分, 变得更加清晰了.
 */
extension Notification {
    /// The `Request` contained by the instance's `userInfo`, `nil` otherwise.
    public var request: Request? {
        userInfo?[String.requestKey] as? Request
    }
    
    init(name: Notification.Name, request: Request) {
        self.init(name: name, object: nil, userInfo: [String.requestKey: request])
    }
}

extension NotificationCenter {
    func postNotification(named name: Notification.Name,
                          with request: Request) {
        let notification = Notification(name: name, request: request)
        post(notification)
    }
}

/*
 什么时候, 是 string 的 extension, 什么时候, 是 Notification 的 extension, 有点不太明白.
 */
extension String {
    /// User info dictionary key representing the `Request` associated with the notification.
    fileprivate static let requestKey = "org.alamofire.notification.key.request"
}

/// `EventMonitor` that provides Alamofire's notifications.
public final class AlamofireNotifications: EventMonitor {
    public func requestDidResume(_ request: Request) {
        NotificationCenter.default.postNotification(named: Request.didResumeNotification, with: request)
    }
    
    public func requestDidSuspend(_ request: Request) {
        NotificationCenter.default.postNotification(named: Request.didSuspendNotification, with: request)
    }
    
    public func requestDidCancel(_ request: Request) {
        NotificationCenter.default.postNotification(named: Request.didCancelNotification, with: request)
    }
    
    public func requestDidFinish(_ request: Request) {
        NotificationCenter.default.postNotification(named: Request.didFinishNotification, with: request)
    }
    
    public func request(_ request: Request, didResumeTask task: URLSessionTask) {
        NotificationCenter.default.postNotification(named: Request.didResumeTaskNotification, with: request)
    }
    
    public func request(_ request: Request, didSuspendTask task: URLSessionTask) {
        NotificationCenter.default.postNotification(named: Request.didSuspendTaskNotification, with: request)
    }
    
    public func request(_ request: Request, didCancelTask task: URLSessionTask) {
        NotificationCenter.default.postNotification(named: Request.didCancelTaskNotification, with: request)
    }
    
    public func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: AFError?) {
        NotificationCenter.default.postNotification(named: Request.didCompleteTaskNotification, with: request)
    }
}
