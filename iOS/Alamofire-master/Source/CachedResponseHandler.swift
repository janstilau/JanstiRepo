import Foundation

/// A type that handles whether the data task should store the HTTP response in the cache.
public protocol CachedResponseHandler {
    /// Determines whether the HTTP response should be stored in the cache.
    ///
    /// The `completion` closure should be passed one of three possible options:
    ///
    ///   1. The cached response provided by the server (this is the most common use case).
    ///   2. A modified version of the cached response (you may want to modify it in some way before caching).
    ///   3. A `nil` value to prevent the cached response from being stored in the cache.
    ///
    /// - Parameters:
    ///   - task:       The data task whose request resulted in the cached response.
    ///   - response:   The cached response to potentially store in the cache.
    ///   - completion: The closure to execute containing cached response, a modified response, or `nil`.
    func dataTask(_ task: URLSessionDataTask,
                  willCacheResponse response: CachedURLResponse,
                  completion: @escaping (CachedURLResponse?) -> Void)
}

// MARK: -

/// `ResponseCacher` is a convenience `CachedResponseHandler` making it easy to cache, not cache, or modify a cached
/// response.
public struct ResponseCacher {
    /// Defines the behavior of the `ResponseCacher` type.
    public enum Behavior {
        /// Stores the cached response in the cache.
        case cache
        /// Prevents the cached response from being stored in the cache.
        case doNotCache
        /// Modifies the cached response before storing it in the cache.
        case modify((URLSessionDataTask, CachedURLResponse) -> CachedURLResponse?)
    }
    
    /// Returns a `ResponseCacher` with a follow `Behavior`.
    public static let cache = ResponseCacher(behavior: .cache)
    /// Returns a `ResponseCacher` with a do not follow `Behavior`.
    public static let doNotCache = ResponseCacher(behavior: .doNotCache)
    
    /// The `Behavior` of the `ResponseCacher`.
    public let behavior: Behavior
    
    /// Creates a `ResponseCacher` instance from the `Behavior`.
    ///
    /// - Parameter behavior: The `Behavior`.
    public init(behavior: Behavior) {
        self.behavior = behavior
    }
}

extension ResponseCacher: CachedResponseHandler {
    public func dataTask(_ task: URLSessionDataTask,
                         willCacheResponse response: CachedURLResponse,
                         completion: @escaping (CachedURLResponse?) -> Void) {
        switch behavior {
        case .cache:
            completion(response)
        case .doNotCache:
            completion(nil)
        case let .modify(closure):
            let response = closure(task, response)
            completion(response)
        }
    }
}
