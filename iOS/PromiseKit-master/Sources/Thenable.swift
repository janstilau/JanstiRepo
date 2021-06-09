import Dispatch

// Thenable represents an asynchronous operation that can be chained.

/*
    Then 仅仅是一个协议, 通过 pipe, 和 result 的限制, 完成了大量的核心方法.
    而 pipe 里面, 是真正的对于数据的管理.
 */

// Thenable 和核心概念, 就是给自己添加一个回调函数. 也就是 pipe 函数.
// Thenable 表示的结果, 为一个 Result.
public protocol Thenable: AnyObject {
    /// The type of the wrapped value
    // Thenable 表示的结果中, success 会产出的值的类型.
    associatedtype T

    /// `pipe` is immediately executed when this `Thenable` is resolved
    
    // 使用这个函数, 为 Thenable 增加一个回调函数.
    // 如果, 已经是 resolved 的状态, 就将存储的结果, 传递进去立马调用
    // 如果, 还是在 pending 的状态, 就存储这个回调, 在自己变为 resolved 的状态之后, 会逐个调用存储的闭包.
    func pipe(to: @escaping(Result<T>) -> Void)

    /// The resolved result or nil if pending.
    // 当前的 Thenable 的结果.
    var result: Result<T>? { get }
}

public extension Thenable {
    /*
     The provided closure executes when this promise is fulfilled.
     
     当 Promise Resolved 之后, 并且状态为 Fullfil 之后, 就会执行通过 then 添加上去的各种回调.
     这些回调, 接受 T 为参数.
     
     This allows chaining promises. The promise returned by the provided closure is resolved before the promise returned by this closure resolves.
     body 返回的 Promise 先触发, 它用来设置 返回值的 Promise. 然后返回值的 Promise, 用来触发后续的操作.
     - Parameter on: The queue to which the provided closure dispatches.
     - Parameter body: The closure that executes when this promise is fulfilled. It must return a promise.
     - Returns: A new promise that resolves when the promise returned from the provided closure resolves. For example:

           firstly {
               URLSession.shared.dataTask(.promise, with: url1)
           }.then { response in
               transform(data: response.data)
           }.done { transformation in
               //…
           }
     */
    
    /*
        自己变为 Resolved 状态, 会触发 pipe 里面的操作.
        触发的时候, 可能会引起 DispatchQueue 的调用.
        这个时候, 才会触发 Body 调用, 生成一个新的 Promise.
        这个新生成的 Promise, 可能是一个异步操作结果的封装. 所以 Body 里面, 很有可能还是一个异步操作. 这个异步操作到最后, 才会修改 Promise 的值.
        这个 Promise 的状态改变, 才会触发返回值 Promise 的状态改变.
        而返回值 Promise 状态改变之后, 才会触发后面的 then 添加的回调.
     */
    func then<U: Thenable>(on: DispatchQueue? = conf.Q.map,
                           flags: DispatchWorkItemFlags? = nil,
                           _ body: @escaping(T) throws -> U) -> Promise<U.T> {
        // 对于返回值 RP 来说, 他应该是 U.T 的, 这样, body 的结果, 才能直接传递到 RP 里面.
        // rv.pipe(to: rp.box.seal) 能够执行的基础, 也是他们的类型是一致的.
        let rp = Promise<U.T>(.pending)
        pipe {
            switch $0 {
            case .fulfilled(let value):
                on.async(flags: flags) {
                    do {
                        // rv 的出现, 是因为可能 body 是一个异步操作.
                        // Rv 代表的就是那个异步操作的结果.
                        let rv = try body(value)
                        guard rv !== rp else { throw PMKError.returnedSelf }
                        rv.pipe(to: rp.box.seal)
                    } catch {
                        rp.box.seal(.rejected(error))
                    }
                }
            case .rejected(let error):
                // 如果, 当前的失败了. 那么并不会触发 Body.
                // 而是直接将返回值 Promise 状态修改为 resolved(rejected)
                // 这样, 所有的这个 Promise 的 then 都会变为 rejected, 从而触发最终的 Catch.
                rp.box.seal(.rejected(error))
            }
        }
        return rp
    }

