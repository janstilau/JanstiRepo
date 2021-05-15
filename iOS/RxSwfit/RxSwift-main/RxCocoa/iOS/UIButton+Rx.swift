//
//  UIButton+Rx.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 3/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if os(iOS)

import RxSwift
import UIKit

/*
 通过向 Reactive 上添加行为, 而不是像 UIButton 上添加行为.
 touchBtn.rx.tap.map{}
 rx 返回一个特殊的类型 Reactive, 这个类型, 存储了 self.
 不断的扩展 Reactive, 通过 where Base, 在不同的类型上, 添加不同的类型自己的扩展.
 .rx 返回一个特殊类型的方式, 很像是 lazy, 但是通过 Base 按照类型添加方法, Lazy 没有体现. 不过, 这种模式现在很普遍.
 */

extension Reactive where Base: UIButton {
        
    // 返回类型, ControlEvent, 是一个 Publisher
    public var tap: ControlEvent<Void> {
        controlEvent(.touchUpInside)
    }
}

#endif

#if os(tvOS)

import RxSwift
import UIKit

extension Reactive where Base: UIButton {

    /// Reactive wrapper for `PrimaryActionTriggered` control event.
    public var primaryAction: ControlEvent<Void> {
        controlEvent(.primaryActionTriggered)
    }

}

#endif

#if os(iOS) || os(tvOS)

import RxSwift
import UIKit

extension Reactive where Base: UIButton {
    /// Reactive wrapper for `setTitle(_:for:)`
    public func title(for controlState: UIControl.State = []) -> Binder<String?> {
        Binder(self.base) { button, title in
            button.setTitle(title, for: controlState)
        }
    }

    /// Reactive wrapper for `setImage(_:for:)`
    public func image(for controlState: UIControl.State = []) -> Binder<UIImage?> {
        Binder(self.base) { button, image in
            button.setImage(image, for: controlState)
        }
    }

    /// Reactive wrapper for `setBackgroundImage(_:for:)`
    public func backgroundImage(for controlState: UIControl.State = []) -> Binder<UIImage?> {
        Binder(self.base) { button, image in
            button.setBackgroundImage(image, for: controlState)
        }
    }
    
}
#endif

#if os(iOS) || os(tvOS)
    import RxSwift
    import UIKit
    
    extension Reactive where Base: UIButton {
        /// Reactive wrapper for `setAttributedTitle(_:controlState:)`
        public func attributedTitle(for controlState: UIControl.State = []) -> Binder<NSAttributedString?> {
            return Binder(self.base) { button, attributedTitle -> Void in
                button.setAttributedTitle(attributedTitle, for: controlState)
            }
        }
    }
#endif
