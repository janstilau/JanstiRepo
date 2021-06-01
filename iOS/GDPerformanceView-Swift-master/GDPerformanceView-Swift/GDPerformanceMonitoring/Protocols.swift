import UIKit

/// Memory usage tuple. Contains used and total memory in bytes.
public typealias MemoryUsage = (used: UInt64, total: UInt64)

/// Performance report tuple. Contains CPU usage in percentages, FPS and memory usage.
public typealias PerformanceReport = (cpuUsage: Double, fps: Int, memoryUsage: MemoryUsage)

/// Performance monitor delegate. Gets called on the main thread.
public protocol PerformanceMonitorDelegate: class {
    /// Reports monitoring information to the receiver.
    ///
    /// - Parameters:
    ///   - performanceReport: Performance report tuple. Contains CPU usage in percentages, FPS and memory usage.
    func performanceMonitor(didReport performanceReport: PerformanceReport)
}

public protocol PerformanceViewConfigurator {
    var options: PerformanceMonitor.DisplayOptions { get set }
    var userInfo: PerformanceMonitor.UserInfo { get set }
    var style: PerformanceMonitor.Style { get set }
    var interactors: [UIGestureRecognizer]? { get set }
}

public protocol StatusBarConfigurator {
    var statusBarHidden: Bool { get set }
    var statusBarStyle: UIStatusBarStyle { get set }
}
