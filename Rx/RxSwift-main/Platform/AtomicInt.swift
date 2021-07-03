//
//  AtomicInt.swift
//  Platform
//
//  Created by Krunoslav Zaher on 10/28/18.
//  Copyright © 2018 Krunoslav Zaher. All rights reserved.
//

import Foundation

/*
 RxSwfit 里面, 对于 AtomicValue 的封装.
 我们习惯于类内一把锁, 进行相关成员变量的锁定. 但是实际上, 应该是相关的成员变量的修改使用一个锁.
 Atomic Type 就是在修改相关的数据的时候, 会进行 lock 处理. 所以, 这个类型一定是引用类型, 所保护的资源, 一定是在堆空间内.
 iOS 没有对应的 Atomic 实现, 这里自己实现一版.
 NSLock 保证了引用类型, 保证了所的实现. 所以, 用 NSLock 作为父类, 然后增加了一个 Int 值做成员变量.
 */

final class AtomicInt: NSLock {
    fileprivate var value: Int32
    public init(_ value: Int32 = 0) {
        self.value = value
    }
}



// 定义了各种全局方法, 进行 Atomic Int 的修改.
// 不太清楚为什么不定义成为成员函数.
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
