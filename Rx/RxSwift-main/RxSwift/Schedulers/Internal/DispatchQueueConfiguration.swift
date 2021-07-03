//
//  DispatchQueueConfiguration.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 7/23/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import Dispatch
import Foundation

struct DispatchQueueConfiguration {
    let queue: DispatchQueue
    // leeway 余地, 偏航.
    let leeway: DispatchTimeInterval
}

/*
    schedule 这个方法, 主要就是为了 Action 的使用的. Action 返回一个 Disposable. 但是 Action 的调用, 要从原有的 Queue, 变为 Configuration 里面存储的 Queue.
    如果, 任务执行时, 已经被 cancle 了, Action 也就不执行了.
    action 执行完之后返回的 Disposable, 存储到 cancel 的内部, 这样外界调用 disposable, 里面的也能够被调用了
 */
extension DispatchQueueConfiguration {
    func schedule<StateType>(_ state: StateType,
                             action: @escaping (StateType) -> Disposable) -> Disposable {
        let cancel = SingleAssignmentDisposable()

        self.queue.async {
            if cancel.isDisposed {
                return
            }
            cancel.setDisposable(action(state))
        }

        return cancel
    }

    // 在什么时间点, 进行 action 的处理.
    func scheduleRelative<StateType>(_ state: StateType,
                                     dueTime: RxTimeInterval,
                                     action: @escaping (StateType) -> Disposable) -> Disposable {
        let deadline = DispatchTime.now() + dueTime

        let compositeDisposable = CompositeDisposable()

        let timer = DispatchSource.makeTimerSource(queue: self.queue)
        timer.schedule(deadline: deadline, leeway: self.leeway)

        // TODO:
        // This looks horrible, and yes, it is.
        // It looks like Apple has made a conceputal change here, and I'm unsure why.
        // Need more info on this.
        // It looks like just setting timer to fire and not holding a reference to it
        // until deadline causes timer cancellation.
        var timerReference: DispatchSourceTimer? = timer
        let cancelTimer = Disposables.create {
            timerReference?.cancel()
            timerReference = nil
        }

        timer.setEventHandler(handler: {
            if compositeDisposable.isDisposed {
                return
            }
            _ = compositeDisposable.insert(action(state))
            cancelTimer.dispose()
        })
        timer.resume()

        _ = compositeDisposable.insert(cancelTimer)
        // compositeDisposable 里面, 存储了定时器的 disposable, 存储了 action 的 disposable.
        // 定时器触发时, 调用了 action, 并且主动触发 timer 的 disposable.
        return compositeDisposable
    }

    // 周期性的, 进行 action 的调用.
    func schedulePeriodic<StateType>(_ state: StateType, startAfter: RxTimeInterval, period: RxTimeInterval, action: @escaping (StateType) -> StateType) -> Disposable {
        let initial = DispatchTime.now() + startAfter

        var timerState = state

        let timer = DispatchSource.makeTimerSource(queue: self.queue)
        timer.schedule(deadline: initial, repeating: period, leeway: self.leeway)
        
        // TODO:
        // This looks horrible, and yes, it is.
        // It looks like Apple has made a conceputal change here, and I'm unsure why.
        // Need more info on this.
        // It looks like just setting timer to fire and not holding a reference to it
        // until deadline causes timer cancellation.
        var timerReference: DispatchSourceTimer? = timer
        let cancelTimer = Disposables.create {
            timerReference?.cancel()
            timerReference = nil
        }

        timer.setEventHandler(handler: {
            if cancelTimer.isDisposed {
                return
            }
            timerState = action(timerState)
        })
        timer.resume()
        
        return cancelTimer
    }
}
