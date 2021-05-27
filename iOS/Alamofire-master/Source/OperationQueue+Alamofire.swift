import Foundation

extension OperationQueue {
    /// Creates an instance using the provided parameters.
    ///
    /// - Parameters:
    ///   - qualityOfService:            `QualityOfService` to be applied to the queue. `.default` by default.
    ///   - maxConcurrentOperationCount: Maximum concurrent operations.
    ///                                  `OperationQueue.defaultMaxConcurrentOperationCount` by default.
    ///   - underlyingQueue: Underlying  `DispatchQueue`. `nil` by default.
    ///   - name:                        Name for the queue. `nil` by default.
    ///   - startSuspended:              Whether the queue starts suspended. `false` by default.
    convenience init(qualityOfService: QualityOfService = .default,
                     maxConcurrentOperationCount: Int = OperationQueue.defaultMaxConcurrentOperationCount,
                     underlyingQueue: DispatchQueue? = nil,
                     name: String? = nil,
                     startSuspended: Bool = false) {
        self.init()
        self.qualityOfService = qualityOfService
        self.maxConcurrentOperationCount = maxConcurrentOperationCount
        self.underlyingQueue = underlyingQueue
        self.name = name
        isSuspended = startSuspended
    }
}
