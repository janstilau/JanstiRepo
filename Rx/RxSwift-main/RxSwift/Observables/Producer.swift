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
  Sink 对象本身作为一个 Disposable, 是因为 Sink 对象在自己的业务处理时, 获取了一些资源, 最终需要释放.
  一般情况下, Sink 的 Dispose 仅仅是修改一下自己的状态.
 
  每个 Operator 其实是生成一个 Producer, Producer 仅仅是将数据进行收集, 并没有实际的生成事件序列的完成处理管道.
  当 Producer 的 subscribe 真正被调用的时候, 会生成一个 Sink 对象, 这个对象是真正的插入到信号的处理管道中的. 上游 source 调用 Subscribe(sink), 返回一个 subscription. 这个 subscription 是一个 Disposable, 用于将 Sink 取消订阅的行为.
  而这个 subscription, 其实是 SinkDisposer 这个类型. 这个类型, 存储了 Sink, 以及 source.Subscribe(sink) 的返回值. SinkDisposer 的 dispose 方法, 会调用这两个对象的 dispose. 所以 Sink 可以 dispose 释放自己的资源, Sink 也可以从 source 的信号处理中取消订阅.
 真正的处理管道, 是在最后一个 Producer 调用 subscribe 的时候生成的.
 在 map_1().map_2().subscribe(End) 这个例子中, map_2().subscribe() 生成了一个 Sink2 -> End, 在这个过程中, 调用 source->subscribe(Sink2), 这个 source, 就是 map_1 的 Producer. 所以会产生  Sink1 -> Sink2 -> End 这个管道. 在这个过程里面, Sink1 -> Sink2 的 subscription 会被记录到 Sink2 -> End 产生的 SinkDisposer中, 当做 Sink2 -> End 返回.
 这样, dispose 就是链表了, 最终调用方手里面拿到的 Sink2 -> End 的 subscription, 调用 dispose 的时候, 会一直往上调用, 一直到头的创建 Publisher 的时候返回的 Disposable 调用 Dispose.
 
 */

/*
    Producer 是一个 Publisher, 也就是它是一个可以发出信号的装置.
    而它产生的 Sink, 可能会是一个 Observer, 可以接受信号. 但是不会是一个 Publisher.
 
    Sink 仅仅是将, 信号, 进行操作, 然后交给注册给自己的下游而已. 并不能注册新的 subscriber 使用.
 */

class Producer<Element>: Observable<Element> {
    override init() {
        super.init()
    }

    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        if !CurrentThreadScheduler.isScheduleRequired {
            let disposer = SinkDisposer()
            let sinkAndSubscription = self.run(observer, cancel: disposer)
            disposer.setSinkAndSubscription(sink: sinkAndSubscription.sink,
                                            subscription: sinkAndSubscription.subscription)
            return disposer
        } else {
            return CurrentThreadScheduler.instance.schedule(()) { _ in
                let disposer = SinkDisposer()
                let sinkAndSubscription = self.run(observer, cancel: disposer)
                disposer.setSinkAndSubscription(sink: sinkAndSubscription.sink,
                                                subscription: sinkAndSubscription.subscription)
                return disposer
            }
        }
    }

    
    /*
        Run 处理的流程一般是:
        1. 从 Producer 里面, 读取收集的信息出来, 建造出真正添加到信号处理管道节点的 Sink 对象.
        1. 将这个 Sink 对象, source.subscrie(sink) 中, 获取返回的 subscription, 和 Sink 对象一起组成一个 SinkDisposer.
     
        所以, 实际的上, 不同业务种类的 Producer 真正运行相应业务逻辑的地方在 Sink 类里面.
     */
    func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        rxAbstractMethod()
    }
}

private final class SinkDisposer: Cancelable {
    
    private enum DisposeState: Int32 {
        case disposed = 1
        case sinkAndSubscriptionSet = 2
    }

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

        // 这里的逻辑标明, 对象只能被使用一次.
        if (previousState & DisposeState.disposed.rawValue) != 0 {
            sink.dispose()
            subscription.dispose()
            self.sink = nil
            self.subscription = nil
        }
    }

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
            
            // 在调用完 Sink 之后, 释放引用. 这是因为可能会有循环引用的问题.

            self.sink = nil
            self.subscription = nil
        }
    }
}
