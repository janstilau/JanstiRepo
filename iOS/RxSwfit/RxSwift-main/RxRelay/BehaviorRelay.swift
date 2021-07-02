//
//  BehaviorRelay.swift
//  RxRelay
//
//  Created by Krunoslav Zaher on 10/7/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import RxSwift

/// BehaviorRelay is a wrapper for `BehaviorSubject`.
///
/// Unlike `BehaviorSubject` it can't terminate with error or completed.

/*
    使用 BehaviorRelay 这个类型, 可以将基本数据类型的值, 转化为 信号源 .
    所有对于该数据感兴趣的事件, 都可以订阅到这个信号源.
    BehaviorRelay 的 accept 方法, 会改变这个值, 然后所有的注册事件, 就可以接收到这个信号, 然后处理后面的逻辑了.
 
    一定是 accept 方法调用, 直接修改 BehaviorRelay 中的值, 是不会引起响应式编码的.
 */

public final class BehaviorRelay<Element>: ObservableType {
    private let subject: BehaviorSubject<Element>

    /// Accepts `event` and emits it to subscribers
    public func accept(_ event: Element) {
        self.subject.onNext(event)
    }

    /// Current value of behavior subject
    // Behaviour, 可以进行取值.
    public var value: Element {
        // this try! is ok because subject can't error out or be disposed
        return try! self.subject.value()
    }

    /// Initializes behavior relay with initial value.
    // 使用 BehaviorRelay 需要添加一个初始值.
    public init(value: Element) {
        self.subject = BehaviorSubject(value: value)
    }

    /// Subscribes observer
    // BehaviorRelay 可以充当 ObservableType 的关键就在这里, 它提供了 subscribe 的接口.
    public func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.subject.subscribe(observer)
    }

    /// - returns: Canonical interface for push style sequence
    public func asObservable() -> Observable<Element> {
        self.subject.asObservable()
    }
}
