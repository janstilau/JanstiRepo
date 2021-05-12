//
//  SynchronizedUnsubscribeType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

// 一个特殊的协议, 这个协议主要就是根据 disposeKey 进行取消注册的操作.
protocol SynchronizedUnsubscribeType: AnyObject {
    associatedtype DisposeKey

    func synchronizedUnsubscribe(_ disposeKey: DisposeKey)
}
