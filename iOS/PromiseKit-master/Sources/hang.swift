import Foundation
import CoreFoundation

/*
 Runs the active run-loop until the provided promise resolves.

 This is for debug and is not a generally safe function to use in your applications. We mostly provide it for use in testing environments.

 Still if you like, study how it works (by reading the sources!) and use at your own risk.

 - Returns: The value of the resolved promise
 - Throws: An error, should the promise be rejected
 - See: `wait()`
*/
public func hang<T>(_ promise: Promise<T>) throws -> T {
    guard Thread.isMainThread else {
        fatalError("Only call hang() on the main thread.")
    }
    let runLoopMode: CFRunLoopMode = CFRunLoopMode.defaultMode

    // 这里的实现, 和 XCTest 的实现是一致的. 就是 promise 如果没有处于 resolved 的状态的话, 就一直处于 Runloop 的 run 中.
    if promise.isPending {
        var context = CFRunLoopSourceContext()
        let runLoop = CFRunLoopGetCurrent()
        let runLoopSource = CFRunLoopSourceCreate(nil, 0, &context)
        CFRunLoopAddSource(runLoop, runLoopSource, runLoopMode)

        _ = promise.ensure {
            CFRunLoopStop(runLoop)
        }

        while promise.isPending {
            CFRunLoopRun()
        }
        CFRunLoopRemoveSource(runLoop, runLoopSource, runLoopMode)
    }

    switch promise.result! {
    case .rejected(let error):
        throw error
    case .fulfilled(let value):
        return value
    }
}
