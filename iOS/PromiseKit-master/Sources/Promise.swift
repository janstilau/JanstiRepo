import class Foundation.Thread
import Dispatch

/*
 A `Promise` is a functional abstraction around a failable asynchronous operation.
 - See: `Thenable`
 
 Sealant 表示的是, 还没完成和已经完成.
 Sealant 被 Box 封装了一层, Box 体现的数据概念和 Sealant 一致的.
 Promise 表示的是, 结果成功了还是失败了. 无论是成功还是失败, 都是完成的状态.
 所以, Promise 还会有没有完成的状态.
 */

/*
 Promise，里面保存着某个未来才会结束的事件（通常是一个异步操作）的结果.
 并不是 Promise 里面有个异步操作, 而是异步操作的最后, 去操作 Promise 对象.
 比如网络请求, 在最后的 completion 里面, 调用 Promise 的 fullfil 或者 reject 方法, 来设置 Promise 的结果.
 Promise 里面, 存储的是后续的一系列回调方法, 或者最终自己的 Result 状态.
 异步操作里面, 引用到 Promise, 在合理的实际, 触发 Promise 的状态改变.
 由 Promise 来触发后续的逻辑.
 */


public final class Promise<T>: Thenable, CatchMixin {
    let box: Box<Result<T>>

    fileprivate init(box: SealedBox<Result<T>>) {
        self.box = box
    }

    // 使用一个值初始化 Promise, 就是 SealedBox, fullfilled 的状态.
    public static func value(_ value: T) -> Promise<T> {
        return Promise(box: SealedBox(value: .fulfilled(value)))
    }
    // 使用一个 Error 初始化 Promies, 就是 SealedBox, Rejected 的状态.
    public init(error: Error) {
        box = SealedBox(value: .rejected(error))
    }

    // Thenable 完成之后, 触发 Box. 而不是 Box 触发 Thenable.
    // 所以, 这里的限制是, U.T == T, 也就是 Thenable 的输出, 要和自己的 Result 的类型相同.
    public init<U: Thenable>(_ bridge: U) where U.T == T {
        box = EmptyBox()
        bridge.pipe(to: box.seal)
    }

    // 使用这个方法, 来开启一个异步操作. 在异步操作的合适的位置, 调用 resolver 的 fullfil 或者 reject 方法.
    // 从实现我们看出, 是将数据, 从 body 之外准备好, 然后在 body 内修改这些数据, 数据本身是 Box 相关的, 这样, box 改变状态之后, 触发自己存储的回调.
    public init(resolver body: (Resolver<T>) throws -> Void) {
        // Resolver 其实就是对于 Box 操作的封装, body 对于 Resolver 的操作, 其实就是对于 Box 的操作.
        // Box 又是 Promise 的成员变量状态值, 所以, body 里面, 能够直接影响到 Promiese.
        box = EmptyBox()
        let resolver = Resolver(box)
        do {
            try body(resolver)
        } catch {
            resolver.reject(error)
        }
    }

    // - Returns: a tuple of a new pending promise and its `Resolver`.
    public class func pending() -> (promise: Promise<T>,
                                    resolver: Resolver<T>) {
        // 非常诡异的写法, 生成了一个 Promise, 然后传递到闭包里面.
        // 闭包里面, 生成一个元组.
        // 在外界生成, 然后产生一个 Resolver, 返回元组不同一的结果吗.
        return { ($0, Resolver($0.box)) }(Promise<T>(.pending))
    }

