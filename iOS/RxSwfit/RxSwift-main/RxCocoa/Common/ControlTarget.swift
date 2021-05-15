//
//  ControlTarget.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 2/21/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if os(iOS) || os(tvOS) || os(macOS)

import RxSwift

#if os(iOS) || os(tvOS)
    import UIKit

    typealias Control = UIKit.UIControl
#elseif os(macOS)
    import Cocoa

    typealias Control = Cocoa.NSControl
#endif

// This should be only used from `MainScheduler`
final class ControlTarget: RxTarget {
    
    typealias Callback = (Control) -> Void

    let selector: Selector = #selector(ControlTarget.eventHandler(_:))

    weak var control: Control? // UI 控件
    let controlEvents: UIControl.Event // 应该监听的事件
    var callback: Callback? // 监听到事件之后的回调
    
    #if os(iOS) || os(tvOS)
    init(control: Control, controlEvents: UIControl.Event, callback: @escaping Callback) {
        MainScheduler.ensureRunningOnMainThread()

        self.control = control
        self.controlEvents = controlEvents
        self.callback = callback

        super.init()

        control.addTarget(self, action: selector, for: controlEvents)

        let method = self.method(for: selector)
        if method == nil {
            rxFatalError("Can't find method")
        }
    }
#elseif os(macOS)
    init(control: Control, callback: @escaping Callback) {
        MainScheduler.ensureRunningOnMainThread()

        self.control = control
        self.callback = callback

        super.init()

        control.target = self
        control.action = self.selector

        let method = self.method(for: self.selector)
        if method == nil {
            rxFatalError("Can't find method")
        }
    }
#endif

    // 这个封装最大意义就在这里. 一个中间层, 将 Control 的 UI 事件, 通过这个中间层, 链接到 callback 里面. 而这个中间层, 是引用循环保持内存一直存在的.
    @objc func eventHandler(_ sender: Control!) {
        if let callback = self.callback, let control = self.control {
            callback(control)
        }
    }

    // Dispose 就是取消这些成员变量的存储.
    // 这样, 在按钮点击之后, 什么信号都不会发生.
    // UIControl 的声明周期是外界控制的. dispose 仅仅控制的是, 作为一个 Publisher, 他没有了产生信号的能力了. 并且, 将产生信号所需的其他资源都释放了.
    override func dispose() {
        super.dispose()
#if os(iOS) || os(tvOS)
        self.control?.removeTarget(self, action: self.selector, for: self.controlEvents)
#elseif os(macOS)
        self.control?.target = nil
        self.control?.action = nil
#endif
        self.callback = nil
    }
}

#endif
