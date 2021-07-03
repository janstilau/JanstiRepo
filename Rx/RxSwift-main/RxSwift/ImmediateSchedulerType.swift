//
//  ImmediateSchedulerType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 5/31/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
    这个抽象的意义在于. 有一块数据, 然后这块数据的操作.
    这个操作, 可能要在特殊的线程, 或者时间点才能 invoke.
    例如 GCD, OperationQueue, 就是不同线程之间的调度.
    也可以是定时器, 或者延时操作.
    总之, 这是一个异步行为可以实现的基础.
 */
public protocol ImmediateSchedulerType {
    /*
    Schedules an action to be executed immediately.
    
    - parameter state: State passed to the action to be executed.
    - parameter action: Action to be executed.
    - returns: The disposable object used to cancel the scheduled action (best effort).
    */
    func schedule<StateType>(_ state: StateType,
                             action: @escaping (StateType) -> Disposable) -> Disposable
}

extension ImmediateSchedulerType {
    /**
    Schedules an action to be executed recursively.
    
    - parameter state: State passed to the action to be executed.
    - parameter action: Action to execute recursively. The last parameter passed to the action is used to trigger recursive scheduling of the action, passing in recursive invocation state.
    - returns: The disposable object used to cancel the scheduled action (best effort).
    */
    public func scheduleRecursive<State>(_ state: State, action: @escaping (_ state: State,
                                                                            _ recurse: (State) -> Void) -> Void) -> Disposable {
        let recursiveScheduler = RecursiveImmediateScheduler(action: action, scheduler: self)
        
        recursiveScheduler.schedule(state)
        
        return Disposables.create(with: recursiveScheduler.dispose)
    }
}