    /*
     The provided closure is executed when this promise is fulfilled.
     
     This is like `then` but it requires the closure to return a non-promise.
     
     - Parameter on: The queue to which the provided closure dispatches.
     - Parameter transform: The closure that is executed when this Promise is fulfilled. It must return a non-promise.
     - Returns: A new promise that is fulfilled with the value returned from the provided closure or rejected if the provided closure throws. For example:

           firstly {
               URLSession.shared.dataTask(.promise, with: url1)
           }.map { response in
               response.data.length
           }.done { length in
               //…
           }
     */
    func map<U>(on: DispatchQueue? = conf.Q.map,
                flags: DispatchWorkItemFlags? = nil,
                _ transform: @escaping(T) throws -> U) -> Promise<U> {
        let rp = Promise<U>(.pending)
        pipe {
            switch $0 {
            case .fulfilled(let value):
                on.async(flags: flags) {
                    do {
                        rp.box.seal(.fulfilled(try transform(value)))
                    } catch {
                        rp.box.seal(.rejected(error))
                    }
                }
            case .rejected(let error):
                rp.box.seal(.rejected(error))
            }
        }
        return rp
    }

    #if swift(>=4) && !swift(>=5.2)
    /*
     Similar to func `map<U>(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, _ transform: @escaping(T) throws -> U) -> Promise<U>`, but accepts a key path instead of a closure.
     
     - Parameter on: The queue to which the provided key path for value dispatches.
     - Parameter keyPath: The key path to the value that is using when this Promise is fulfilled.
     - Returns: A new promise that is fulfilled with the value for the provided key path.
     */
    func map<U>(on: DispatchQueue? = conf.Q.map,
                flags: DispatchWorkItemFlags? = nil,
                _ keyPath: KeyPath<T, U>) -> Promise<U> {
        // 就是一个特殊的 Map 的方式.
        // 从 (U)-> T
        // 变为了从 U 上, 使用特殊的 KeyPath 取 T .
        let rp = Promise<U>(.pending)
        pipe {
            switch $0 {
            case .fulfilled(let value):
                on.async(flags: flags) {
                    rp.box.seal(.fulfilled(value[keyPath: keyPath]))
                }
            case .rejected(let error):
                rp.box.seal(.rejected(error))
            }
        }
        return rp
    }
    #endif

    /*
      The provided closure is executed when this promise is fulfilled.

      In your closure return an `Optional`, if you return `nil` the resulting promise is rejected with `PMKError.compactMap`, otherwise the promise is fulfilled with the unwrapped value.

           firstly {
               URLSession.shared.dataTask(.promise, with: url)
           }.compactMap {
               try JSONSerialization.jsonObject(with: $0.data) as? [String: String]
           }.done { dictionary in
               //…
           }.catch {
               // either `PMKError.compactMap` or a `JSONError`
           }
     */
    // 和 Map 相比, 如果 compactMap 的 tranform 返回一个 nil. 那么, 就是 reject 的效果.
    func compactMap<U>(on: DispatchQueue? = conf.Q.map,
                       flags: DispatchWorkItemFlags? = nil,
                       _ transform: @escaping(T) throws -> U?) -> Promise<U> {
        let rp = Promise<U>(.pending)
        pipe {
            switch $0 {
            case .fulfilled(let value):
                on.async(flags: flags) {
                    do {
                        if let rv = try transform(value) {
                            rp.box.seal(.fulfilled(rv))
                        } else {
                            throw PMKError.compactMap(value, U.self)
                        }
                    } catch {
                        rp.box.seal(.rejected(error))
                    }
                }
            case .rejected(let error):
                rp.box.seal(.rejected(error))
            }
        }
        return rp
    }

