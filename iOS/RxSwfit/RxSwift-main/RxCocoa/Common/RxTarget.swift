//
//  RxTarget.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 7/12/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

import RxSwift

class RxTarget : NSObject
               , Disposable {
    
    private var retainSelf: RxTarget?
    
    override init() {
        super.init()
        // 在这里, 特意进行一次引用循环. 这样, 如果不进行 dispose 的调用, 就会发生内存泄漏了.
        self.retainSelf = self

#if TRACE_RESOURCES
        _ = Resources.incrementTotal()
#endif

#if DEBUG
        MainScheduler.ensureRunningOnMainThread()
#endif
    }
    
    // 在 dispose 里面, 进行引用循环的打破
    func dispose() {
#if DEBUG
        MainScheduler.ensureRunningOnMainThread()
#endif
        self.retainSelf = nil
    }

#if TRACE_RESOURCES
    deinit {
        _ = Resources.decrementTotal()
    }
#endif
}
