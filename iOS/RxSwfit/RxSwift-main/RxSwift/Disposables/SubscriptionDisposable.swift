//
//  SubscriptionDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

// 一个特殊的数据结构, 可以用 key 来从 Owner 里面取消注册. Weak 来引用.
struct SubscriptionDisposable<T: SynchronizedUnsubscribeType> : Disposable {
    private let key: T.DisposeKey
    private weak var owner: T?

    init(owner: T, key: T.DisposeKey) {
        self.owner = owner
        self.key = key
    }

    func dispose() {
        self.owner?.synchronizedUnsubscribe(self.key)
    }
}