    #if swift(>=4) && !swift(>=5.2)
    /*
    Similar to func `compactMap<U>(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, _ transform: @escaping(T) throws -> U?) -> Promise<U>`, but accepts a key path instead of a closure.
    
    - Parameter on: The queue to which the provided key path for value dispatches.
    - Parameter keyPath: The key path to the value that is using when this Promise is fulfilled. If the value for `keyPath` is `nil` the resulting promise is rejected with `PMKError.compactMap`.
    - Returns: A new promise that is fulfilled with the value for the provided key path.
    */
    // 一个特殊的 CompactMap. 使用 keypath 进行取值作为 transform.
    func compactMap<U>(on: DispatchQueue? = conf.Q.map,
                       flags: DispatchWorkItemFlags? = nil,
                       _ keyPath: KeyPath<T, U?>) -> Promise<U> {
        let rp = Promise<U>(.pending)
        pipe {
            switch $0 {
            case .fulfilled(let value):
                on.async(flags: flags) {
                    do {
                        if let rv = value[keyPath: keyPath] {
                            rp.box.seal(.fulfilled(rv))
                        } else {
                            throw PMKError.compactMap(value, U.self)
                        }
                    } catch {
                        rp.box.seal(.rejected(error))
                    }
                }
            case .rejected(let error):
                rp.box.seal(.rejected(error))
            }
        }
        return rp
    }
    #endif

    /*
     The provided closure is executed when this promise is fulfilled.
     
     Equivalent to `map { x -> Void in`, but since we force the `Void` return Swift
     is happier and gives you less hassle about your closure’s qualification.
     
     - Parameter on: The queue to which the provided closure dispatches.
     - Parameter body: The closure that is executed when this Promise is fulfilled.
     - Returns: A new promise fulfilled as `Void` or rejected if the provided closure throws.
     
           firstly {
               URLSession.shared.dataTask(.promise, with: url)
           }.done { response in
               print(response.data)
           }
     */
    func done(on: DispatchQueue? = conf.Q.return,
              flags: DispatchWorkItemFlags? = nil,
              _ body: @escaping(T) throws -> Void) -> Promise<Void> {
        // 当, Self Promise 的值改变之后, 会触发 pipe 的回调.
        // 这个回调, 就是调用 body 函数, 调用完之后, 就改变 rp 的值, 里面封装一个 ().
        // 这样, rp 的值改变, 就能触发后面的操作了.
        let rp = Promise<Void>(.pending)
        pipe {
            switch $0 {
            case .fulfilled(let value):
                on.async(flags: flags) {
                    do {
                        try body(value)
                        rp.box.seal(.fulfilled(()))
                    } catch {
                        rp.box.seal(.rejected(error))
                    }
                }
            case .rejected(let error):
                rp.box.seal(.rejected(error))
            }
        }
        return rp
    }

    /*
     The provided closure is executed when this promise is fulfilled.
     
     This is like `done` but it returns the same value that the handler is fed.
     `get` immutably accesses the fulfilled value; the returned Promise maintains that value.
     
     - Parameter on: The queue to which the provided closure dispatches.
     - Parameter body: The closure that is executed when this Promise is fulfilled.
     - Returns: A new promise that is fulfilled with the value that the handler is fed or rejected if the provided closure throws. For example:
     
           firstly {
               .value(1)
           }.get { foo in
               print(foo, " is 1")
           }.done { foo in
               print(foo, " is 1")
           }.done { foo in
               print(foo, " is Void")
           }
     */
    /*
        Body 是 T -> Void 的, 是因为, 实际上, Map 的 Closure 的签名是 T->T
     */
    func get(on: DispatchQueue? = conf.Q.return,
             flags: DispatchWorkItemFlags? = nil,
             _ body: @escaping (T) throws -> Void) -> Promise<T> {
        return map(on: on,
                   flags: flags) {
            try body($0)
            return $0
        }
    }

    /*
     The provided closure is executed with promise result.

     This is like `get` but provides the Result<T> of the Promise so you can inspect the value of the chain at this point without causing any side effects.

     - Parameter on: The queue to which the provided closure dispatches.
     - Parameter body: The closure that is executed with Result of Promise.
     - Returns: A new promise that is resolved with the result that the handler is fed. For example:

     promise.tap{ print($0) }.then{ /*…*/ }
     */
    func tap(on: DispatchQueue? = conf.Q.map,
             flags: DispatchWorkItemFlags? = nil,
             _ body: @escaping(Result<T>) -> Void) -> Promise<T> {
        // Promise 通过一个操作 Resolver 的闭包进行初始化.
        return Promise { seal in
            // seal 目前, 操作的就是新生成的 Promise 的 Box.
            // pipe 表明了, 只有 Self Resolved 之后, seal 才会修改当前生成的 Promise 的 Box. 才会触发后续的操作.
            pipe { result in
                on.async(flags: flags) {
                    body(result)
                    seal.resolve(result)
                }
            }
        }
    }

    /// - Returns: a new promise chained off this promise but with its value discarded.
    func asVoid() -> Promise<Void> {
        return map(on: nil) { _ in }
    }
}

