//
//  BehaviorSubject.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 5/23/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

// 当观察者对 BehaviorSubject 进行订阅时，它会将源 Observable 中最新的元素发送出来（如果不存在最新的元素，就发出默认元素）。然后将随后产生的元素发送出来。
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
    
    let lock = RecursiveLock()
    
    // state
    private var disposed = false
    // 在这个类初始化的时候, 必须要提供默认值.
    private var element: Element
    private var observers = Observers()
    private var stoppedEvent: Event<Element>?

    #if DEBUG
        private let synchronizationTracker = SynchronizationTracker()
    #endif

    /// Indicates whether the subject has been disposed.
    public var isDisposed: Bool {
        self.disposed
    }
 
    /// Initializes a new instance of the subject that caches its last value and starts with the specified value.
    ///
    /// - parameter value: Initial value sent to observers when no other value has been received by the subject yet.
    public init(value: Element) {
        self.element = value

        #if TRACE_RESOURCES
            _ = Resources.incrementTotal()
        #endif
    }
    
    /// Gets the current value or throws an error.
    ///
    /// - returns: Latest value.
    // 把 thros 函数, 当做返回一个 Enum 来看来
    // Enum.Success(Element)
    // Enum.Fail(Error)
    public func value() throws -> Element {
        self.lock.lock(); defer { self.lock.unlock() }
        
        if self.isDisposed {
            throw RxError.disposed(object: self)
        }
        
        if let error = self.stoppedEvent?.error {
            // intentionally throw exception
            throw error
        }
        else {
            return self.element
        }
    }
    
    /// Notifies all subscribed observers about next event.
    ///
    /// - parameter event: Event to send to the observers.
    public func on(_ event: Event<Element>) {
        #if DEBUG
            self.synchronizationTracker.register(synchronizationErrorMessage: .default)
            defer { self.synchronizationTracker.unregister() }
        #endif
        dispatch(self.synchronized_on(event), event)
    }

    func synchronized_on(_ event: Event<Element>) -> Observers {
        self.lock.lock(); defer { self.lock.unlock() }
        
        if self.stoppedEvent != nil || self.isDisposed {
            return Observers()
        }
        
        // 在接受到信号的时候, 改变了自身的状态.
        // 自身状态的概念, 使得下一次接收到信号, 接收到订阅的时候, 行为发生了变化.
        switch event {
        case .next(let element):
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
        // 在这里, 注册的时候, 主动调用类了一下 observer 的 on 方法, 把当前存储的 value 值发射出去.
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

/*
 
 let disposeBag = DisposeBag()
 let subject = BehaviorSubject(value: "🔴")

 subject
   .subscribe { print("Subscription: 1 Event:", $0) }
   .disposed(by: disposeBag)

 subject.onNext("🐶")
 subject.onNext("🐱")

 subject
   .subscribe { print("Subscription: 2 Event:", $0) }
   .disposed(by: disposeBag)

 subject.onNext("🅰️")
 subject.onNext("🅱️")

 subject
   .subscribe { print("Subscription: 3 Event:", $0) }
   .disposed(by: disposeBag)

 subject.onNext("🍐")
 subject.onNext("🍊")
 输出结果：

 Subscription: 1 Event: next(🔴)
 Subscription: 1 Event: next(🐶)
 Subscription: 1 Event: next(🐱)
 Subscription: 2 Event: next(🐱)
 Subscription: 1 Event: next(🅰️)
 Subscription: 2 Event: next(🅰️)
 Subscription: 1 Event: next(🅱️)
 Subscription: 2 Event: next(🅱️)
 Subscription: 3 Event: next(🅱️)
 Subscription: 1 Event: next(🍐)
 Subscription: 2 Event: next(🍐)
 Subscription: 3 Event: next(🍐)
 Subscription: 1 Event: next(🍊)
 Subscription: 2 Event: next(🍊)
 Subscription: 3 Event: next(🍊)
 
 
 */
