//
//  PublishSubject.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/11/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents an object that is both an observable sequence as well as an observer.
///
/// Each notification is broadcasted to all subscribed observers.
public final class PublishSubject<Element>
    : Observable<Element>
    , SubjectType
    , Cancelable
    , ObserverType
    , SynchronizedUnsubscribeType {
    
    public typealias SubjectObserverType = PublishSubject<Element>

    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType
    
    /// Indicates whether the subject has any observers
    public var hasObservers: Bool {
        self.lock.performLocked { self.observers.count > 0 }
    }
    
    // 所有的, 对于数据的操作, 都进行了加锁的处理.
    private let lock = RecursiveLock()
    
    // state
    private var disposed = false
    private var observers = Observers()
    private var stopped = false
    private var stoppedEvent = nil as Event<Element>?
    
    /*
        PublishObject 里面有两个数据.
        Observers, 所有的 subscriber. 这个会在接收到 Complete, Error 之后, 进行清空.
        StopEvent, 这个会在 Complete, Error 之后记录, 然后后续的 Subscriber 注册的时候, 会继续发送 StopEvent.
     
     Disposed 和 Stopped 是两码事.
     */

    #if DEBUG
        private let synchronizationTracker = SynchronizationTracker()
    #endif

    /// Indicates whether the subject has been isDisposed.
    public var isDisposed: Bool {
        self.disposed
    }
    
    /// Creates a subject.
    public override init() {
        super.init()
        #if TRACE_RESOURCES
            _ = Resources.incrementTotal()
        #endif
    }
    
    /// Notifies all subscribed observers about next event.
    ///
    /// - parameter event: Event to send to the observers.
    public func on(_ event: Event<Element>) {
        dispatch(self.synchronized_on(event), event)
    }

    // 这个框架里面, 把所有的加锁的操作, 都用 synchronized 前缀进行了修饰.
    func synchronized_on(_ event: Event<Element>) -> Observers {
        self.lock.lock(); defer { self.lock.unlock() }
        
        switch event {
        case .next:
            // 如果, 已经不应该处理事件了, 返回一个空的队列.
            if self.isDisposed || self.stopped {
                return Observers()
            }
            // 否则, 返回已经记录的 Observers
            // 感觉这里还是应该放到 else 里面.
            return self.observers
            
        case .completed, .error:
            // 当收到 Complete, Error 的时候, 记录一下 StoppedEvent.
            if self.stoppedEvent == nil {
                self.stoppedEvent = event
                self.stopped = true
                let observers = self.observers
                self.observers.removeAll()
                return observers
            }

            return Observers()
        }
    }
    
    /**
    Subscribes an observer to the subject.
    
    - parameter observer: Observer to subscribe to the subject.
    - returns: Disposable object that can be used to unsubscribe the observer from the subject.
    */
    public override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.lock.performLocked { self.synchronized_subscribe(observer) }
    }

    func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        
        // 如果, 已经结束了, 将 StoppedEvent 发射到新的 Observer 里面,
        if let stoppedEvent = self.stoppedEvent {
            observer.on(stoppedEvent)
            return Disposables.create()
        }
        
        // 如果已经 Disposed 了, 那就是错误了.
        if self.isDisposed {
            observer.on(.error(RxError.disposed(object: self)))
            return Disposables.create()
        }
        
        // 将新的 Observer 插入到自己的存储中.
        let key = self.observers.insert(observer.on)
        return SubscriptionDisposable(owner: self, key: key)
    }

    // 从这里可以看出, 对于 Subject 来说, 它是真的将 Observer 存起来了.
    func synchronizedUnsubscribe(_ disposeKey: DisposeKey) {
        self.lock.performLocked { self.synchronized_unsubscribe(disposeKey) }
    }

    func synchronized_unsubscribe(_ disposeKey: DisposeKey) {
        _ = self.observers.removeKey(disposeKey)
    }
    
    /// Returns observer interface for subject.
    public func asObserver() -> PublishSubject<Element> {
        self
    }
    
    /// Unsubscribe all observers and release resources.
    public func dispose() {
        self.lock.performLocked { self.synchronized_dispose() }
    }

    final func synchronized_dispose() {
        self.disposed = true
        self.observers.removeAll()
        self.stoppedEvent = nil
    }
}
