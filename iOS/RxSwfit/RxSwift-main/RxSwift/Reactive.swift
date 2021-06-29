//
//  Reactive.swift
//  RxSwift
//
//  Created by Yury Korolev on 5/2/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

/*
 Use `Reactive` proxy as customization point for constrained protocol extensions.

 General pattern would be:

 // 1. Extend Reactive protocol with constrain on Base
 // Read as: Reactive Extension where Base is a SomeType
 extension Reactive where Base: SomeType {
 // 2. Put any specific reactive extension for SomeType here
 
 这里面, 讲的很明白, 这种 rx.someMethod 的好处.
 1. 一个切入点, 之后再这个切入点之后, 才是 rx 相关的扩展.
 1. 类型相关的扩展. 根据 Base 的 Type, 进行特定 Type 的扩展.
 }

 With this approach we can have more specialized methods and properties using
 `Base` and not just specialized on common base type.

 `Binder`s are also automatically synthesized using `@dynamicMemberLookup` for writable reference properties of the reactive base.
 */

/*
 这个特性中文可以叫动态查找成员。
 在使用@dynamicMemberLookup标记了对象后（对象、结构体、枚举、protocol），实现了subscript(dynamicMember member: String)方法后我们就可以访问到对象不存在的属性。
 如果访问到的属性不存在，就会调用到实现的 subscript(dynamicMember member: String)方法，key 作为 member 传入这个方法。
 */

@dynamicMemberLookup
public struct Reactive<Base> {
    /// Base object to extend.
    public let base: Base

    /// Creates extensions with base object.
    ///
    /// - parameter base: Base object.
    public init(_ base: Base) {
        self.base = base
    }

    /// Automatically synthesized binder for a key path between the reactive
    /// base and one of its properties
    public subscript<Property>(dynamicMember keyPath: ReferenceWritableKeyPath<Base, Property>) -> Binder<Property> where Base: AnyObject {
        Binder(self.base) { base, value in
            base[keyPath: keyPath] = value
        }
    }
}

/// A type that has reactive extensions.
public protocol ReactiveCompatible {
    /// Extended type
    associatedtype ReactiveBase

    /// Reactive extensions.
    static var rx: Reactive<ReactiveBase>.Type { get set }

    /// Reactive extensions.
    var rx: Reactive<ReactiveBase> { get set }
}



extension ReactiveCompatible {
    /// Reactive extensions.
    public static var rx: Reactive<Self>.Type {
        get { Reactive<Self>.self }
        /*
            为了可以调用 mutating 方法, 一定要写 rx 的 sest 方法.
         */
        // this enables using Reactive to "mutate" base type
        // swiftlint:disable:next unused_setter_value
        set { }
    }

    /// Reactive extensions.
    public var rx: Reactive<Self> {
        get { Reactive(self) }
        // this enables using Reactive to "mutate" base object
        // swiftlint:disable:next unused_setter_value
        set { }
    }
}

import Foundation

/// Extend NSObject with `rx` proxy.
// 只要是 NSObject 的子类, 都会有 rx 的属性调用.
extension NSObject: ReactiveCompatible { }
