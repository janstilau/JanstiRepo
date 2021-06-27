//
//  ObserverBase.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

class ObserverBase<Element> : Disposable, ObserverType {
    private let isStopped = AtomicInt(0)

    // 在接受到信号之后, 会首先检查一下当前的状态, 如果已经 stopped, 是不会在对信号做出处理的.
    // 各种 Sink, 都会将信号进行传递.
    // 但是 Anyobserver 其实是指令式编程和声明式的一个切口, 后面不会有处理节点了. 所以, 在这里应首先判断状态值.
    func on(_ event: Event<Element>) {
        switch event {
        case .next:
            if load(self.isStopped) == 0 {
                self.onCore(event)
            }
        case .error, .completed:
            if fetchOr(self.isStopped, 1) == 0 {
                self.onCore(event)
            }
        }
    }

    func onCore(_ event: Event<Element>) {
        rxAbstractMethod()
    }

    func dispose() {
        fetchOr(self.isStopped, 1)
    }
}
