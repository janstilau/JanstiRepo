//
//  RxTarget.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 7/12/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

import RxSwift

// RxTarget 最最主要的作用, 就是循环引用自己, 然后在外界要有一个明确的时间点, 调用这个对象的切断循环引用的方法.
/*
    自身的循环引用的只有在 init 方法里面, 和 dispose 方法里面进行改变了.
    
 */
class RxTarget : NSObject
               , Disposable {
    
    private var retainSelf: RxTarget?
    
    override init() {
        super.init()
        self.retainSelf = self
    }
    
    func dispose() {
        self.retainSelf = nil
    }
}
