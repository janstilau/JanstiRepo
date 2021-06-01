import Dispatch

// 表达 Promise 状态的类型.
// T 表示 Promise 的结果.
// 如果, 一个 Promise 还在等待结果, 那么它就是 pending. 关联值就是所有对于这个结果感兴趣的 handlers.
// 如果, 一个 Promise 被满足了, 那么状态就变为了 resolved. 关联值, 就是这个 Promise 的期望值.

enum Sealant<T> {
    case pending(Handlers<T>)
    case resolved(T)
}

// R 表示 Promise 的结果.
// Handlers 里面, 存储的就是对 Promise 的结果感兴趣的闭包.
final class Handlers<T> {
    var bodies: [(T) -> Void] = []
    func append(_ item: @escaping(T) -> Void) { bodies.append(item) }
}

class Box<T> {
    func inspect() -> Sealant<T> { fatalError() } // 用户返回当前 Box 的 Promise 状态.
    func inspect(_: (Sealant<T>) -> Void) { fatalError() } // 向 Handler 里面, 添加方法.
    func seal(_: T) {} // 这个就是将 Box 的状态, 进行改变的函数.
}

// 一个已经封装好的 Box. 也就是, 它的状态已经变为了 Resolved 了, 已经包含了 Promise 的结果了. 已经无法对状态进行修改了.
// Value : T 就是 Promise 的结果.
final class SealedBox<T>: Box<T> {
    let value: T
    
    init(value: T) {
        self.value = value
    }
    
    override func inspect() -> Sealant<T> {
        return .resolved(value)
    }
}

// 空箱子, 等待往里面填充值.

class EmptyBox<T>: Box<T> {
    private var sealant = Sealant<T>.pending(.init())
    private let barrier = DispatchQueue(label: "org.promisekit.barrier", attributes: .concurrent)
    
    // 将 Box 的状态, 从 Pending 变为 Resolve
    // 必须是在 Pending 状态调用该方法.
    override func seal(_ value: T) {
        var handlers: Handlers<T>!
        barrier.sync(flags: .barrier) {
            guard case .pending(let _handlers) = self.sealant else {
                return  // already fulfilled!
            }
            handlers = _handlers
            self.sealant = .resolved(value)
            // 在 barrier 里面, 完成状态的改变.
        }
        
        // 在 barrier, 完成各个闭包的调用.
        //FIXME we are resolved so should `pipe(to:)` be called at this instant, “thens are called in order” would be invalid
        //NOTE we don’t do this in the above `sync` because that could potentially deadlock
        //THOUGH since `then` etc. typically invoke after a run-loop cycle, this issue is somewhat less severe
        
        if let handlers = handlers {
            handlers.bodies.forEach{ $0(value) }
        }
    }
    
    override func inspect() -> Sealant<T> {
        var rv: Sealant<T>!
        barrier.sync {
            rv = self.sealant
        }
        return rv
    }
    
    override func inspect(_ body: (Sealant<T>) -> Void) {
        var sealed = false
        barrier.sync(flags: .barrier) {
            switch sealant {
            case .pending:
                // body will append to handlers, so we must stay barrier’d
                body(sealant)
            case .resolved:
                sealed = true
            }
        }
        if sealed {
            // we do this outside the barrier to prevent potential deadlocks
            // it's safe because we never transition away from this state
            body(sealant)
        }
    }
}


extension Optional where Wrapped: DispatchQueue {
    @inline(__always)
    func async(flags: DispatchWorkItemFlags?, _ body: @escaping() -> Void) {
        switch self {
        case .none:
            body()
        case .some(let q):
            if let flags = flags {
                q.async(flags: flags, execute: body)
            } else {
                q.async(execute: body)
            }
        }
    }
}
