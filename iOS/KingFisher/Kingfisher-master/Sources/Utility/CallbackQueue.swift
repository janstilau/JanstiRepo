import Foundation

/// Represents callback queue behaviors when an calling of closure be dispatched.
///
/// - asyncMain: Dispatch the calling to `DispatchQueue.main` with an `async` behavior.
/// - currentMainOrAsync: Dispatch the calling to `DispatchQueue.main` with an `async` behavior if current queue is not
///                       `.main`. Otherwise, call the closure immediately in current main queue.
/// - untouch: Do not change the calling queue for closure.
/// - dispatch: Dispatches to a specified `DispatchQueue`.

/*
    将 Enum 当做 Container 使用的又一个例证.
    只有 .Dispatch 这种情况, 是真正的需要存储数据的.
    使用 Enum, 让代码更加的清晰.
 
    各种方法, 直接定义到了 Enum 的内部.
    也就是说, 这个类型主要的使用场景, 就是调用自己的方法, 而不是进行 Type 的区分.
    这个类型, 基本不会进入到 Switch case 中, 而是得到了 .case 的实例之后, 直接调用 execute 方法, 传入对应的闭包.
    在 Enum 的内部, 就是将对应的闭包, 传递到对应的 queue 的过程了.
 */

/*
    Swfit 的抽象, 很多方法是使用参数的行为.
    例如, PageView addTo, removeFrom, 都是使用 参数的 AddSubView, RemoveSubView 来进行相关页面的加载删除.
 */

public enum CallbackQueue {
    /// Dispatch the calling to `DispatchQueue.main` with an `async` behavior.
    case mainAsync
    /// Dispatch the calling to `DispatchQueue.main` with an `async` behavior if current queue is not
    /// `.main`. Otherwise, call the closure immediately in current main queue.
    case mainCurrentOrAsync
    /// Do not change the calling queue for closure.
    case untouch
    /// Dispatches to a specified `DispatchQueue`.
    case dispatch(DispatchQueue)
    
    public func execute(_ block: @escaping () -> Void) {
        switch self {
        case .mainAsync:
            // 虽然, async 的参数类型也是 () -> Void
            // 但这里, 没有直接将 block 传递到 async 里面, 而是又包装了一层.
            // 将 block 当做数据来看. 提交给 main queue 的是一个动作, 而这个动作, 是调用传递过来的函数数据.
            DispatchQueue.main.async { block() }
        case .mainCurrentOrAsync:
            DispatchQueue.main.safeAsync { block() }
        case .untouch:
            block()
        case .dispatch(let queue):
            // 这里, 才用到了 Enum 的存储属性, 将存储的 queue 提取出来, 将对于函数对象的调用, 放到对应的 queue 里面.
            queue.async { block() }
        }
    }

    // OperationQueue.current?.underlyingQueue 这句, 明显的暗示了, OperationQueue 的底层任务分派, 是通过了 GCD Queue 完成的.
    var queue: DispatchQueue {
        switch self {
        case .mainAsync: return .main
        case .mainCurrentOrAsync: return .main
        case .untouch: return OperationQueue.current?.underlyingQueue ?? .main
        case .dispatch(let queue): return queue
        }
    }
}

extension DispatchQueue {
    // This method will dispatch the `block` to self.
    // If `self` is the main queue, and current thread is main thread, the block
    // will be invoked immediately instead of being dispatched.
    func safeAsync(_ block: @escaping ()->()) {
        if self === DispatchQueue.main && Thread.isMainThread {
            block()
        } else {
            async { block() }
        }
    }
}
