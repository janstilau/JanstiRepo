import class Foundation.Thread
import Dispatch

/*
 A `Promise` is a functional abstraction around a failable asynchronous operation.
 - See: `Thenable`
 
 Sealant 表示的是, 还没完成和已经完成.
 Sealant 被 Box 封装了一层, Box 体现的数据概念和 Sealant 一致的.
 Promise 表示的是, 结果成功了还是失败了. 无论是成功还是失败, 都是完成的状态.
 所以, Promise 还会有没有完成的状态.
 Promise 的成员变量是 Box, 这个值, 本身带有三层含义.
 1. 没有完成, 存储了各种回调在 pending 状态的 handlers 里面
 2. 完成了. Resolved 的 Result 里面, 是 fullfil 的状态.
 3. 完成了. resolved 的 Result 里面, 是 Rejected 的状态.
 
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

    /// Initialize a new promise bound to the provided `Thenable`.
    // Thenable 完成之后, 触发 Box. 而不是 Box 触发 Thenable.
    public init<U: Thenable>(_ bridge: U) where U.T == T {
        box = EmptyBox()
        bridge.pipe(to: box.seal)
    }

    /// Initialize a new promise that can be resolved with the provided `Resolver`.
    public init(resolver body: (Resolver<T>) throws -> Void) {
        box = EmptyBox()
        let resolver = Resolver(box)
        do {
            try body(resolver)
        } catch {
            resolver.reject(error)
        }
    }

    /// - Returns: a tuple of a new pending promise and its `Resolver`.
    public class func pending() -> (promise: Promise<T>, resolver: Resolver<T>) {
        return { ($0, Resolver($0.box)) }(Promise<T>(.pending))
    }

    /*
        Promise 对于 Pipe 的实现.
        获取当前 sealant 的状态. 如果还是 pending, 就将回调, 添加到 handlers的 闭包数组里面.
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

    /// - See: `Thenable.result`
    public var result: Result<T>? {
        switch box.inspect() {
        case .pending:
            return nil // 如果, 还是 pending 状态, 就没有结果.
        case .resolved(let result):
            return result // 只有, 明显的进行了 Resolved, 才能获取到对应的结果.
        }
    }

    init(_: PMKUnambiguousInitializer) {
        box = EmptyBox()
    }
}

public extension Promise {
    /**
     Blocks this thread, so—you know—don’t call this on a serial thread that
     any part of your chain may use. Like the main thread for example.
     */
    func wait() throws -> T {

        if Thread.isMainThread {
            conf.logHandler(LogEvent.waitOnMainThread)
        }

        var result = self.result

        if result == nil {
            let group = DispatchGroup()
            group.enter()
            pipe { result = $0; group.leave() }
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
    final func async<T>(_: PMKNamespacer, group: DispatchGroup? = nil, qos: DispatchQoS = .default, flags: DispatchWorkItemFlags = [], execute body: @escaping () throws -> T) -> Promise<T> {
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
