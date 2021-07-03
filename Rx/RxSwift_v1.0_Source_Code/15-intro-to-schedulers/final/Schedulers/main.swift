/*
 * Copyright (c) 2014-2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Foundation
import RxSwift

print("\n\n\n===== Schedulers =====\n")

let globalScheduler = ConcurrentDispatchQueueScheduler(queue: DispatchQueue.global())
let bag = DisposeBag()
let animal = BehaviorSubject(value: "[dog]")

animal
    .subscribeOn(MainScheduler.instance)
    .dump()
    .observeOn(globalScheduler)
    .dumpingSubscription()
    .addDisposableTo(bag)

let fruit = Observable<String>.create { observer in
    observer.onNext("[apple]")
    sleep(2) // 调用了系统的 Sleep 方法进行线程休眠.
    observer.onNext("[pineapple]")
    sleep(2) // 调用了系统的 Sleep 方法进行线程休眠.
    observer.onNext("[strawberry]")
    return Disposables.create()
}

fruit // Publisher
    .subscribeOn(globalScheduler) // SubscribeSink
    .dump() // DoSink
    .observeOn(MainScheduler.instance) // ObserverSink
    .dumpingSubscription() // End Subscriber.
    .addDisposableTo(bag)

// SubscribeSink 在 subscribe 的时候, 会进行 schedule 的调度, 将 source.subcribe(self) 这个动作进行调度.
// 而 SubscribeSink 自身的 on 方法, 仅仅是进行 forward.
// ObserverSink 在接受到信号的时候, 会进行 schedule 的调度, 将信号数据在另外的一个线程, 传递给 End

let animalsThread = Thread() {
    sleep(3)
    animal.onNext("[cat]")
    sleep(3)
    animal.onNext("[tiger]")
    sleep(3)
    animal.onNext("[fox]")
    sleep(3)
    animal.onNext("[leopard]")
}

animalsThread.name = "Animals Thread"
animalsThread.start()



RunLoop.main.run(until: Date(timeIntervalSinceNow: 13))

