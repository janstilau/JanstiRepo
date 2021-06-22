//
//  Disposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

// Disposable 代表的是一个概念. 这个概念就是, 它所代表的操作可以取消.
// 这操作, 可以是产生序列, 也可以是序列的监听器, 
public protocol Disposable {
    func dispose()
}
