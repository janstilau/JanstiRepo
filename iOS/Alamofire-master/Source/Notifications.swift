import Foundation

/*
 RawRepresentable 这个协议, 彻底的将原始值, 和类型值进行了区分.
 
 一个专门的类型, 表达一个含义, 虽然, Notification.Name 里面仅仅是一个 string, 但是它是一个专门的类型, 在各个 API 传入的时候, 都有类型的检查操作.
 专门建立一个 static 类型的全局量, 表示某个值, 和专门建立一个 原始类型的全局量, 表达这个值, 在使用上没有什么差别, 但是 类型值带有类型信息, 让使用者更加明确自己操作的是什么东西.
 
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

// 专门用一个特殊的 key, 作为 Notification 里面 userinfo 的取值 key 值.
// 这个值只会在这个文件里面用到, 外界使用的, 是这个值服务的外部接口.
// Extension 一个原始类型, 然后 private, 或者 fileprivate 是一个非常常用的做法.
extension String {
    fileprivate static let requestKey = "org.alamofire.notification.key.request"
}

/// `EventMonitor` that provides Alamofire's notifications.
/*
    AlamofireNotifications: EventMonitor
    这个类就是在相应的各个方法被调用的时候, 发送相应的通知.
    各个通知的发送, 就是在特定的时间点, 发送信号到外界而已. 这个含义, 正符合 EventMonitor 这个接口的含义.
 */

/*
    通知, 就是在特定的事件发生之后, 广播通知所有对于该事件感兴趣的对象.
    该对象在接收到通知之后, 触发自己的逻辑.
    这件事在 AFN 时代, 是写到了业务代码里面, 在 ALAMOFIRE 里面, 有一个 EventMonitor 作为事件的接受者,
    AlamofireNotifications 作为整个协议的实现者. 在各个协议方法里面, 是最真正的广播的行为.
 */
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
