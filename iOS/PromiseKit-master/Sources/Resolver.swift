

// Resolver 就是对于 box 操作的封装.

public final class Resolver<T> {
    // 这里, Box 里面的 T 的类型, 是 Result<T>
    // 所以, Box 里面的 value 的类型, 不是 T, 而是 Result.
    // 所有的 box 值的设定, 都是传递一个 Result. 
    let box: Box<Result<T>>

    init(_ box: Box<Result<T>>) {
        self.box = box
    }

    deinit {
        if case .pending = box.inspect() {
            conf.logHandler(.pendingPromiseDeallocated)
        }
    }
}

public extension Resolver {
    
    // FullFill 就是将封装的 Box seal 到 Fullfilled 的状态.
    func fulfill(_ value: T) {
        box.seal(.fulfilled(value))
    }

    // reject 就是将封装的 Box seal 到 Rejected 的状态.
    func reject(_ error: Error) {
        box.seal(.rejected(error))
    }

    /// Resolves the promise with the provided result
    func resolve(_ result: Result<T>) {
        box.seal(result)
    }

    // 如果有 error, 就是 reject, 如果有 obj, 就是 fullfull
    // 否则, 就是一个默认的 error 进行 reject.
    func resolve(_ obj: T?, _ error: Error?) {
        if let error = error {
            reject(error)
        } else if let obj = obj {
            fulfill(obj)
        } else {
            reject(PMKError.invalidCallingConvention)
        }
    }

    /// Fulfills the promise with the provided value unless the provided error is non-nil
    func resolve(_ obj: T, _ error: Error?) {
        if let error = error {
            reject(error)
        } else {
            fulfill(obj)
        }
    }

    /// Resolves the promise, provided for non-conventional value-error ordered completion handlers.
    func resolve(_ error: Error?, _ obj: T?) {
        resolve(obj, error)
    }
}

#if swift(>=3.1)
extension Resolver where T == Void {
    /// Fulfills the promise unless error is non-nil
    public func resolve(_ error: Error?) {
        if let error = error {
            reject(error)
        } else {
            fulfill(())
        }
    }
#if false
    // disabled ∵ https://github.com/mxcl/PromiseKit/issues/990

    /// Fulfills the promise
    public func fulfill() {
        self.fulfill(())
    }
#else
    /// Fulfills the promise
    /// - Note: underscore is present due to: https://github.com/mxcl/PromiseKit/issues/990
    public func fulfill_() {
        self.fulfill(())
    }
#endif
}
#endif

#if swift(>=5.0)
extension Resolver {
    /// Resolves the promise with the provided result
    public func resolve<E: Error>(_ result: Swift.Result<T, E>) {
        switch result {
        case .failure(let error): self.reject(error)
        case .success(let value): self.fulfill(value)
        }
    }
}
#endif

// Result 表示, Promise 想要的结果. 要么是一个 成功状态下的 T, 要么是一个失败状态下的 Error.
public enum Result<T> {
    case fulfilled(T)
    case rejected(Error)
}

public extension PromiseKit.Result {
    var isFulfilled: Bool {
        switch self {
        case .fulfilled:
            return true
        case .rejected:
            return false
        }
    }
}
