//
//  AsyncSubject.swift
//  RxSwift
//
//  Created by Victor Galán on 07/01/2017.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//
/*
 AsyncSubject 将在源 Observable 产生完成事件后，发出最后一个元素（仅仅只有最后一个元素），如果源 Observable 没有发出任何元素，只有一个完成事件。那 AsyncSubject 也只有一个完成事件。
 它会对随后的观察者发出最终元素。如果源 Observable 因为产生了一个 error 事件而中止， AsyncSubject 就不会发出任何元素，而是将这个 error 事件发送出来。
 那么在业务实现上, 就是存储上一个值, 直到最后接收到 Complete 的时候, 才发出存储的值, 然后将自己设置为 Complete.
 */
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
    // 在这里, 专门有一个自己的 Observers 的存储器.
    private var observers = Observers()
    private var isStopped = false
    // StoppedEvent, 作为结束的标志.
    private var stoppedEvent = nil as Event<Element>? {
        didSet {
            self.isStopped = self.stoppedEvent != nil
        }
    }
    // 业务类的核心数据存储, 就是不断更新的上一次信号发过来的值.
    private var lastElement: Element?

    #if DEBUG
        private let synchronizationTracker = SynchronizationTracker()
    #endif


    /// Creates a subject.
    public override init() {
        #if TRACE_RESOURCES
        // 主动的声明不关心返回值. 不然会有警告.
            _ = Resources.incrementTotal()
        #endif
        super.init()
    }

    /// Notifies all subscribed observers about next event.
    ///
    /// - parameter event: Event to send to the observers.
    public func on(_ event: Event<Element>) {
        // 根据 synchronized_on 的返回值, 主要是 event 的 case, 进行后面的逻辑处理.
        let (observers, event) = self.synchronized_on(event)
        switch event {
        case .next:
            // 如果是 next, 证明 synchronized_on 里面处理的是 complete 事件. 那么就发射 element, 然后发射 complete
            // 主动地调用 complete.
            dispatch(observers, event)
            dispatch(observers, .completed)
        case .completed:
            // 如果是 complete, 那么就是直接 complete 了, 没有 element 存储
            dispatch(observers, event)
            // 如果是 error, 也不会发射 element 事件.
        case .error:
            dispatch(observers, event)
        }
    }

    func synchronized_on(_ event: Event<Element>) -> (Observers, Event<Element>) {
        self.lock.lock(); defer { self.lock.unlock() }
        
        // 如果, 当前已经处于完成状态了, 就返回一个空的 Observers.
        // 这种返回空的集合的方法, 让后面的逻辑统一. 不过, 不是太 clean code.
        if self.isStopped {
            return (Observers(), .completed)
        }

        switch event {
        case .next(let element):
            // 如果是 next 这种 case, 返回一个空的 Observers.
            // 更新 LastElements 里面的值.
            self.lastElement = element
            return (Observers(), .completed)
        case .error:
            // 记录 stoppedEvent, 修改 isStopped 状态.
            self.stoppedEvent = event

            // 释放资源.
            // 当收到 complete, error 事件的时候, 释放资源
            // 这个事情, 是 Observer 的编写者需要注意的事情.
            let observers = self.observers
            self.observers.removeAll()

            // 如果源 Observable 因为产生了一个 error 事件而中止， AsyncSubject 就不会发出任何元素，而是将这个 error 事件发送出来。
            return (observers, event)
        case .completed:

            let observers = self.observers
            self.observers.removeAll()

            // 如果, 之前存储了值了, 那么把这些值, 都分发给存储的 observer, 否则, 否则就是直接的 complete.
            if let lastElement = self.lastElement {
                self.stoppedEvent = .next(lastElement)
                return (observers, .next(lastElement))
            }
            else {
                self.stoppedEvent = event
                return (observers, .completed)
            }
        }
    }

    /// Subscribes an observer to the subject.
    ///
    /// - parameter observer: Observer to subscribe to the subject.
    /// - returns: Disposable object that can be used to unsubscribe the observer from the subject.
    public override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.lock.performLocked { self.synchronized_subscribe(observer) }
    }

    func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        // 如果当前已经结束了, 那么根据存储的 self.stoppedEvent, 完成 Publisher 的逻辑.
        if let stoppedEvent = self.stoppedEvent {
            switch stoppedEvent {
            case .next:
                observer.on(stoppedEvent)
                observer.on(.completed)
            case .completed:
                observer.on(stoppedEvent)
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

    #if TRACE_RESOURCES
    deinit {
        _ = Resources.decrementTotal()
    }
    #endif
}

/*
 let disposeBag = DisposeBag()
 let subject = AsyncSubject<String>()

 subject
   .subscribe { print("Subscription: 1 Event:", $0) }
   .disposed(by: disposeBag)

 subject.onNext("🐶")
 subject.onNext("🐱")
 subject.onNext("🐹")
 subject.onCompleted()
 
 所以实际上, 这个类就是
 1. 存储 observer, 并且提供 dispose observer 的接口. 这是每一个 Publisher 都应该做的事情.
 2. 完成自己的业务逻辑的编写,  这里就是存储一下接受到的 element, 然后在 complete 的时候发射.
    Error 的时候, 也会有相关逻辑的考虑.
 */
