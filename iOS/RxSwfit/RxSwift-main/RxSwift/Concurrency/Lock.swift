//
//  Lock.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/31/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol Lock {
    func lock()
    func unlock()
}

// https://lists.swift.org/pipermail/swift-dev/Week-of-Mon-20151214/000321.html
typealias SpinLock = RecursiveLock

// 一个简便的方法, 在很多的类库都见过. 传递闭包来, 在闭包前后进行加锁解锁.
// 这样, 闭包的运行, 一定在锁的保护之下.
extension RecursiveLock : Lock {
    @inline(__always)
    final func performLocked<T>(_ action: () -> T) -> T {
        self.lock(); defer { self.unlock() }
        return action()
    }
}
