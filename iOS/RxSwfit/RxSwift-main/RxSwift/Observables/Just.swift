//
//  Just.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/30/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    /**
     Returns an observable sequence that contains a single element.

     - seealso: [just operator on reactivex.io](http://reactivex.io/documentation/operators/just.html)

     - parameter element: Single element in the resulting observable sequence.
     - returns: An observable sequence containing the single specified element.
     */
    public static func just(_ element: Element) -> Observable<Element> {
        Just(element: element)
    }

    /**
     Returns an observable sequence that contains a single element.

     - seealso: [just operator on reactivex.io](http://reactivex.io/documentation/operators/just.html)

     - parameter element: Single element in the resulting observable sequence.
     - parameter scheduler: Scheduler to send the single element on.
     - returns: An observable sequence containing the single specified element.
     */
    public static func just(_ element: Element, scheduler: ImmediateSchedulerType) -> Observable<Element> {
        JustScheduled(element: element, scheduler: scheduler)
    }
}

final private class JustScheduledSink<Observer: ObserverType>: Sink<Observer> {
    typealias Parent = JustScheduled<Observer.Element>

    private let parent: Parent

    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }

    func run() -> Disposable {
        let scheduler = self.parent.scheduler
        return scheduler.schedule(self.parent.element) { element in
            self.forwardOn(.next(element))
            return scheduler.schedule(()) { _ in
                self.forwardOn(.completed)
                self.dispose()
                return Disposables.create()
            }
        }
    }
}

final private class JustScheduled<Element>: Producer<Element> {
    fileprivate let scheduler: ImmediateSchedulerType
    fileprivate let element: Element

    init(element: Element, scheduler: ImmediateSchedulerType) {
        self.scheduler = scheduler
        self.element = element
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = JustScheduledSink(parent: self, observer: observer, cancel: cancel)
        let subscription = sink.run()
        return (sink: sink, subscription: subscription)
    }
}

// Just 会存储传递过来的值.
final private class Just<Element>: Producer<Element> {
    private let element: Element
    
    init(element: Element) {
        self.element = element
    }
    
    // 这里, 直接复写了 producer 里面的 subscribe. 返回一个 NopDisposable 对象.
    // 这是因为, 在 subscribe 里面, 明确的调用了 on completed 事件.
    // observer 接收到了 completed 之后, 应该释放自己引用的资源.
    // 在 Subject 的类簇里面, 释放资源指的是, 所有的 observer 进行清空, 所有自己存储的 value 值进行清空.
    // 要记住, 是 observer 接收到 complete 事件之后, obverser 进行资源的清空.
    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        observer.on(.next(self.element))
        observer.on(.completed)
        return Disposables.create()
    }
}
