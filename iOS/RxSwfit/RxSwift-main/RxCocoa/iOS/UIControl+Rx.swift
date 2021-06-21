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
    
    /*
        controlEvent 表示的是, 发生了该事件.
        controlProperty 表示的是, 发生了该事件, 通过 get 获取信号里面的值, 通过 set 来处理信号里面的值.
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

    public func controlProperty<T>(
        editingEvents: UIControl.Event, // event 表示, 这个 UIControl 作为 Publisher 的时候, 什么 Event 会触发信号.
        getter: @escaping (Base) -> T, // getter 表示, 在 UIControl 触发信号之后, 应该如何获取 Element 的值, 发送到后面的节点.
        setter: @escaping (Base, T) -> Void // setter 表示, 在作为 Observer 接受到信号之后, 应该执行什么样的操作, 来处理这个信号.
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
                
                // ControlTarget 的生命周期, 会被 Disposables.create 的返回值引用着.
                // 如果, 使用者没有使用这个值. ControlTarget 就会发生内存泄漏. 因为 ControlTarget 的自己的循环引用不会消失.
                return Disposables.create(with: controlTarget.dispose)
            }
            .take(until: deallocated)

        let bindingObserver = Binder(base, binding: setter)
        return ControlProperty<T>(values: source,
                                  valueSink: bindingObserver)
    }

    /// This is a separate method to better communicate to public consumers that
    /// an `editingEvent` needs to fire for control property to be updated.
    internal func controlPropertyWithDefaultEvents<T>(
        editingEvents: UIControl.Event = [.allEditingEvents,
                                          .valueChanged],
        getter: @escaping (Base) -> T,
        setter: @escaping (Base, T) -> Void
        ) -> ControlProperty<T> {
        
        return controlProperty(
            editingEvents: editingEvents,
            getter: getter,
            setter: setter
        )
    }
}

#endif
