//
//  NopDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a disposable that does nothing on disposal.
///
/// Nop = No Operation
// 专门, 定义了一个类型, 用来返回没有实际意义的 dispose 对象.
// 这是为了保持接口的一致性. 很多时候, subscibe 根本没有意义, 所以返回一个 dispose 也没有意义.
// 这个时候, 返回一个 NopDisposable, 可以让实现的思路保持稳定.
private struct NopDisposable : Disposable {
 
    fileprivate static let noOp: Disposable = NopDisposable()
    
    private init() {
        
    }
    
    /// Does nothing.
    public func dispose() {
    }
}

extension Disposables {
    /**
     Creates a disposable that does nothing on disposal.
     */
    static public func create() -> Disposable { NopDisposable.noOp }
}
