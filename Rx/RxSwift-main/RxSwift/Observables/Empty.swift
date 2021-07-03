//
//  Empty.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/30/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
 一个特殊的类型.
 Subscribte 直接就是发送一个 complete 信号给后面的流.
 */
extension ObservableType {
    /**
     Returns an empty observable sequence, using the specified scheduler to send out the single `Completed` message.

     - seealso: [empty operator on reactivex.io](http://reactivex.io/documentation/operators/empty-never-throw.html)

     - returns: An observable sequence with no elements.
     */
    public static func empty() -> Observable<Element> {
        EmptyProducer<Element>()
    }
}

final private class EmptyProducer<Element>: Producer<Element> {
    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        // 在添加监听器的时候, 直接调用了监听器的 complete 处理函数.
        // 返回一个 NoDisposable 对象.
        observer.on(.completed)
        return Disposables.create()
    }
}
