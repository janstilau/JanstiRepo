//
//  AtomicInt.swift
//  Platform
//
//  Created by Krunoslav Zaher on 10/28/18.
//  Copyright © 2018 Krunoslav Zaher. All rights reserved.
//

import Foundation

/*
 RxSwfit 里面, 对于 atomicValue 的封装.
 就是在锁的环境下, 进行 property 的操作行为.
 Atomic 相关类的意义就在于, 对于这个值来说, 只会有一个线程正在进行访问.
 */

final class AtomicInt: NSLock {
    fileprivate var value: Int32
    public init(_ value: Int32 = 0) {
        self.value = value
    }
}

/*
 所有的这些操作, 都是用的全局函数的方式.
 */

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
