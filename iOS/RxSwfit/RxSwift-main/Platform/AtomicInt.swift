//
//  AtomicInt.swift
//  Platform
//
//  Created by Krunoslav Zaher on 10/28/18.
//  Copyright © 2018 Krunoslav Zaher. All rights reserved.
//

import Foundation

// iOS 平台, 实现 atmic Int. 其实就是加锁处理.
// 这是一个 NSLock, 所以是一个引用值.
final class AtomicInt: NSLock {
    fileprivate var value: Int32
    public init(_ value: Int32 = 0) {
        self.value = value
    }
}

// 各种操作, 都是之前的简单的算术运算, 增加了 lock 的处理.
@discardableResult
@inline(__always)
func add(_ this: AtomicInt, _ value: Int32) -> Int32 {
    this.lock()
    let oldValue = this.value
    this.value += value
    this.unlock()
    return oldValue
}

@discardableResult
@inline(__always)
func sub(_ this: AtomicInt, _ value: Int32) -> Int32 {
    this.lock()
    let oldValue = this.value
    this.value -= value
    this.unlock()
    return oldValue
}

@discardableResult
@inline(__always)
func fetchOr(_ this: AtomicInt, _ mask: Int32) -> Int32 {
    this.lock()
    let oldValue = this.value
    this.value |= mask
    this.unlock()
    return oldValue
}

@inline(__always)
func load(_ this: AtomicInt) -> Int32 {
    this.lock()
    let oldValue = this.value
    this.unlock()
    return oldValue
}

@discardableResult
@inline(__always)
func increment(_ this: AtomicInt) -> Int32 {
    add(this, 1)
}

@discardableResult
@inline(__always)
func decrement(_ this: AtomicInt) -> Int32 {
    sub(this, 1)
}

@inline(__always)
func isFlagSet(_ this: AtomicInt, _ mask: Int32) -> Bool {
    (load(this) & mask) != 0
}
