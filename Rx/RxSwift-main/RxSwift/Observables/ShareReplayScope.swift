//
//  ShareReplayScope.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 5/28/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

/// Subject lifetime scope
public enum SubjectLifetimeScope {
    /**
     **Each connection will have it's own subject instance to store replay events.**
     **Connections will be isolated from each another.**

     Configures the underlying implementation to behave equivalent to.
     
     ```
     source.multicast(makeSubject: { MySubject() }).refCount()
     ```

     **This is the recommended default.**

     This has the following consequences:
     * `retry` or `concat` operators will function as expected because terminating the sequence will clear internal state.
     * Each connection to source observable sequence will use it's own subject.
     * When the number of subscribers drops from 1 to 0 and connection to source sequence is disposed, subject will be cleared.

     
     ```
     let xs = Observable.deferred { () -> Observable<TimeInterval> in
             print("Performing work ...")
             return Observable.just(Date().timeIntervalSince1970)
         }
         .share(replay: 1, scope: .whileConnected)

     _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })
     _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })
     _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })

     ```

     Notice how time interval is different and `Performing work ...` is printed each time)
     
     ```
     Performing work ...
     next 1495998900.82141
     completed

     Performing work ...
     next 1495998900.82359
     completed

     Performing work ...
     next 1495998900.82444
     completed


     ```
     
     */
    case whileConnected

    /**
     **One subject will store replay events for all connections to source.**
     **Connections won't be isolated from each another.**

     Configures the underlying implementation behave equivalent to.

     ```
     source.multicast(MySubject()).refCount()
     ```
     
     This has the following consequences:
     * Using `retry` or `concat` operators after this operator usually isn't advised.
     * Each connection to source observable sequence will share the same subject.
     * After number of subscribers drops from 1 to 0 and connection to source observable sequence is dispose, this operator will 
       continue holding a reference to the same subject.
       If at some later moment a new observer initiates a new connection to source it can potentially receive
       some of the stale events received during previous connection.
     * After source sequence terminates any new observer will always immediately receive replayed elements and terminal event.
       No new subscriptions to source observable sequence will be attempted.

     ```
     let xs = Observable.deferred { () -> Observable<TimeInterval> in
             print("Performing work ...")
             return Observable.just(Date().timeIntervalSince1970)
         }
         .share(replay: 1, scope: .forever)

     _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })
     _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })
     _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })
     ```
     
     Notice how time interval is the same, replayed, and `Performing work ...` is printed only once
     
     ```
     Performing work ...
     next 1495999013.76356
     completed

     next 1495999013.76356
     completed

     next 1495999013.76356
     completed
     ```
     
    */
    case forever
}

extension ObservableType {

    /**
     Returns an observable sequence that **shares a single subscription to the underlying sequence**, and immediately upon subscription replays  elements in buffer.
     
     This operator is equivalent to:
     * `.whileConnected`
     ```
     // Each connection will have it's own subject instance to store replay events.
     // Connections will be isolated from each another.
     source.multicast(makeSubject: { Replay.create(bufferSize: replay) }).refCount()
     ```
     * `.forever`
     ```
     // One subject will store replay events for all connections to source.
     // Connections won't be isolated from each another.
     source.multicast(Replay.create(bufferSize: replay)).refCount()
     ```
     
     It uses optimized versions of the operators for most common operations.

     - parameter replay: Maximum element count of the replay buffer.
     - parameter scope: Lifetime scope of sharing subject. For more information see `SubjectLifetimeScope` enum.

     - seealso: [shareReplay operator on reactivex.io](http://reactivex.io/documentation/operators/replay.html)

     - returns: An observable sequence that contains the elements of a sequence produced by multicasting the source sequence.
     */
    public func share(replay: Int = 0,
                      scope: SubjectLifetimeScope = .whileConnected)
        -> Observable<Element> {
        switch scope {
        case .forever:
            switch replay {
            case 0: return self.multicast(PublishSubject()).refCount()
            default: return self.multicast(ReplaySubject.create(bufferSize: replay)).refCount()
            }
        case .whileConnected:
            switch replay {
            case 0: return ShareWhileConnected(source: self.asObservable())
            case 1: return ShareReplay1WhileConnected(source: self.asObservable())
                
            default: return self.multicast(makeSubject: { ReplaySubject.create(bufferSize: replay) }).refCount()
            }
        }
    }
}

// 这个 Connection, 会在每次信号过来之后, 存储当前的 Element.
private final class ShareReplay1WhileConnectedConnection<Element>
    : ObserverType
    , SynchronizedUnsubscribeType {
    
    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType

    typealias Parent = ShareReplay1WhileConnected<Element>
    private let parent: Parent
    private let subscription = SingleAssignmentDisposable()

    private let lock: RecursiveLock
    private var disposed: Bool = false
    fileprivate var observers = Observers()
    private var element: Element?

    init(parent: Parent, lock: RecursiveLock) {
        self.parent = parent
        self.lock = lock

        #if TRACE_RESOURCES
            _ = Resources.incrementTotal()
        #endif
    }

    final func on(_ event: Event<Element>) {
        let observers = self.lock.performLocked { self.synchronized_on(event) }
        dispatch(observers, event)
    }

    final private func synchronized_on(_ event: Event<Element>) -> Observers {
        if self.disposed {
            return Observers()
        }

        switch event {
        case .next(let element):
            self.element = element
            return self.observers
        case .error, .completed:
            let observers = self.observers
            self.synchronized_dispose()
            return observers
        }
    }

    final func connect() {
        self.subscription.setDisposable(self.parent.source.subscribe(self))
    }

    final func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        
        self.lock.performLocked {
            // 当新的 Observer 到来的时候, 会将存储的 Element 发送给新到来的 Observer.
            if let element = self.element {
                observer.on(.next(element))
            }
            let disposeKey = self.observers.insert(observer.on)
            return SubscriptionDisposable(owner: self, key: disposeKey)
        }
    }

    final private func synchronized_dispose() {
        self.disposed = true
        if self.parent.connection === self {
            self.parent.connection = nil
        }
        self.observers = Observers()
    }

    final func synchronizedUnsubscribe(_ disposeKey: DisposeKey) {
        if self.lock.performLocked({ self.synchronized_unsubscribe(disposeKey) }) {
            self.subscription.dispose()
        }
    }

    @inline(__always)
    final private func synchronized_unsubscribe(_ disposeKey: DisposeKey) -> Bool {
        // if already unsubscribed, just return
        if self.observers.removeKey(disposeKey) == nil {
            return false
        }

        if self.observers.count == 0 {
            self.synchronized_dispose()
            return true
        }

        return false
    }
}

