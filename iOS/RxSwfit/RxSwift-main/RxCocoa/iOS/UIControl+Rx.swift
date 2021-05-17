//
//  UIControl+Rx.swift
//  RxCocoa
//
//  Created by Daniel Tartaglia on 5/23/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if os(iOS) || os(tvOS)

import RxSwift
import UIKit

extension Reactive where Base: UIControl {
    /// Reactive wrapper for target action pattern.
    ///
    /// - parameter controlEvents: Filter for observed event types.
    
    /*
        从这里我们看出, Create 里面存储的, 是 subscibe 调用的时候, Publisher 应该如何根据 Observer 做参数执行的逻辑.
        有可能是, 直接 observer.on 这样调用了.
        也有可能是, 继续将 observer 进行封装, 像这里, 就是将 observer 作为了 UIControl 的点击事件信号的后续节点.
     */
    public func controlEvent(_ controlEvents: UIControl.Event) -> ControlEvent<()> {
        let source: Observable<Void> = Observable.create {
            // control 才是真正真正需要的, 无论是通过给 类型增加分类, self 取值, 还是 self.base 取值, 只要能拿到值, 就能达到目的.
            [weak control = self.base] observer in
                MainScheduler.ensureRunningOnMainThread()

                guard let control = control else {
                    // 如果, UIControl 的生命周期已经结束, 直接后续的节点接受完成信号.
                    observer.on(.completed)
                    return Disposables.create()
                }

                // 在这里, 生成了一个 ControlTarget 对象. ControlTarget 被点击的回调, 就是它的后续 observer 接受到一个新的事件信号.
                //
                let controlTarget = ControlTarget(control: control, controlEvents: controlEvents) { _ in
                    observer.on(.next(()))
                }

                return Disposables.create(with: controlTarget.dispose)
            }
            .take(until: deallocated)

        // 虽然, ControlEvent 是一个 Struct, 但是 Source 是一个引用类型.
        return ControlEvent(events: source)
    }

    /// Creates a `ControlProperty` that is triggered by target/action pattern value updates.
    ///
    /// - parameter controlEvents: Events that trigger value update sequence elements.
    /// - parameter getter: Property value getter.
    /// - parameter setter: Property value setter.
    public func controlProperty<T>(
        editingEvents: UIControl.Event,
        getter: @escaping (Base) -> T,
        setter: @escaping (Base, T) -> Void
    ) -> ControlProperty<T> {
        // Source 是一个 Publisher, 每次 Control 的 Event 发生之后, 就会发生信号.
        let source: Observable<T> = Observable.create { [weak weakControl = base] observer in
                guard let control = weakControl else {
                    observer.on(.completed)
                    return Disposables.create()
                }

                // 在 subscribe 的时候, 先把 control 当前的状态, 暴露出去.
                observer.on(.next(getter(control)))
                
                // 然后, 建立里一个中间层 ControlTarget, 这个中间层的 Control event 的触发函数, 就是调用 Observer 的 on 方法.
                // 这就是, UIControl 可以当做 Publisher 的原因所在.
                let controlTarget = ControlTarget(control: control, controlEvents: editingEvents) { _ in
                    if let control = weakControl {
                        observer.on(.next(getter(control)))
                    }
                }
                
                return Disposables.create(with: controlTarget.dispose)
            }
            .take(until: deallocated)

        let bindingObserver = Binder(base, binding: setter)

        return ControlProperty<T>(values: source, valueSink: bindingObserver)
    }

    /// This is a separate method to better communicate to public consumers that
    /// an `editingEvent` needs to fire for control property to be updated.
    internal func controlPropertyWithDefaultEvents<T>(
        editingEvents: UIControl.Event = [.allEditingEvents, .valueChanged],
        getter: @escaping (Base) -> T,
        setter: @escaping (Base, T) -> Void
        ) -> ControlProperty<T> {
        // 返回一个 ControlProperty
        return controlProperty(
            editingEvents: editingEvents,
            getter: getter,
            setter: setter
        )
    }
}

#endif
