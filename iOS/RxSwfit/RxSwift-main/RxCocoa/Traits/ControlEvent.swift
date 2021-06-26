//
//  ControlEvent.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 8/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import RxSwift

/*
    这种 SomeClassType 的协议, 提供的唯一的功能, 就是提供一个方法, 这个方法名为 asSomeClass
    而 SomeClass 应该是一个固定的类型, 在这个类型的内部, 提供了相应的方法实现.
    而实现了 SomeClassType 协议的类型, 主要的功能就是提供一个 asSomeClass 方法的实现, 将自身转变为对应的类型.
    
    如果没有这个协议, 那么每个需要使用 SomeClass 的时候, 都是需要在特定的类型, 提供一个方法, 生成一个 SomeClass 对象, 然后传入到使用 SomeClass 的地方.
    有了这个协议, 可以直接将原始的对象传递过去. 因为在方法内部, 一定会是先使用 asSomeClass 进行数据的提取, 然后根据这个提取之后的数据, 进行编码.
 */

/// A protocol that extends `ControlEvent`.
public protocol ControlEventType : ObservableType {

    /// - returns: `ControlEvent` interface
    func asControlEvent() -> ControlEvent<Element>
}

/*
    A trait for `Observable`/`ObservableType` that represents an event on a UI element.

    Properties:

    - it doesn’t send any initial value on subscription,
    - it `Complete`s the sequence when the control deallocates,
    - it never errors out
    - it delivers events on `MainScheduler.instance`.
 
    1. 不会发射初始信号.
    1. 消亡的时候, 发射 Complete 信号.
    1. 不会发生错误. 因为 Event 是 UI 交互产生的结果, 本身是不带数据的.
    1. 主线程发射信号.

    **The implementation of `ControlEvent` will ensure that sequence of events is being subscribed on main scheduler
     (`subscribe(on: ConcurrentMainScheduler.instance)` behavior).**

    **It is the implementor’s responsibility to make sure that all other properties enumerated above are satisfied.**

    **If they aren’t, using this trait will communicate wrong properties, and could potentially break someone’s code.**

    **If the `events` observable sequence passed into the initializer doesn’t satisfy all enumerated
     properties, don’t use this trait.**
*/
//



public struct ControlEvent<PropertyType> : ControlEventType {
    public typealias Element = PropertyType

    let events: Observable<PropertyType> // 

    /// Initializes control event with a observable sequence that represents events.
    ///
    /// - parameter events: Observable sequence that represents events.
    /// - returns: Control event created with a observable sequence of events.
    // 在这里, 当 UI 事件生成的时候, 将 events 进行了一次包装, 确保了事件产生是在主线程进行的.
    public init<Ev: ObservableType>(events: Ev) where Ev.Element == Element {
        self.events = events.subscribe(on: ConcurrentMainScheduler.instance)
    }

    /// Subscribes an observer to control events.
    ///
    /// - parameter observer: Observer to subscribe to events.
    /// - returns: Disposable object that can be used to unsubscribe the observer from receiving control events.
    //
    // 然后对于 Publisher 的实现, 就是简单地转交给了 events.
    public func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.events.subscribe(observer)
    }

    /// - returns: `Observable` interface.
    public func asObservable() -> Observable<Element> {
        self.events
    }

    /// - returns: `ControlEvent` interface.
    public func asControlEvent() -> ControlEvent<Element> {
        self
    }
}
