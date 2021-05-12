//
//  ReplaySubject.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 4/14/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents an object that is both an observable sequence as well as an observer.
///
/// Each notification is broadcasted to all subscribed and future observers, subject to buffer trimming policies.
// 这是一个类簇模式的类.
// ReplaySubject 里面, 定义公共的数据和Template方法的实现.
// 在子类里面, 完成 Primitive Method 的定义.
public class ReplaySubject<Element>
    : Observable<Element>
    , SubjectType
    , ObserverType
    , Disposable {
    public typealias SubjectObserverType = ReplaySubject<Element>

    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType

    /// Indicates whether the subject has any observers
    public var hasObservers: Bool {
        self.lock.performLocked { self.observers.count > 0 }
    }
    
    fileprivate let lock = RecursiveLock()
    
    // state
    fileprivate var isDisposed = false
    fileprivate var stopped = false
    fileprivate var stoppedEvent = nil as Event<Element>? {
        didSet {
            self.stopped = self.stoppedEvent != nil
        }
    }
    fileprivate var observers = Observers()

    #if DEBUG
        fileprivate let synchronizationTracker = SynchronizationTracker()
    #endif

    func unsubscribe(_ key: DisposeKey) {
        rxAbstractMethod()
    }

    final var isStopped: Bool {
        self.stopped
    }
    
    /// Notifies all subscribed observers about next event.
    ///
    /// - parameter event: Event to send to the observers.
    public func on(_ event: Event<Element>) {
        rxAbstractMethod()
    }
    
    /// Returns observer interface for subject.
    public func asObserver() -> ReplaySubject<Element> {
        self
    }
    
    /// Unsubscribe all observers and release resources.
    public func dispose() {
    }

    /// Creates new instance of `ReplaySubject` that replays at most `bufferSize` last elements of sequence.
    ///
    /// - parameter bufferSize: Maximal number of elements to replay to observer after subscription.
    /// - returns: New instance of replay subject.
    // 工厂方法的实现. 在里面, 完成了不同的子类对象的创建.
    // Swift 里面, 也可以完成类簇模式的设计. 不过, 需要有一个明确的工厂方法. 来掌管所有的对象的创建.
    public static func create(bufferSize: Int) -> ReplaySubject<Element> {
        if bufferSize == 1 {
            return ReplayOne()
        }
        else {
            return ReplayMany(bufferSize: bufferSize)
        }
    }

    /// Creates a new instance of `ReplaySubject` that buffers all the elements of a sequence.
    /// To avoid filling up memory, developer needs to make sure that the use case will only ever store a 'reasonable'
    /// number of elements.
    // 特殊的方法, 返回一个没有限制的 Publisher.
    public static func createUnbounded() -> ReplaySubject<Element> {
        ReplayAll()
    }

    #if TRACE_RESOURCES
        override init() {
            _ = Resources.incrementTotal()
        }

        deinit {
            _ = Resources.decrementTotal()
        }
    #endif
}

private class ReplayBufferBase<Element>
    : ReplaySubject<Element>
    , SynchronizedUnsubscribeType {
    
    func trim() {
        rxAbstractMethod()
    }
    
    func addValueToBuffer(_ value: Element) {
        rxAbstractMethod()
    }
    
    func replayBuffer<Observer: ObserverType>(_ observer: Observer) where Observer.Element == Element {
        rxAbstractMethod()
    }
    
    override func on(_ event: Event<Element>) {
        #if DEBUG
            self.synchronizationTracker.register(synchronizationErrorMessage: .default)
            defer { self.synchronizationTracker.unregister() }
        #endif
        dispatch(self.synchronized_on(event), event)
    }

    func synchronized_on(_ event: Event<Element>) -> Observers {
        self.lock.lock(); defer { self.lock.unlock() }
        if self.isDisposed {
            return Observers()
        }
        
        if self.isStopped {
            return Observers()
        }
        
        switch event {
        case .next(let element):
            // 在缓存了之后, 里面进行 trim.
            // 逻辑比较统一, 而是否需要 trim, 其实是各个子类都有自己的实现的.
            // 一个简单的算法.
            self.addValueToBuffer(element)
            self.trim()
            return self.observers
        case .error, .completed:
            self.stoppedEvent = event
            self.trim()
            let observers = self.observers
            self.observers.removeAll()
            return observers
        }
    }
    
    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.lock.performLocked { self.synchronized_subscribe(observer) }
    }

    func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        if self.isDisposed {
            observer.on(.error(RxError.disposed(object: self)))
            return Disposables.create()
        }
     
        let anyObserver = observer.asObserver()
        
        // replayBuffer 就是将缓存的数据, 在注册的时候, 交给 Observer 进行响应.
        self.replayBuffer(anyObserver)
        if let stoppedEvent = self.stoppedEvent {
            observer.on(stoppedEvent)
            return Disposables.create()
        }
        else {
            let key = self.observers.insert(observer.on)
            return SubscriptionDisposable(owner: self, key: key)
        }
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
    
    override func dispose() {
        super.dispose()

        self.synchronizedDispose()
    }

    func synchronizedDispose() {
        self.lock.performLocked { self.synchronized_dispose() }
    }

    func synchronized_dispose() {
        self.isDisposed = true
        self.observers.removeAll()
    }
}

private final class ReplayOne<Element> : ReplayBufferBase<Element> {
    // 仅仅存储一个 value.
    private var value: Element?
    
    override init() {
        super.init()
    }
    
    override func trim() {
        
    }
    
    // Primitive Method 缓存, 对于 One 这种子类, 就是替换
    override func addValueToBuffer(_ value: Element) {
        self.value = value
    }

    // Primitive Method 响应缓存, 就是如果有 value, 发送到响应者那里.
    override func replayBuffer<Observer: ObserverType>(_ observer: Observer) where Observer.Element == Element {
        if let value = self.value {
            observer.on(.next(value))
        }
    }

    override func synchronized_dispose() {
        super.synchronized_dispose()
        self.value = nil
    }
}

private class ReplayManyBase<Element>: ReplayBufferBase<Element> {
    // 存储一个队列.
    fileprivate var queue: Queue<Element>
    
    init(queueSize: Int) {
        self.queue = Queue(capacity: queueSize + 1)
    }
    
    override func addValueToBuffer(_ value: Element) {
        self.queue.enqueue(value)
    }

    override func replayBuffer<Observer: ObserverType>(_ observer: Observer) where Observer.Element == Element {
        for item in self.queue {
            observer.on(.next(item))
        }
    }

    override func synchronized_dispose() {
        super.synchronized_dispose()
        self.queue = Queue(capacity: 0)
    }
}

private final class ReplayMany<Element> : ReplayManyBase<Element> {
    private let bufferSize: Int
    
    init(bufferSize: Int) {
        self.bufferSize = bufferSize
        
        super.init(queueSize: bufferSize)
    }
    
    override func trim() {
        while self.queue.count > self.bufferSize {
            _ = self.queue.dequeue()
        }
    }
}

private final class ReplayAll<Element> : ReplayManyBase<Element> {
    init() {
        super.init(queueSize: 0)
    }
    
    override func trim() {
        
    }
}
