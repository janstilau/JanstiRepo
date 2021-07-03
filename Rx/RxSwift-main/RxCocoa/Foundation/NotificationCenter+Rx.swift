//
//  NotificationCenter+Rx.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 5/2/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation
import RxSwift

extension Reactive where Base: NotificationCenter {
    /**
    Transforms notifications posted to notification center to observable sequence of notifications.
    
    - parameter name: Optional name used to filter notifications.
    - parameter object: Optional object used to filter notifications.
    - returns: Observable sequence of posted notifications.
    */
    /*
     这里是 NSNotificationCenter 的创建 Observable 的操作.
     返回的 dispose 仅仅是移除注册, 并没有调用 observer 的 on 方法.
     */
    public func notification(_ name: Notification.Name?, object: AnyObject? = nil) -> Observable<Notification> {
        return Observable.create { [weak object] observer in
            let nsObserver = self.base.addObserver(forName: name, object: object, queue: nil) { notification in
                observer.on(.next(notification))
            }
            
            return Disposables.create {
                self.base.removeObserver(nsObserver)
            }
        }
    }
}
