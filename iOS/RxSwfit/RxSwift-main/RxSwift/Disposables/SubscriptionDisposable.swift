//
//  SubscriptionDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

// 一个特殊的 Disposable 实现类. 它的 dispose 就是调用 owen 的 synchronizedUnsubscribe 方法, 进行取消注册的操作.
struct SubscriptionDisposable<T: SynchronizedUnsubscribeType> : Disposable {
    private let key: T.DisposeKey
    // 这里, owner 是 weak 存储的.  所以 dispose 对象, 不会有内存管理引用计数的变化.
    private weak var owner: T?

    init(owner: T, key: T.DisposeKey) {
        self.owner = owner
        self.key = key
    }

    func dispose() {
        self.owner?.synchronizedUnsubscribe(self.key)
    }
}