/*
    Share 的逻辑就是, 找一个 Connection 当做 Source 的 observer.
    每次注册, 都是将 Observer 存储在 Connection 内部维护
    然后每次信号给 Connection, Connection 都将维护的 Observer 取出来, 调用 on 方法.
 */
final private class ShareReplay1WhileConnected<Element>
    : Observable<Element> {

    fileprivate typealias Connection = ShareReplay1WhileConnectedConnection<Element>

    fileprivate let source: Observable<Element> // 信号的发射源.

    private let lock = RecursiveLock()

    fileprivate var connection: Connection?

    init(source: Observable<Element>) {
        self.source = source
    }

    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.lock.lock()
        let connection = self.synchronized_subscribe(observer)
        let count = connection.observers.count

        let disposable = connection.synchronized_subscribe(observer)
        self.lock.unlock()
        
        if count == 0 {
            connection.connect() // 将 Source 的下游, 注册给 Connection.
        }

        return disposable
    }

    @inline(__always)
    private func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Connection where Observer.Element == Element {
        let connection: Connection

        // 懒加载.
        if let existingConnection = self.connection {
            connection = existingConnection
        } else {
            connection = ShareReplay1WhileConnectedConnection<Element>(
                parent: self,
                lock: self.lock)
            self.connection = connection
        }

        return connection
    }
}

/*
    这个 Connection, 没有了存储上一个 Element 的能力了.
 */
private final class ShareWhileConnectedConnection<Element>
    : ObserverType
    , SynchronizedUnsubscribeType {
    
    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType

    typealias Parent = ShareWhileConnected<Element>
    private let parent: Parent
    private let subscription = SingleAssignmentDisposable()

    private let lock: RecursiveLock
    private var disposed: Bool = false
    /*
     在这里, 记录了所有的 Subscribe
     */
    fileprivate var observers = Observers()

    init(parent: Parent, lock: RecursiveLock) {
        self.parent = parent
        self.lock = lock
    }

    // 取得所有的注册 Observer, 向他们统一的发送消息.
    final func on(_ event: Event<Element>) {
        let observers = self.lock.performLocked { self.synchronized_on(event) }
        dispatch(observers, event)
    }

    final private func synchronized_on(_ event: Event<Element>) -> Observers {
        if self.disposed {
            return Observers()
        }

        switch event {
        case .next:
            return self.observers
        case .error, .completed:
            let observers = self.observers
            self.synchronized_dispose()
            return observers
        }
    }

    final func connect() {
        self.subscription.setDisposable(self.parent.source.subscribe(self))
    }

    // 向 Connection 里面, 添加 Observer, 就是将 Observer 添加到存储的数据结构里面.
    final func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.lock.performLocked {
            let disposeKey = self.observers.insert(observer.on)
            return SubscriptionDisposable(owner: self, key: disposeKey)
        }
    }

    final private func synchronized_dispose() {
        self.disposed = true
        if self.parent.connection === self {
            self.parent.connection = nil
        }
        self.observers = Observers()
    }

    final func synchronizedUnsubscribe(_ disposeKey: DisposeKey) {
        if self.lock.performLocked({ self.synchronized_unsubscribe(disposeKey) }) {
            self.subscription.dispose()
        }
    }

    @inline(__always)
    final private func synchronized_unsubscribe(_ disposeKey: DisposeKey) -> Bool {
        // if already unsubscribed, just return
        if self.observers.removeKey(disposeKey) == nil {
            return false
        }

        if self.observers.count == 0 {
            self.synchronized_dispose()
            return true
        }

        return false
    }

    #if TRACE_RESOURCES
    deinit {
        _ = Resources.decrementTotal()
    }
    #endif
}

final private class ShareWhileConnected<Element>
    : Observable<Element> {

    fileprivate typealias Connection = ShareWhileConnectedConnection<Element>

    fileprivate let source: Observable<Element>

    private let lock = RecursiveLock()

    fileprivate var connection: Connection?

    init(source: Observable<Element>) {
        self.source = source
    }

    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.lock.lock()
        let connection = self.synchronized_subscribe(observer)
        let count = connection.observers.count
        let disposable = connection.synchronized_subscribe(observer)
        self.lock.unlock()

        if count == 0 {
            connection.connect()
        }

        return disposable
    }

    @inline(__always)
    private func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Connection where Observer.Element == Element {
        let connection: Connection

        if let existingConnection = self.connection {
            connection = existingConnection
        } else {
            connection = ShareWhileConnectedConnection<Element>(
                parent: self,
                lock: self.lock)
            self.connection = connection
        }
        
        return connection
    }
}
