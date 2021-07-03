//
//  AsyncSubject.swift
//  RxSwift
//
//  Created by Victor Galán on 07/01/2017.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

/// An AsyncSubject emits the last value (and only the last value) emitted by the source Observable,
/// and only after that source Observable completes.
///
/// (If the source Observable does not emit any values, the AsyncSubject also completes without emitting any values.)
public final class AsyncSubject<Element>
    : Observable<Element>
    , SubjectType
    , ObserverType
    , SynchronizedUnsubscribeType {
    public typealias SubjectObserverType = AsyncSubject<Element>

    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType

    /// Indicates whether the subject has any observers
    public var hasObservers: Bool {
        self.lock.performLocked {
            self.observers.count > 0
        }
    }

    let lock = RecursiveLock()

    // state
    private var observers = Observers()
    private var isStopped = false
    private var stoppedEvent = nil as Event<Element>? {
        didSet {
            self.isStopped = self.stoppedEvent != nil
        }
    }
    
    // 真正的存储数据的地方, 一个 Optinal, 因为可能没有 Next 信号, 直接 Complete 了.
    private var lastElement: Element?


    /// Creates a subject.
    public override init() {
        super.init()
    }

    /// Notifies all subscribed observers about next event.
    ///
    /// - parameter event: Event to send to the observers.
    public func on(_ event: Event<Element>) {
        // On 方法, 会在 synchronized_on 进行 事件和 Observers 的筛选, 然后根据筛选结果, 进行 dispatch.
        let (observers, event) = self.synchronized_on(event)
        switch event {
        case .next:
            dispatch(observers, event)
            dispatch(observers, .completed)
        case .completed:
            dispatch(observers, event)
        case .error:
            dispatch(observers, event)
        }
    }

    func synchronized_on(_ event: Event<Element>) -> (Observers, Event<Element>) {
        self.lock.lock(); defer { self.lock.unlock() }
        
        if self.isStopped {
            return (Observers(), .completed)
        }

        switch event {
        case .next(let element):
            // 如果, 是 Next, 那么将 Next 的值存储起来, 然后返回空的 Observer.
            self.lastElement = element
            return (Observers(), .completed)
            
            
        case .error:
            // 如果 Error, 那么清空 Observers, 也不会向 Observer 发射信号.
            self.stoppedEvent = event
            let observers = self.observers
            self.observers.removeAll()
            return (observers, event)
            
            
        case .completed:

            // 如果是 Complete.
            let observers = self.observers
            self.observers.removeAll()
            // 如果, 原来存储了 element, 才会真正在 On 里面处理 Next 事件.
            if let lastElement = self.lastElement {
                self.stoppedEvent = .next(lastElement)
                return (observers, .next(lastElement))
            } else {
                self.stoppedEvent = event
                return (observers, .completed)
            }
        }
    }
    
    /*
        后面的逻辑, 四种 Subject 都有.
     */

    /// Subscribes an observer to the subject.
    ///
    /// - parameter observer: Observer to subscribe to the subject.
    /// - returns: Disposable object that can be used to unsubscribe the observer from the subject.
    public override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.lock.performLocked { self.synchronized_subscribe(observer) }
    }

    // 
    func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        if let stoppedEvent = self.stoppedEvent {
            // Swich 可以直接进行 case 的比对, 而不管里面的关联值.
            switch stoppedEvent {
            case .next:
                observer.on(stoppedEvent)
                observer.on(.completed)
            case .completed:
                observer.on(.completed)
            case .error:
                observer.on(stoppedEvent)
            }
            return Disposables.create()
        }

        let key = self.observers.insert(observer.on)

        return SubscriptionDisposable(owner: self, key: key)
    }

    func synchronizedUnsubscribe(_ disposeKey: DisposeKey) {
        self.lock.performLocked { self.synchronized_unsubscribe(disposeKey) }
    }
    
    func synchronized_unsubscribe(_ disposeKey: DisposeKey) {
        _ = self.observers.removeKey(disposeKey)
    }
    
    /// Returns observer interface for subject.
    public func asObserver() -> AsyncSubject<Element> {
        self
    }
}

