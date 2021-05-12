//
//  PublishSubject.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/11/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//


/*
 第一个分析的 rx 实现类.
 可以看到.
 作为一个 observer, PublishSubject 有着 send 的能力.
 作为可以从命令式, 到响应式的入口, Subject 的 publish 能力, 是建立在它是一个 Observer 的基础上. 因为它是一个 Observer, 所以可以调用 on 进行信号的主动传输.
 信号到达了 Subject, 之后的流程, 就是 Subject 内部控制了.
 
 在 Subject 的内部, 存储了各个 Observer. 无论是存储接口对象也好, 还是存储闭包也好, 都是主动的进行了存储.
 每次存储的时候, 都会返回一个 Disposeable 对象. 这个对象, 在不同的场合有着不同的含义. 但是有着统一的行为意义, 取消订阅, 释放资源.
 
 在 Subject 的内部, 存储着各个状态, 这些状态, 控制着 注册 Observer 的时候, 接收到信号的时候, Subject 的行为.
 */

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
    
    private let lock = RecursiveLock()
    
    // state
    // 数据, 私有的, 外界无法进行访问.
        
    /*
     是否已经取消, 和是否已经结束, 是两个概念.
     取消, 是外界调用了 disposed 方法.
     stop 是接收到了上游的 complete 事件.
     */
    private var disposed = false
    private var stopped = false
    private var stoppedEvent = nil as Event<Element>?
    private var observers = Observers()

    #if DEBUG
        private let synchronizationTracker = SynchronizationTracker()
    #endif

    /// Indicates whether the subject has been isDisposed.
    // 对外的接口, Cancelable 的实现.
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
    /*
     PublishObject 的 on 事件, 是 obverver 的功能.
     使用 on, 其实就是传递接收的 event, 到它的 observers
     */
    public func on(_ event: Event<Element>) {
        #if DEBUG
            self.synchronizationTracker.register(synchronizationErrorMessage: .default)
            defer { self.synchronizationTracker.unregister() }
        #endif
        dispatch(self.synchronized_on(event), event)
    }

    // 获取到当前 subject 的 Observers.
    func synchronized_on(_ event: Event<Element>) -> Observers {
        self.lock.lock(); defer { self.lock.unlock() }
        
        switch event {
        case .next:
            // 如果, 当前的 subject 不应该发出事件了, 那么返回一个空的 observers.
            if self.isDisposed || self.stopped {
                return Observers()
            }
            // 如果, 当前 subject 可以传递事件, 那么返回自己的 obversers.
            return self.observers
        case .completed, .error:
            // 如果, 当前 stop Event 没有被记录过, 那么主动记录下是当前的 event 事件.
            // 然后返回自己存储的 observers 的拷贝, 清空自己的存储.
            if self.stoppedEvent == nil {
                self.stoppedEvent = event
                self.stopped = true
                let observers = self.observers
                self.observers.removeAll()
                return observers
            }
            // 表示已经 stop 过了, 返回一个空的 observers.
            return Observers()
        }
    }
    
    /**
    Subscribes an observer to the subject.
     
    - parameter observer: Observer to subscribe to the subject.
    - returns: Disposable object that can be used to unsubscribe the observer from the subject.
    */
    // 给外界, 暴露 protocol 里面的接口,  良好.
    // 在内部, 使用更加命名清晰的函数名, synchronized_subscribe 表明了方法会在线程安全的环境中进行.
    public override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.lock.performLocked { self.synchronized_subscribe(observer) }
    }

    func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        
        // 如果, self subject 已经结束了, 那么直接通知 observer 结束事件.
        // 根本不添加 observer 到自己的存储中.
        if let stoppedEvent = self.stoppedEvent {
            observer.on(stoppedEvent)
            // 返回一个没有任何意义的 dispose 对象.
            // 接受者拿到这个对象, 调用 dispose, 不会有任何影响.
            // 什么时候返回一个 Disposables.create, 是 subscribe 的实现者应该考虑的事情.
            return Disposables.create()
        }

        // 如果, self subject 已经取消了, 那么直接通知 observer 错误事件.
        // 同样的, 不添加存储, 返回一个无效的 disposed 对象.
        if self.isDisposed {
            observer.on(.error(RxError.disposed(object: self)))
            return Disposables.create()
        }
        
        // 将, observer.on 存储起来, on 里面自动保存了 observer 的生命周期.
        // 如果是原始的面向对象的设计思路, 这里铁定的是存储 observer, 但是这里, 存储的是一个闭包.
        let key = self.observers.insert(observer.on)
        return SubscriptionDisposable(owner: self, key: key)
    }

    func synchronizedUnsubscribe(_ disposeKey: DisposeKey) {
        self.lock.performLocked { self.synchronized_unsubscribe(disposeKey) }
    }

    func synchronized_unsubscribe(_ disposeKey: DisposeKey) {
        // 不适用 swift 里面函数的返回值, 要显式地标明出来 _
        _ = self.observers.removeKey(disposeKey)
    }
    
    /// Returns observer interface for subject.
    public func asObserver() -> PublishSubject<Element> {
        self
    }
    
    /// Unsubscribe all observers and release resources.
    // Subject, 也可以是一个 disposable 对象.
    // 调用的结果就是, 注册的观察者全部释放了. 改变自身的状态.
    public func dispose() {
        self.lock.performLocked { self.synchronized_dispose() }
    }

    final func synchronized_dispose() {
        self.disposed = true
        self.observers.removeAll()
        self.stoppedEvent = nil
    }

    #if TRACE_RESOURCES
        deinit {
            _ = Resources.decrementTotal()
        }
    #endif
}


/*
 
 从使用的实例中可以看出, PublishSubject 这个主要就是当做 命令式环境里面, 创建一个 publisher 的入口了.
 但是实际上, 它是一个 Observer, 它实现了 Observer 接口. 所以, 它也可以注册给一个 publisher.
 
 Subject 它们既是可监听序列也是观察者。关键就在于, 它是一个 观察者, 然后暴露了接口可以主动的调用观察者的 on 方法, 手动的添加信号进去, 又变为了 Publisher.
 
 let disposeBag = DisposeBag()
 let subject = PublishSubject<String>()

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
 */
