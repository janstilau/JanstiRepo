//
//  ObservableType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a push style sequence.
public protocol ObservableType: ObservableConvertibleType {
    /**
    Subscribes `observer` to receive events for this sequence.
    
    ### Grammar
    
    **Next\* (Error | Completed)?**
    
    * sequences can produce zero or more elements so zero or more `Next` events can be sent to `observer`
    * once an `Error` or `Completed` event is sent, the sequence terminates and can't produce any other elements
    
    It is possible that events are sent from different threads, but no two events can be sent concurrently to
    `observer`.
    
    ### Resource Management
    
    When sequence sends `Complete` or `Error` event all internal resources that compute sequence elements
    will be freed.
    
    To cancel production of sequence elements and free resources immediately, call `dispose` on returned
    subscription.
    
    - returns: Subscription for `observer` that can be used to cancel production of sequence elements and free resources.
    */
    
    /*
        返回值, Disposable 可以认为是注册这个行为的句柄. 它的 dispose 方法, 是取消注册这件事.
        
        从实现的角度来说, 管道的各个节点, 是在 subscibe 中连接起来的.
        如果是 Empty, Just 这种 Producer, 直接在 subscribe 的实现里面, 调用了对应的 Observer 的 on 方法就结束了.
        如果是 Sink 这种 Producer, 则是创建中转水槽, 由水槽接管 source 的信号, 经过处理之后, 交给后方.
     
        总之, subscribe 的不同实现, 使得异步序列这件事, 有着不同的实现.
     */
    func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element
}

extension ObservableType {
    
    /// Default implementation of converting `ObservableType` to `Observable`.
    public func asObservable() -> Observable<Element> {
        // temporary workaround
        //return Observable.create(subscribe: self.subscribe)
        Observable.create { o in self.subscribe(o) }
    }
}
