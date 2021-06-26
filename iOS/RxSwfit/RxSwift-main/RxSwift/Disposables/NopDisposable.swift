//
//  NopDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
    一个特殊的 Disposable 对象, 范围标识符 private 的使用.
    只能通过 Disposables.create() 来获取.
    这种写法, 在 Swift 这种, 使用协议来编码的语言里面很流行. 没有闭包将真正的对象暴露出去, 仅仅暴露接口对象出去就可以了.
    
    这个特殊的对象, 代表着就是他所代表的操作,
    是不可以取消的. 或者, 是不需要取消的.
 */
private struct NopDisposable : Disposable {
 
    fileprivate static let noOp: Disposable = NopDisposable()
    
    private init() {
    }
    
    public func dispose() {
    }
}

extension Disposables {
    static public func create() -> Disposable { NopDisposable.noOp }
}