public extension Thenable {
    /**
     - Returns: The error with which this promise was rejected; `nil` if this promise is not rejected.
     */
    var error: Error? {
        switch result {
        case .none:
            return nil
        case .some(.fulfilled):
            return nil
        case .some(.rejected(let error)):
            return error
        }
    }

    /**
     - Returns: `true` if the promise has not yet resolved.
     */
    var isPending: Bool {
        return result == nil
    }

    /**
     - Returns: `true` if the promise has resolved.
     */
    var isResolved: Bool {
        return !isPending
    }

    /**
     - Returns: `true` if the promise was fulfilled.
     */
    var isFulfilled: Bool {
        return value != nil
    }

    /**
     - Returns: `true` if the promise was rejected.
     */
    var isRejected: Bool {
        return error != nil
    }

    /**
     - Returns: The value with which this promise was fulfilled or `nil` if this promise is pending or rejected.
     */
    var value: T? {
        switch result {
        case .none:
            return nil
        case .some(.fulfilled(let value)):
            return value
        case .some(.rejected):
            return nil
        }
    }
}

public extension Thenable where T: Sequence {
    /**
     `Promise<[T]>` => `T` -> `U` => `Promise<[U]>`

         firstly {
             .value([1,2,3])
         }.mapValues { integer in
             integer * 2
         }.done {
             // $0 => [2,4,6]
         }
     */
    func mapValues<U>(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, _ transform: @escaping(T.Iterator.Element) throws -> U) -> Promise<[U]> {
        return map(on: on, flags: flags){ try $0.map(transform) }
    }

    #if swift(>=4) && !swift(>=5.2)
    /**
     `Promise<[T]>` => `KeyPath<T, U>` => `Promise<[U]>`

         firstly {
             .value([Person(name: "Max"), Person(name: "Roman"), Person(name: "John")])
         }.mapValues(\.name).done {
             // $0 => ["Max", "Roman", "John"]
         }
     */
    func mapValues<U>(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, _ keyPath: KeyPath<T.Iterator.Element, U>) -> Promise<[U]> {
        return map(on: on, flags: flags){ $0.map { $0[keyPath: keyPath] } }
    }
    #endif

    /**
     `Promise<[T]>` => `T` -> `[U]` => `Promise<[U]>`

         firstly {
             .value([1,2,3])
         }.flatMapValues { integer in
             [integer, integer]
         }.done {
             // $0 => [1,1,2,2,3,3]
         }
     */
    func flatMapValues<U: Sequence>(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, _ transform: @escaping(T.Iterator.Element) throws -> U) -> Promise<[U.Iterator.Element]> {
        return map(on: on, flags: flags){ (foo: T) in
            try foo.flatMap{ try transform($0) }
        }
    }

    /**
     `Promise<[T]>` => `T` -> `U?` => `Promise<[U]>`

         firstly {
             .value(["1","2","a","3"])
         }.compactMapValues {
             Int($0)
         }.done {
             // $0 => [1,2,3]
         }
     */
    func compactMapValues<U>(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, _ transform: @escaping(T.Iterator.Element) throws -> U?) -> Promise<[U]> {
        return map(on: on, flags: flags) { foo -> [U] in
          #if !swift(>=3.3) || (swift(>=4) && !swift(>=4.1))
            return try foo.flatMap(transform)
          #else
            return try foo.compactMap(transform)
          #endif
        }
    }