    /*
        Pipe, 如果自己的状态改变了, 应该调用什么 Block.
     */
    public func pipe(to: @escaping(Result<T>) -> Void) {
        // 这里有一个 double check.
        switch box.inspect() {
        case .pending:
            // inspect 函数, 本身会有线程同步的考虑.
            // 所以这里是有一个 double check 的技术.
            // 首先, box.inspect()  获取到一个值, 进入到了逻辑分支里.
            // 然后 box.inspect {} 上锁, 并且在上锁后, 重新进行一次逻辑判断.
            // 锁内的代码是单独线程执行的, 这样, 就算有两个线程同时进入了 pending 分支, 因为一先一后的顺序, 后进入的线程, 还是能够确保使用的是准确的数据.
            box.inspect {
                switch $0 {
                case .pending(let handlers):
                    // 如果, 还在未 Resolved 的状态, 就把回调添加到 handlers 的数组里面.
                    handlers.append(to)
                case .resolved(let value):
                    to(value)
                }
            }
        case .resolved(let value):
            to(value)
        }
    }

    // 获取当前的结果. 如果是 Pending 状态的时候, 就是 nil.
    // 如果是 resolved 的状态, 一定有值.
    public var result: Result<T>? {
        switch box.inspect() {
        case .pending:
            return nil // 如果, 还是 pending 状态, 就没有结果.
        case .resolved(let result):
            return result // 只有, 明显的进行了 Resolved, 才能获取到对应的结果.
        }
    }

    // 一个非常特殊的初始化方法. (Promise<T>(.pending)) 能够编译成功的基础.
    // 不太明白, 为什么不是 init().
    init(_: PMKUnambiguousInitializer) {
        box = EmptyBox()
    }
}

public extension Promise {
    /*
     Blocks this thread, so—you know—don’t call this on a serial thread that
     any part of your chain may use.
     Like the main thread for example.
     */
    
    func wait() throws -> T {

        if Thread.isMainThread {
            conf.logHandler(LogEvent.waitOnMainThread)
        }

        var result = self.result

        if result == nil {
            let group = DispatchGroup()
            group.enter()
            // 如果, 自己的状态从 Pending 到 Resolved 之后,
            pipe {
                result = $0
                group.leave()
            }
            group.wait()
        }

        switch result! {
        case .rejected(let error):
            throw error
        case .fulfilled(let value):
            return value
        }
    }
}

#if swift(>=3.1)
extension Promise where T == Void {
    /// Initializes a new promise fulfilled with `Void`
    public convenience init() {
        self.init(box: SealedBox(value: .fulfilled(Void())))
    }

    /// Returns a new promise fulfilled with `Void`
    public static var value: Promise<Void> {
        return .value(Void())
    }
}
#endif


public extension DispatchQueue {
    /**
     Asynchronously executes the provided closure on a dispatch queue.

         DispatchQueue.global().async(.promise) {
             try md5(input)
         }.done { md5 in
             //…
         }

     - Parameter body: The closure that resolves this promise.
     - Returns: A new `Promise` resolved by the result of the provided closure.
     - Note: There is no Promise/Thenable version of this due to Swift compiler ambiguity issues.
     */
    @available(macOS 10.10, iOS 8.0, tvOS 9.0, watchOS 2.0, *)
    
    /*
        DispatchQueue的扩展, 通过一个特殊类型的变量, 复用了原有的 async 方法.
        PMKNamespacer 就如同 type traits 一样, 仅仅是为了方法分发用的. 这个类型, 没有任何的意义.
     */
    final func async<T>(_: PMKNamespacer,
                        group: DispatchGroup? = nil,
                        qos: DispatchQoS = .default,
                        flags: DispatchWorkItemFlags = [],
                        execute body: @escaping () throws -> T) -> Promise<T> {

        // 从这里, 可以看出平时自定义一个返回 Promise 是怎么实现的.
        // 生成一个空的 Promise. 然后在异步操作中, 去修改这个 Promise 的状态.
        // 返回这个 promise, 这样, 外界就可以使用 promise 去收集后续的回调了.
        let promise = Promise<T>(.pending)
        async(group: group, qos: qos, flags: flags) {
            do {
                promise.box.seal(.fulfilled(try body()))
            } catch {
                promise.box.seal(.rejected(error))
            }
        }
        return promise
    }
}


/// used by our extensions to provide unambiguous functions with the same name as the original function
public enum PMKNamespacer {
    case promise
}

enum PMKUnambiguousInitializer {
    case pending
}
