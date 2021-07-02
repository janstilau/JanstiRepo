//
//  BehaviorSubject.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 5/23/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a value that changes over time.
///
/// Observers can subscribe to the subject to receive the last (or initial) value and all subsequent notifications.
public final class BehaviorSubject<Element>
    : Observable<Element>
    , SubjectType
    , ObserverType
    , SynchronizedUnsubscribeType
    , Cancelable {
    
    public typealias SubjectObserverType = BehaviorSubject<Element>

    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType
    
    /// Indicates whether the subject has any observers
    public var hasObservers: Bool {
        self.lock.performLocked { self.observers.count > 0 }
    }
    
    
    // 自带一把锁做线程控制.
    let lock = RecursiveLock()
    
    // state
    private var disposed = false // 代表着, 自己被 dispose 了, 和 stoppedEvent 是两个概念.
    private var element: Element // 必然会有一个值, 初始化的时候, 就 init 了.
    // 存储了所有的 Observer 到自己的内部, 这是当做 Publisher 的基础.
    // 当调用 Subscribe 的时候, 就是将新获得的 Observer 添加到这个成员变量里面.
    private var observers = Observers()
    private var stoppedEvent: Event<Element>? // Optional, 即表示了已经停止, 也存储了触发停止状态的 Event 的数据.

    /// Indicates whether the subject has been disposed.
    public var isDisposed: Bool {
        self.disposed
    }
 
    // 必须要有一个值. 当 Observer 添加的时候, 将这个值, 传递给 Observer.
    public init(value: Element) {
        self.element = value
    }
    
    /// Gets the current value or throws an error.
    ///
    /// - returns: Latest value.
    
    // 必然会有一个值, 但是如果状态不对, 抛出错误.
    public func value() throws -> Element {
        self.lock.lock()
        defer { self.lock.unlock() }
        
        
        if self.isDisposed {
            throw RxError.disposed(object: self)
        }
        
        if let error = self.stoppedEvent?.error {
            // intentionally throw exception
            throw error
        } else {
            return self.element
        }
    }
    
    /// Notifies all subscribed observers about next event.
    ///
    /// - parameter event: Event to send to the observers.
    
    /*
        作为 Subject, 他接收到信号的基本操作, 就是将数据转交给存储的 Observers.
     */
    public func on(_ event: Event<Element>) {
        dispatch(self.synchronized_on(event), event)
    }

    // synchronized_on 这个函数, 实际的作用是, 提取可以处理事件的 Observers.
    // 这里做的事情比较做, 还增加了对于 stoppedEvent 的记录. 不是太好的做法.
    func synchronized_on(_ event: Event<Element>) -> Observers {
        self.lock.lock(); defer { self.lock.unlock() }
        if self.stoppedEvent != nil || self.isDisposed {
            return Observers()
        }
        
        switch event {
        case .next(let element):
            // 在 Next 信号里面, 不断地更新存储的 Element
            self.element = element
        case .error, .completed:
            self.stoppedEvent = event
        }
        
        return self.observers
    }
    
    /// Subscribes an observer to the subject.
    ///
    /// - parameter observer: Observer to subscribe to the subject.
    /// - returns: Disposable object that can be used to unsubscribe the observer from the subject.
    public override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.lock.performLocked { self.synchronized_subscribe(observer) }
    }

    // 返回一个特殊的 Disposable, 这个 Disposable 的主要作用, 是 Observer 从存储的 Observers 中删除.
    func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        if self.isDisposed {
            observer.on(.error(RxError.disposed(object: self)))
            return Disposables.create()
        }
        
        if let stoppedEvent = self.stoppedEvent {
            observer.on(stoppedEvent)
            return Disposables.create()
        }
        
        let key = self.observers.insert(observer.on)
        observer.on(.next(self.element))
    
        return SubscriptionDisposable(owner: self, key: key)
    }

    func synchronizedUnsubscribe(_ disposeKey: DisposeKey) {
        self.lock.performLocked { self.synchronized_unsubscribe(disposeKey) }
    }

    func synchronized_unsubscribe(_ disposeKey: DisposeKey) {
        if self.isDisposed {
            return
        }

        _ = self.observers.removeKey(disposeKey)
    }

    /// Returns observer interface for subject.
    public func asObserver() -> BehaviorSubject<Element> {
        self
    }

    /// Unsubscribe all observers and release resources.
    public func dispose() {
        self.lock.performLocked {
            self.disposed = true
            self.observers.removeAll()
            self.stoppedEvent = nil
        }
    }

    #if TRACE_RESOURCES
        deinit {
        _ = Resources.decrementTotal()
        }
    #endif
}
