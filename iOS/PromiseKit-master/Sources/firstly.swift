import Dispatch

/*
    URLSession.shared.dataTask(url: url1) 的返回结果本身就是一个 Promise.
    使用返回结果, 可以直接进行 then, done 等连接.
    Firstly 向其中增加了一个中间层.
    中间层去触发后面的操作, URLSession.shared.dataTask(url: url1) 触发中间层的启动.
    这样让代码变得更加的清晰简洁.
 */
/**
 Judicious use of `firstly` *may* make chains more readable.

 Compare:

     URLSession.shared.dataTask(url: url1).then {
         URLSession.shared.dataTask(url: url2)
     }.then {
         URLSession.shared.dataTask(url: url3)
     }

 With:

     firstly {
         URLSession.shared.dataTask(url: url1)
     }.then {
         URLSession.shared.dataTask(url: url2)
     }.then {
         URLSession.shared.dataTask(url: url3)
     }

 - Note: the block you pass executes immediately on the current thread/queue.
 */

// body 的函数签名不同, 会走不同的函数.
// 因为, throw 本质上是返回值不同, 所以, 同样的函数签名, 增加了 throw 的话, 其实是走不同的编译路线.


// 从这里可以看出, Promise 的作者为什么要设计这样一个中间层出来.
// Body 生成新的 Promise 的过程, 可能会发生错误. 也就是说, Body 的返回值是一个多状态的值, 而不仅仅是 Promise 类型.
// 而需要传出去的是一个 Promise, 所以, 需要特意的生成一个 Promise
// 如果 Body 成功, 就让 Body 的 Promise 来触发这个中间层的 Promise.
// 如果 Body 失败了, 就让中间层 Promise rejected. 触发后面的失败逻辑.
// 按照这个思路, do 外面生成一个 rp, 然后 catch 的时候, 设置 rp 的状态更好.

// Firstly 和 then 的主要区别就是, Firstly 的 body 是同步发生的. 而 Then 里面的逻辑, 是当前 Promise 决议之后, 才会触发的. 大概率是异步发生的.


public func firstly<U: Thenable>(execute body: () throws -> U) -> Promise<U.T> {
    do {
        let rp = Promise<U.T>(.pending)
        try body().pipe(to: rp.box.seal)
        return rp
    } catch {
        return Promise(error: error)
    }
}

/// - See: firstly()
public func firstly<T>(execute body: () -> Guarantee<T>) -> Guarantee<T> {
    return body()
}