    #if swift(>=4) && !swift(>=5.2)
    /**
     `Promise<[T]>` => `KeyPath<T, U?>` => `Promise<[U]>`

         firstly {
             .value([Person(name: "Max"), Person(name: "Roman", age: 26), Person(name: "John", age: 23)])
         }.compactMapValues(\.age).done {
             // $0 => [26, 23]
         }
     */
    func compactMapValues<U>(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, _ keyPath: KeyPath<T.Iterator.Element, U?>) -> Promise<[U]> {
        return map(on: on, flags: flags) { foo -> [U] in
          #if !swift(>=4.1)
            return foo.flatMap { $0[keyPath: keyPath] }
          #else
            return foo.compactMap { $0[keyPath: keyPath] }
          #endif
        }
    }
    #endif

    /**
     `Promise<[T]>` => `T` -> `Promise<U>` => `Promise<[U]>`

         firstly {
             .value([1,2,3])
         }.thenMap { integer in
             .value(integer * 2)
         }.done {
             // $0 => [2,4,6]
         }
     */
    func thenMap<U: Thenable>(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, _ transform: @escaping(T.Iterator.Element) throws -> U) -> Promise<[U.T]> {
        return then(on: on, flags: flags) {
            when(fulfilled: try $0.map(transform))
        }
    }

    /**
     `Promise<[T]>` => `T` -> `Promise<[U]>` => `Promise<[U]>`

         firstly {
             .value([1,2,3])
         }.thenFlatMap { integer in
             .value([integer, integer])
         }.done {
             // $0 => [1,1,2,2,3,3]
         }
     */
    func thenFlatMap<U: Thenable>(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, _ transform: @escaping(T.Iterator.Element) throws -> U) -> Promise<[U.T.Iterator.Element]> where U.T: Sequence {
        return then(on: on, flags: flags) {
            when(fulfilled: try $0.map(transform))
        }.map(on: nil) {
            $0.flatMap{ $0 }
        }
    }

    /**
     `Promise<[T]>` => `T` -> Bool => `Promise<[T]>`

         firstly {
             .value([1,2,3])
         }.filterValues {
             $0 > 1
         }.done {
             // $0 => [2,3]
         }
     */
    func filterValues(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, _ isIncluded: @escaping (T.Iterator.Element) -> Bool) -> Promise<[T.Iterator.Element]> {
        return map(on: on, flags: flags) {
            $0.filter(isIncluded)
        }
    }

    #if swift(>=4) && !swift(>=5.2)
    /**
     `Promise<[T]>` => `KeyPath<T, Bool>` => `Promise<[T]>`

         firstly {
             .value([Person(name: "Max"), Person(name: "Roman", age: 26, isStudent: false), Person(name: "John", age: 23, isStudent: true)])
         }.filterValues(\.isStudent).done {
             // $0 => [Person(name: "John", age: 23, isStudent: true)]
         }
     */
    func filterValues(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, _ keyPath: KeyPath<T.Iterator.Element, Bool>) -> Promise<[T.Iterator.Element]> {
        return map(on: on, flags: flags) {
            $0.filter { $0[keyPath: keyPath] }
        }
    }
    #endif
}

public extension Thenable where T: Collection {
    /// - Returns: a promise fulfilled with the first value of this `Collection` or, if empty, a promise rejected with PMKError.emptySequence.
    var firstValue: Promise<T.Iterator.Element> {
        return map(on: nil) { aa in
            if let a1 = aa.first {
                return a1
            } else {
                throw PMKError.emptySequence
            }
        }
    }

    func firstValue(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, where test: @escaping (T.Iterator.Element) -> Bool) -> Promise<T.Iterator.Element> {
        return map(on: on, flags: flags) {
            for x in $0 where test(x) {
                return x
            }
            throw PMKError.emptySequence
        }
    }

    /// - Returns: a promise fulfilled with the last value of this `Collection` or, if empty, a promise rejected with PMKError.emptySequence.
    var lastValue: Promise<T.Iterator.Element> {
        return map(on: nil) { aa in
            if aa.isEmpty {
                throw PMKError.emptySequence
            } else {
                let i = aa.index(aa.endIndex, offsetBy: -1)
                return aa[i]
            }
        }
    }
}

public extension Thenable where T: Sequence, T.Iterator.Element: Comparable {
    /// - Returns: a promise fulfilled with the sorted values of this `Sequence`.
    func sortedValues(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil) -> Promise<[T.Iterator.Element]> {
        return map(on: on, flags: flags){ $0.sorted() }
    }
}
