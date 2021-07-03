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

final class ControlTarget: RxTarget {
    
    typealias Callback = (Control) -> Void

    let selector: Selector = #selector(ControlTarget.eventHandler(_:))

    weak var control: Control? // UI 控件
    let controlEvents: UIControl.Event // 应该监听的事件
    var callback: Callback? // 监听到事件之后的回调
    
    init(control: Control, controlEvents: UIControl.Event, callback: @escaping Callback) {

        self.control = control
        self.controlEvents = controlEvents
        self.callback = callback

        super.init()

        control.addTarget(self, action: selector, for: controlEvents)
    }

    @objc func eventHandler(_ sender: Control!) {
        if let callback = self.callback,
           let control = self.control {
            callback(control)
        }
    }

    override func dispose() {
        // super.dispose 切断了循环引用.
        // 后面的操作, 取消了事件处理.
        super.dispose()
        self.control?.removeTarget(self, action: self.selector, for: self.controlEvents)
        self.callback = nil
    }
}

#endif
