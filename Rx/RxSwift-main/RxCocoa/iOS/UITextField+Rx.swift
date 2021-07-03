//
//  UITextField+Rx.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 2/21/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if os(iOS) || os(tvOS)

import RxSwift
import UIKit


extension Reactive where Base: UITextField {
    /// Reactive wrapper for `text` property.
    public var text: ControlProperty<String?> {
        value
    }
    
    // ControlPropertyWithDefaultEvents 是 UIControl 的方法.
    // UIControl 封装了事件处理相关的逻辑.
    public var value: ControlProperty<String?> {
        return base.rx.controlPropertyWithDefaultEvents(
            getter: { textField in
                textField.text
            },
            setter: { textField, value in
                if textField.text != value {
                    textField.text = value
                }
            }
        )
    }
    
    /// Bindable sink for `attributedText` property.
    public var attributedText: ControlProperty<NSAttributedString?> {
        return base.rx.controlPropertyWithDefaultEvents(
            getter: { textField in
                textField.attributedText
            },
            setter: { textField, value in
                if textField.attributedText != value {
                    textField.attributedText = value
                }
            }
        )
    }
}

#endif
