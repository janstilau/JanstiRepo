//
//  Sink.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

// Sink 这个类, 里面会存储它后面的 observer 的指针
// 当接受到数据之后, 按照自己的方式对数据进行转化, 然后交给后面的 observer.
class Sink<Observer: ObserverType>: Disposable {
    
    fileprivate let observer: Observer // 下游的 observer, 当 sink 完成了数据转化之后, 将转化后的数据, 传递给下游的  observer
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

    final func forwardOn(_ event: Event<Observer.Element>) {
        #if DEBUG
            self.synchronizationTracker.register(synchronizationErrorMessage: .default)
            defer { self.synchronizationTracker.unregister() }
        #endif
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
