import Dispatch

// 表达 Promise 状态的类型.
// R 表示 Promise 的结果.
// 如果, 一个 Promise 还在等待结果, 那么它就是 pending. 关联值就是所有对于这个结果感兴趣的 handlers.
// 如果, 一个 Promise 被满足了, 那么状态就变为了 resolved. 关联值, 就是这个 Promise 的期望值.
enum Sealant<R> {
    case pending(Handlers<R>)
    case resolved(R)
}

// R 表示 Promise 的结果.
// Handler 用于保存处理 Promise 结果的 handler.
final class Handlers<R> {
    var bodies: [(R) -> Void] = []
    func append(_ item: @escaping(R) -> Void) { bodies.append(item) }
}

/// - Remark: not protocol ∵ http://www.russbishop.net/swift-associated-types-cont
class Box<T> {
    func inspect() -> Sealant<T> { fatalError() } // 用户返回当前 Box 的 Promise 状态.
    func inspect(_: (Sealant<T>) -> Void) { fatalError() }
    func seal(_: T) {}
}

// 一个已经封装好的 Box. 也就是, 它的状态已经变为了 Resolved 了, 其中, 已经包含了 Promise 的结果了. 已经无法对状态进行修改了.
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

    override func seal(_ value: T) {
        var handlers: Handlers<T>!
        barrier.sync(flags: .barrier) {
            guard case .pending(let _handlers) = self.sealant else {
                return  // already fulfilled!
            }
            handlers = _handlers
            self.sealant = .resolved(value)
        }

        //FIXME we are resolved so should `pipe(to:)` be called at this instant, “thens are called in order” would be invalid
        //NOTE we don’t do this in the above `sync` because that could potentially deadlock
        //THOUGH since `then` etc. typically invoke after a run-loop cycle, this issue is somewhat less severe

        if let handlers = handlers {
            handlers.bodies.forEach{ $0(value) }
        }

        //TODO solution is an unfortunate third state “sealed” where then's get added
        // to a separate handler pool for that state
        // any other solution has potential races
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
