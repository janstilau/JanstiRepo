//
//  Producer.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/20/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
  Producer 的主要作用, 是创建一个 Sink 对象.
  Sink 对象, 可以接受到上游的事件, 经过自己的业务处理, 例如 map 转化, filter 过滤, 然后交给自己的记录下游.
  Sink 对象的业务子类, 一般是一个 observer, 而 Sink 是一个 Disposable.
    Sink 的业务处理的时候, 可能会占用到资源. Sink 作为一个 Disposable, 他调用 dispose 的是为了有能力, 去释放这部分资源.
  将 Sink 的子类对象, 作为 Observer 注册到上游的过程中, 返回会一个 Disposable, 这个 Disposable 用于取消注册的行为, 这在 Subject 的实现里面很好理解.
 
  Producer, 将 Sink 安插在了 Source 和 Observer 之间, 所以产生了两个需要 dispose 的需求, 这就是 SinkDisposer 存在的意义.
  而每个 Producer 的 run 方法, 则是真正的产生 Sink, 将 Observer 注册给 Sink, 将 Sink subscribe 给 Source 的逻辑所在的地方.
 */
class Producer<Element>: Observable<Element> {
    override init() {
        super.init()
    }

    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        if !CurrentThreadScheduler.isScheduleRequired {
            // The returned disposable needs to release all references once it was disposed.
            let disposer = SinkDisposer()
            let sinkAndSubscription = self.run(observer, cancel: disposer)
            disposer.setSinkAndSubscription(sink: sinkAndSubscription.sink, subscription: sinkAndSubscription.subscription)

            return disposer
        }
        else {
            return CurrentThreadScheduler.instance.schedule(()) { _ in
                let disposer = SinkDisposer()
                let sinkAndSubscription = self.run(observer, cancel: disposer)
                disposer.setSinkAndSubscription(sink: sinkAndSubscription.sink, subscription: sinkAndSubscription.subscription)

                return disposer
            }
        }
    }

    func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        rxAbstractMethod()
    }
}

private final class SinkDisposer: Cancelable {
    
    private enum DisposeState: Int32 {
        case disposed = 1
        case sinkAndSubscriptionSet = 2
    }

    // 这个状态, 其实主要的就是记录, 有没有被 dispose 过.
    private let state = AtomicInt(0)
    
    private var sink: Disposable?
    private var subscription: Disposable?

    var isDisposed: Bool {
        isFlagSet(self.state, DisposeState.disposed.rawValue)
    }

    func setSinkAndSubscription(sink: Disposable, subscription: Disposable) {
        
        self.sink = sink
        self.subscription = subscription

        let previousState = fetchOr(self.state, DisposeState.sinkAndSubscriptionSet.rawValue)
        if (previousState & DisposeState.sinkAndSubscriptionSet.rawValue) != 0 {
            rxFatalError("Sink and subscription were already set")
        }

        // 这里的逻辑标明, 这个类是不能够重用的.
        if (previousState & DisposeState.disposed.rawValue) != 0 {
            sink.dispose()
            subscription.dispose()
            self.sink = nil
            self.subscription = nil
        }
    }

    // 这个类, 是 Produce subscribe 之后交给外界的. 所以, 真正外界使用的是 SinkDisposer 的 dispose 方法.
    // 在这里面, 将 sink, subscription 的 dispose 调用了一遍.
    func dispose() {
        // fetchOr(self.state, DisposeState.disposed.rawValue) 会改变 self.state 的值, 导致这里只会被调用一次.
        let previousState = fetchOr(self.state, DisposeState.disposed.rawValue)

        if (previousState & DisposeState.disposed.rawValue) != 0 {
            return
        }

        if (previousState & DisposeState.sinkAndSubscriptionSet.rawValue) != 0 {
            guard let sink = self.sink else {
                rxFatalError("Sink not set")
            }
            guard let subscription = self.subscription else {
                rxFatalError("Subscription not set")
            }

            sink.dispose()
            subscription.dispose()

            self.sink = nil
            self.subscription = nil
        }
    }
}
