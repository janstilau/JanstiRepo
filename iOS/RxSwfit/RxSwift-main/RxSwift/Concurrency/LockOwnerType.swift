//
//  LockOwnerType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

// 协议, 规定最基础的要求.
protocol LockOwnerType: AnyObject, Lock {
    var lock: RecursiveLock { get }
}

// 在协议上, 增加各种方便的方法.
extension LockOwnerType {
    func lock() { self.lock.lock() }
    func unlock() { self.lock.unlock() }
}
