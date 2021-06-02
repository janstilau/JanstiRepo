import Dispatch

// 表达 Promise 状态的类型.
// 如果, 一个 Promise 还在等待结果, 那么它就是 Pending. Pending 下, 存储了所有的回调信息.
// 如果, 一个 Promise 被满足了, 那么状态就变为了 Resolved. Resolved 下, 存储了最终的结果.
enum Sealant<R> {
    case pending(Handlers<R>)
    case resolved(R)
}

// Handlers 用来保存, 当一个 Promise 从 Pending 状态, 改变到 Resolved 状态的时候, 应该触发的所有回调.
// 正是因为 bodies 将所有的回调都记录了下来. 才能多次使用同一个 Promise 进行 then.
final class Handlers<R> {
    var bodies: [(R) -> Void] = []
    func append(_ item: @escaping(R) -> Void) { bodies.append(item) }
}

// Promise 内, 存储的是 Box 作为数据成员.
// inspect -> 返回当前的状态.
// inspect(Block), 添加回调闭包.
// seal(_ : T), 将 Box 的状态, 变为 Resolved, 并且传递最终值.
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
// 这种 Box, 才可能进行状态的改变.
class EmptyBox<T>: Box<T> {
    
    private var sealant = Sealant<T>.pending(.init())
    /*
     concurrent:
     If this attribute is not present, the queue schedules tasks serially in first-in, first-out (FIFO) order.
     */
    private let barrier = DispatchQueue(label: "org.promisekit.barrier", attributes: .concurrent)

    // seal 函数, 将 Box 的状态从 Pending 变为 Resolved.
    override func seal(_ value: T) {
        var handlers: Handlers<T>!
        barrier.sync(flags: .barrier) {
            guard case .pending(let _handlers) = self.sealant else {
                return  // already fulfilled!
            }
            handlers = _handlers
            self.sealant = .resolved(value)
        }

        // 当有状态变化之后, 调用所有的回调.
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

    // 向 Sealant 中添加回调.
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
