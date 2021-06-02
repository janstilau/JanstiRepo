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
// seal(_ : T), 将 Box 的状态, 变为 Resolved, 并且传递最终值.
class Box<T> {
    func inspect() -> Sealant<T> { fatalError() } // 用户返回当前 Box 的 Promise 状态.
    func inspect(_: (Sealant<T>) -> Void) { fatalError() }
    func seal(_: T) {}
}

// 一个已经 Sealed 的 Box, 是无法再次修改自己的状态的.
final class SealedBox<T>: Box<T> {
    let value: T

    init(value: T) {
        self.value = value
    }

    override func inspect() -> Sealant<T> {
        return .resolved(value)
    }
}

class EmptyBox<T>: Box<T> {
    
    // EmptyBox 才可以进行数据的改变. 其实就是从 pending 到 resolved.
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
    }

    override func inspect() -> Sealant<T> {
        var rv: Sealant<T>!
        barrier.sync {
            rv = self.sealant
        }
        return rv
    }

    // 这里, 类似于 with 函数.
    // with 函数是取得自身的某个值, 然后将这个值传递到闭包里面调用.
    // 这里, inspect 是取得自己的 sealant 的值, 然后传到 body 里面被使用.
    // 这里, body 的调用, 是在线程安全的情况下.
    // 所以, body 是在锁的环境下执行的.
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


// 这里很像是 Wrapper Base 的模型.
// Optinal 是 Wrapper, 当它的 Base 是 DispatchQueue 的时候, 才可以使用这个方法.
// 各种操作, 都是交给关联的 Wrapped 值进行操作. Optinal 就是一个盒子而已.
// 这么看, Swfit 特别流行的 Wrapper Base 模式, 就是 Optinal 的仿造而已.
extension Optional where Wrapped: DispatchQueue {
    @inline(__always)
    func async(flags: DispatchWorkItemFlags?,
               _ body: @escaping() -> Void) {
        switch self {
        case .none:
            // 如果, 没有提供 queue, 就直接在当前线程进行 body 的调用, 没有线程切换
            body()
        case .some(let q):
            // 斗则, 就使用提供的 Queue 进行切换.
            if let flags = flags {
                q.async(flags: flags, execute: body)
            } else {
                q.async(execute: body)
            }
        }
    }
}
