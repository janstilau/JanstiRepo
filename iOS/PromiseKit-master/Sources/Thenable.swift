import Dispatch

// Thenable represents an asynchronous operation that can be chained.

/*
    Then 仅仅是一个协议, 通过 pipe, 和 result 的限制, 完成了大量的核心方法.
    而 pipe 里面, 是真正的对于数据的管理.
 */

// Thenable 核心概念:
// 给自己添加一个回调函数. 也就是 pipe 函数.
// 自己能够表现一个结果, Result 类型的, T 的实际数据类型.
public protocol Thenable: AnyObject {
    // The type of the wrapped value
    // Result 为 Fulfilled 的时候, 实际存储的类型.
    associatedtype T

    // 使用这个函数, 为 Thenable 增加一个回调函数.
    // 如果, 已经是 resolved 的状态, 就将存储的结果, 传递进去立马调用
    // 如果, 还是在 pending 的状态, 就存储这个回调, 在自己变为 resolved 的状态之后, 会逐个调用存储的闭包.
    func pipe(to: @escaping(Result<T>) -> Void)

    // 当前的 Thenable 的结果.
    var result: Result<T>? { get }
}

public extension Thenable {
    /*
     The provided closure executes when this promise is fulfilled.
     
     This allows chaining promises. The promise returned by the provided closure is resolved before the promise returned by this closure resolves.
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
        Thenable 就是来执行异步操作的.
        所以才会有 queue 的设置.
     */
    func then<U: Thenable>(on: DispatchQueue? = conf.Q.map,
                           flags: DispatchWorkItemFlags? = nil,
                           _ body: @escaping(T) throws -> U) -> Promise<U.T> {
        // 当前的 Thenable 的 Result Type 是 T, 所以 Body 里面参数类型是 T.
        // Body 必须返回一个 Promise.
        // Body 更多的是开启一个异步任务. 在异步任务开启前, 设置一个 Promise, 然后在异步任务的回调里面, 将 Promise 的值进行 resolve.
        // Body 返回的就是这个 Promise
        // 在 Then 里面, 是调用 Body. 只有自己 Resolved 之后, 才会去在 on queue 里面, 调用 Body 开启异步任务.
        // 这里做的和 Body 里面没有太大的区别.
        // Promise 作为结果的存储器, 是最终的 return 的值.
        // 而 Return promise 的值, 是需要被 resolved 的, 这个过程, 要到
        // 1. self resolved 之后, 判断当前的状态, 调用 Body 开启一个新的异步任务.
        // 2. 新的异步任务, resolve 之后, 才会调用 return promise 的 resolve 方法.
        
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
    /*
        相比较于 Then 里面, 开启了一个新的异步任务, 这里在 Self resolved 之后, 直接使用 transform 来获取变换的值.
        然后将这个值, 当做 Return Promise 的值进行了 seal.
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
    /*
        Done 是一个特殊的 Then. 接受的闭包, 不在对数据进行操作, 而是最终执行一个操作, 返回 Void.
        pipe 的参数, 会被存到 handler 里面. Body 仅仅是参数的一部分.
     */
    func done(on: DispatchQueue? = conf.Q.return,
              flags: DispatchWorkItemFlags? = nil,
              _ body: @escaping(T) throws -> Void) -> Promise<Void> {
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
        // 使用了 Map.
        // 也就是原来的 Result 值, 原封不动的传递. 在这个过程中, 执行了 Body 方法.
        // 一个中转的 Promise
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
    
    // Get 获取的是 fullfil 下的 value 值. 而 Tap 则是获取的 Result 值.
    func tap(on: DispatchQueue? = conf.Q.map,
             flags: DispatchWorkItemFlags? = nil,
             _ body: @escaping(Result<T>) -> Void) -> Promise<T> {
        // Promise 通过一个操作 Resolver 的闭包进行初始化.
        return Promise { seal in
            pipe { result in
                on.async(flags: flags) {
                    body(result)
                    seal.resolve(result)
                }
            }
        }
    }

    // - Returns: a new promise chained off this promise but with its value discarded.
    // AsVoid, 就是生成一个新的 Promise, 这个 Promise 会在原有的 Promise Fulfilled 之后调用 transform, 但是 value 是 Void.
    // 这个在 When 的实现里面, 使用的特别多.
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
