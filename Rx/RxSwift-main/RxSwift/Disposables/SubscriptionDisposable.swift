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

    // 这里, dispose 中, owner 是 optinal.
    // 因为实际上, 可能会 Publisher 已经消亡了. 但是注册还存在着.
    // 这在拿到另外一个对象的Publisher来进行 subscibe 是经常出现的. Publisher 的生命周期, 跟随着另外一个对象.
    func dispose() {
        self.owner?.synchronizedUnsubscribe(self.key)
    }
}
