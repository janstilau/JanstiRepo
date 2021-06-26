//
//  Create.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    // MARK: create

    /*
     Creates an observable sequence from a specified subscribe method implementation.
     - seealso: [create operator on reactivex.io](http://reactivex.io/documentation/operators/create.html)
     - parameter subscribe: Implementation of the resulting observable sequence's `subscribe` method.
     - returns: The observable sequence with the specified implementation for the `subscribe` method.
     */
    
    /*
        Observable 是一个概念, 就是 Publisher, 以时间为轴的一个事件序列.
        但是这仅仅只是一个概念, 到了真正的物理编码上, 如何时间他提取的概念来呢.
     
        从现在来看, Create 函数中, 传入了一个返回 Disposable 的闭包.
        这个闭包, 仅仅是被存储起来了.
        当真正进行 Subscribe 的时候, 这个闭包, 才会真正被调用. 而这个真正被调用, 才会去创建事件队列.
        
        对于 ControlProperty 来说, 它的 Create 里面存储的是, 建立一个 ControlTarget 对象, 每当 UIControl 的事件触发一次的时候, 都会发射一个信号出去. 所有的 Subsciber 监听这个信号就好了.
        而作为 Just, Empty 来说, 他们根本就不是 AnonymousObservable 的类型.
        而我们自己编写, 可以在 create 里面调用 subscribe.on 方法. 因为这个闭包, 只会在 AnonymousObservable 的 subscribe 的时候才会被调用.
     */

    public static func create(_ subscribe: @escaping (AnyObserver<Element>) -> Disposable) -> Observable<Element> {
        // AnonymousObservable 是一个 Producer.
        AnonymousObservable(subscribe)
    }
}

final private class AnonymousObservableSink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Element = Observer.Element 
    typealias Parent = AnonymousObservable<Element>

    // state
    private let isStopped = AtomicInt(0)

    #if DEBUG
        private let synchronizationTracker = SynchronizationTracker()
    #endif

    override init(observer: Observer, cancel: Cancelable) {
        super.init(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<Element>) {
        switch event {
        case .next:
            if load(self.isStopped) == 1 {
                return
            }
            self.forwardOn(event)
        case .error, .completed:
            if fetchOr(self.isStopped, 1) == 0 {
                self.forwardOn(event)
                self.dispose()
            }
        }
    }

    func run(_ parent: Parent) -> Disposable {
        parent.subscribeHandler(AnyObserver(self))
    }
}

/*
    封装的主要的设计意图, 就是将相关的逻辑封在对象的内部, 然后使用这个对象的时候, 就可以重复利用这些封装好的代码了.
    为了可以使用这些封装好的逻辑, 需要填入相对应的数据, 各种 set 方法, init 方法传入的数据, 都是为了这个目的.
    但是本质上, 我们想要的其实是类对外提供的一个接口而已. 数据的传入, private 方法的封装, 都是实现这个接口要求的功能.
 
    如果有一个闭包将这些逻辑全部封装到一起, 那么传入这个闭包, 然后在接口里面直接调用一下这个闭包就好了.
    各种 Any 类, 主要就是这个逻辑.
    闭包本身的数据捕获的功能, 使得传入闭包的这种方式, 不太需要 set, init 来进行数据传入.
    闭包里面的代码可以自组织, 所以也可以做好函数的分割之后, 直接在闭包里面, 调用这些函数.
 
    AnonymousObservable, 是 Producer 的子类. 所以闭包的调用, 放到了 Producer 的 Item 方法里面了.
 */
final private class AnonymousObservable<Element>: Producer<Element> {
    
    typealias SubscribeHandler = (AnyObserver<Element>) -> Disposable

    let subscribeHandler: SubscribeHandler

    init(_ subscribeHandler: @escaping SubscribeHandler) {
        self.subscribeHandler = subscribeHandler
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = AnonymousObservableSink(observer: observer, cancel: cancel)
        let subscription = sink.run(self)
        return (sink: sink, subscription: subscription)
    }
}
