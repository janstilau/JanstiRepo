//
//  Sink.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
 如果把Rx中的流当做水，那么Sink就相当于每个水管水龙头的滤网，在出水之前进行最后的加工。
 Sink 的功能:
 1. 状态控制. 在内部一个 atomic Int, 表示当前自己的资源是否已经释放了
 2. 记录下一个 observer. 这个在自己完成功能的 transfom 之后, 将自己加工好的值, 传递给下一个节点.
    这里是使用了 forward 的方法. 而不是 subscribe.
    主要的区别是, 这是一个一对一的关系. Sink 作为 Observer, 接受信号, 完成自己的业务上的加工, 然后转交给后面的 Observer. 
 3. Cancelable 的记录, 自己本身是一个 Disposable, 在外界需要取消的时候, 调用记录的 Cancelable, 完成取消的操作. 释放自己管理的资源.
 */
class Sink<Observer: ObserverType>: Disposable {
    
    fileprivate let observer: Observer
    fileprivate let cancel: Cancelable
    private let disposed = AtomicInt(0)

    #if DEBUG
        private let synchronizationTracker = SynchronizationTracker()
    #endif

    init(observer: Observer, cancel: Cancelable) {
#if TRACE_RESOURCES
        _ = Resources.incrementTotal()
#endif
        self.observer = observer
        self.cancel = cancel
    }

    // 这个方法, 是将 Sink 中, 已经转化的事件, 传递到记录的原始的 observer 的过程.
    final func forwardOn(_ event: Event<Observer.Element>) {
        if isFlagSet(self.disposed, 1) {
            return
        }
        self.observer.on(event)
    }

    final func forwarder() -> SinkForward<Observer> {
        SinkForward(forward: self)
    }

    final var isDisposed: Bool {
        isFlagSet(self.disposed, 1)
    }

    func dispose() {
        fetchOr(self.disposed, 1)
        self.cancel.dispose()
    }

    deinit {
#if TRACE_RESOURCES
       _ =  Resources.decrementTotal()
#endif
    }
}

// 这个类, 就是 sink 里面存储的原始的 observer, 将原始的 forwarder 暴露出去, 那么 Sink 也就不起作用了.
final class SinkForward<Observer: ObserverType>: ObserverType {
    typealias Element = Observer.Element 

    private let forward: Sink<Observer>

    init(forward: Sink<Observer>) {
        self.forward = forward
    }

    final func on(_ event: Event<Element>) {
        switch event {
        case .next:
            self.forward.observer.on(event)
        case .error, .completed:
            self.forward.observer.on(event)
            self.forward.cancel.dispose()
        }
    }
}
