//
//  ControlProperty.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 8/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import RxSwift

public protocol ControlPropertyType : ObservableType, ObserverType {

    func asControlProperty() -> ControlProperty<Element>
}

/*
    Trait for `Observable`/`ObservableType` that represents property of UI element.
 
    Sequence of values only represents initial control value and user initiated value changes.
    Programmatic value changes won't be reported.
    Programmatic value changes 是因为, textFiled.text = "Hello World" 这种方式, 直接就跳过了 ControlTarget 的 Event 触发了, 那么也就不会触发后面的信号处理了.

    It's properties are:

    - `shareReplay(1)` behavior
        - it's stateful, upon subscription (calling subscribe) last element is immediately replayed if it was produced
    - it will `Complete` sequence on control being deallocated
    - it never errors out
    - it delivers events on `MainScheduler.instance`

    **The implementation of `ControlProperty` will ensure that sequence of values is being subscribed on main scheduler
    (`subscribe(on: ConcurrentMainScheduler.instance)` behavior).**

    **It is implementor's responsibility to make sure that that all other properties enumerated above are satisfied.**

    **If they aren't, then using this trait communicates wrong properties and could potentially break someone's code.**

    **In case `values` observable sequence that is being passed into initializer doesn't satisfy all enumerated
    properties, please don't use this trait.**
*/
/*
    ControlProperty 本身是对于 UIKit 的各种属性的封装. PropertyType 一般是 UIControl 的属性值类型.
    例如 UITextFiled.rx.text 就是一个 ControlProperty<String>
 
    本身这个类, 并没有太多的逻辑在里面, 仅仅是存储了 Publisher 和 Subscriber, 然后进行 delegate 而已.
 */
public struct ControlProperty<PropertyType> : ControlPropertyType {
    public typealias Element = PropertyType

    /*
     ControlProperty 本身可以充当两个角色, 一个是 Publisher, 一个是 Subscriber.
     Publisher 的实现是交给了 values, 各种 subscribe 调用的时候, 是 values.subscribe.
     Subscripber 的实现是交给了 valueSink.
     */
    let values: Observable<PropertyType>
    let valueSink: AnyObserver<PropertyType>

    /// Initializes control property with a observable sequence that represents property values and observer that enables
    /// binding values to property.
    ///
    /// - parameter values: Observable sequence that represents property values.
    /// - parameter valueSink: Observer that enables binding values to control property.
    /// - returns: Control property created with a observable sequence of values and an observer that enables binding values
    /// to property.
    public init<Values: ObservableType,
                Sink: ObserverType>(values: Values, valueSink: Sink) where Element == Values.Element, Element == Sink.Element {
        self.values = values.subscribe(on: ConcurrentMainScheduler.instance)
        self.valueSink = valueSink.asObserver()
    }

    /// Subscribes an observer to control property values.
    ///
    /// - parameter observer: Observer to subscribe to property values.
    /// - returns: Disposable object that can be used to unsubscribe the observer from receiving control property values.
    // Subscribe 返回的 disposable, 是为了取消订阅这件事.
    public func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.values.subscribe(observer)
    }

    /// `ControlEvent` of user initiated value changes. Every time user updates control value change event
    /// will be emitted from `changed` event.
    ///
    /// Programmatic changes to control value won't be reported.
    ///
    /// It contains all control property values except for first one.
    ///
    /// The name only implies that sequence element will be generated once user changes a value and not that
    /// adjacent sequence values need to be different (e.g. because of interaction between programmatic and user updates,
    /// or for any other reason).
    public var changed: ControlEvent<PropertyType> {
        ControlEvent(events: self.values.skip(1))
    }

    /// - returns: `Observable` interface.
    public func asObservable() -> Observable<Element> {
        self.values
    }

    /// - returns: `ControlProperty` interface.
    public func asControlProperty() -> ControlProperty<Element> {
        self
    }

    /// Binds event to user interface.
    ///
    /// - In case next element is received, it is being set to control value.
    /// - In case error is received, DEBUG buids raise fatal error, RELEASE builds log event to standard output.
    /// - In case sequence completes, nothing happens.
    // 直接把信号的处理逻辑, 交给了 valueSink 进行处理.
    public func on(_ event: Event<Element>) {
        switch event {
        case .error(let error):
            bindingError(error)
        case .next:
            self.valueSink.on(event)
        case .completed:
            self.valueSink.on(event)
        }
    }
}

/*
    orEmpty: 这件事, 主要是将 String 变为 ""
    作为系统来说, text = nil 表示没有输入值, "" 表示输入过值, 但是全部删除了.
    这在编码的角度来看, 经常是完全一致的. 所以, 将 Publisher 发出的信号从 String? 变为 String 是非常有效的一个做法.
 */

// 扩展是给 ControlPropertyType 添加功能, 而不是 ControlProperty.
extension ControlPropertyType where Element == String? {
    /// Transforms control property of type `String?` into control property of type `String`.
    public var orEmpty: ControlProperty<String> {
        
        let original: ControlProperty<String?> = self.asControlProperty()
        let values: Observable<String> = original.values.map { $0 ?? "" }
        let valueSink: AnyObserver<String> = original.valueSink.mapObserver { $0 }
        return ControlProperty<String>(values: values, valueSink: valueSink)
    }
}
