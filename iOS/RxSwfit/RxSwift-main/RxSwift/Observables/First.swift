//
//  First.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 7/31/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

private final class FirstSink<Element, Observer: ObserverType> : Sink<Observer>, ObserverType where Observer.Element == Element? {
    typealias Parent = First<Element>

    // 只会拿到第一个值交给后面, 然后就是 completed 事件了.
    // 前面, publisher 发送了 completed 时间, 后面的 observer 应该主动将自己的状态改变, 不再去处理新的事件了.
    func on(_ event: Event<Element>) {
        switch event {
        case .next(let value):
            self.forwardOn(.next(value))
            self.forwardOn(.completed)
            self.dispose()
        case .error(let error):
            self.forwardOn(.error(error))
            self.dispose()
        case .completed:
            self.forwardOn(.next(nil))
            self.forwardOn(.completed)
            self.dispose()
        }
    }
}

final class First<Element>: Producer<Element?> {
    private let source: Observable<Element>

    init(source: Observable<Element>) {
        self.source = source
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element? {
        let sink = FirstSink(observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
