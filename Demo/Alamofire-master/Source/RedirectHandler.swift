import Foundation

/// A type that handles how an HTTP redirect response from a remote server should be redirected to the new request.
public protocol RedirectHandler {
    /// Determines how the HTTP redirect response should be redirected to the new request.
    ///
    /// The `completion` closure should be passed one of three possible options:
    ///
    ///   1. The new request specified by the redirect (this is the most common use case).
    ///   2. A modified version of the new request (you may want to route it somewhere else).
    ///   3. A `nil` value to deny the redirect request and return the body of the redirect response.
    ///
    /// - Parameters:
    ///   - task:       The `URLSessionTask` whose request resulted in a redirect.
    ///   - request:    The `URLRequest` to the new location specified by the redirect response.
    ///   - response:   The `HTTPURLResponse` containing the server's response to the original request.
    ///   - completion: The closure to execute containing the new `URLRequest`, a modified `URLRequest`, or `nil`.
    func task(_ task: URLSessionTask,
              willBeRedirectedTo request: URLRequest,
              for response: HTTPURLResponse,
              completion: @escaping (URLRequest?) -> Void)
}

// MARK: -

/// `Redirector` is a convenience `RedirectHandler` making it easy to follow, not follow, or modify a redirect.
/*
    一个默认的处理重定向的类, 里面定义了如何处理重定向操作的一个 Enum. 根据这个 Enum 的值, 执行 重定向的操作.
 */
public struct Redirector {
    /// Defines the behavior of the `Redirector` type.
    public enum Behavior {
        /// Follow the redirect as defined in the response.
        case follow
        /// Do not follow the redirect defined in the response.
        case doNotFollow
        /// Modify the redirect request defined in the response.
        case modify((URLSessionTask, URLRequest, HTTPURLResponse) -> URLRequest?)
    }
    
    /// Returns a `Redirector` with a `.follow` `Behavior`.
    public static let follow = Redirector(behavior: .follow)
    /// Returns a `Redirector` with a `.doNotFollow` `Behavior`.
    public static let doNotFollow = Redirector(behavior: .doNotFollow)
    
    /// The `Behavior` of the `Redirector`.
    public let behavior: Behavior
    
    /// Creates a `Redirector` instance from the `Behavior`.
    ///
    /// - Parameter behavior: The `Behavior`.
    public init(behavior: Behavior) {
        self.behavior = behavior
    }
}

// MARK: -

extension Redirector: RedirectHandler {
    public func task(_ task: URLSessionTask,
                     willBeRedirectedTo request: URLRequest,
                     for response: HTTPURLResponse,
                     completion: @escaping (URLRequest?) -> Void) {
        switch behavior {
        case .follow:
            completion(request)
        case .doNotFollow:
            completion(nil)
        case let .modify(closure):
            let request = closure(task, request, response)
            completion(request)
        }
    }
}
