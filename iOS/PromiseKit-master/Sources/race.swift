import Dispatch

@inline(__always)

// 所有的 Thenables 都是一个类型的 Result 输出.
// 新建一个 Promise, 然后将自己注册到所有的 Thenables 的回调里面.
// 只要有一个 fullfill 了, 新建的 Promise 就 fullfil.
private func _race<U: Thenable>(_ thenables: [U]) -> Promise<U.T> {
    let rp = Promise<U.T>(.pending)
    for thenable in thenables {
        thenable.pipe(to: rp.box.seal)
    }
    return rp
}

/*
 Waits for one promise to resolve

     race(promise1, promise2, promise3).then { winner in
         //…
     }

 - Returns: The promise that resolves first
 - Warning: If the first resolution is a rejection, the returned promise is rejected
*/
public func race<U: Thenable>(_ thenables: U...) -> Promise<U.T> {
    return _race(thenables)
}

/*
 Waits for one promise to resolve

     race(promise1, promise2, promise3).then { winner in
         //…
     }

 - Returns: The promise that resolves first
 - Warning: If the first resolution is a rejection, the returned promise is rejected
 - Remark: If the provided array is empty the returned promise is rejected with PMKError.badInput
*/
public func race<U: Thenable>(_ thenables: [U]) -> Promise<U.T> {
    guard !thenables.isEmpty else {
        return Promise(error: PMKError.badInput)
    }
    return _race(thenables)
}

/*
 Waits for one guarantee to resolve
     race(promise1, promise2, promise3).then { winner in
         //…
     }
 - Returns: The guarantee that resolves first
*/
public func race<T>(_ guarantees: Guarantee<T>...) -> Guarantee<T> {
    let rg = Guarantee<T>(.pending)
    for guarantee in guarantees {
        guarantee.pipe(to: rg.box.seal)
    }
    return rg
}

/*
 Waits for one promise to fulfill

     race(fulfilled: [promise1, promise2, promise3]).then { winner in
         //…
     }

 - Returns: The promise that was fulfilled first.
 - Warning: Skips all rejected promises.
 - Remark: If the provided array is empty, the returned promise is rejected with `PMKError.badInput`. If there are no fulfilled promises, the returned promise is rejected with `PMKError.noWinner`.
*/

/*
    fulfilled 会等待, 所有的 promise 中出现了 fulfilled 的时候, 或者, 全部没有 fulfilled 的时候.
 */
public func race<U: Thenable>(fulfilled thenables: [U]) -> Promise<U.T> {
    var countdown = thenables.count
    guard countdown > 0 else {
        return Promise(error: PMKError.badInput)
    }

    let rp = Promise<U.T>(.pending)

    let barrier = DispatchQueue(label: "org.promisekit.barrier.race", attributes: .concurrent)

    for promise in thenables {
        promise.pipe { result in
            barrier.sync(flags: .barrier) {
                switch result {
                case .rejected:
                    guard rp.isPending else { return }
                    countdown -= 1
                    if countdown == 0 {
                        rp.box.seal(.rejected(PMKError.noWinner))
                    }
                case .fulfilled(let value):
                    // seal 这个函数, 是可以重复调用的.
                    // 所以这里应该进行预先的过滤操作.
                    guard rp.isPending else { return }
                    countdown = 0
                    rp.box.seal(.fulfilled(value))
                }
            }
        }
    }

    return rp
}
