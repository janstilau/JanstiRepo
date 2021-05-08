//
//  CalculatorHistory.swift
//  Calculator
//
//  Created by 王 巍 on 2019/07/20.
//  Copyright © 2019 OneV's Den. All rights reserved.
//

import SwiftUI
import Combine

class Contact: ObservableObject {
    @Published var name: String
    @Published var age: Int

    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }

    func haveBirthday() -> Int {
        age += 1
        return age
    }
}

class CalculatorModel: ObservableObject {

    /*
     如果, 不使用 Published 的话, 那么手动实现数据改变通知外界的逻辑就是下面.
     在数据发生改变之前, 使用 objectWillChange 属性, send 该 Model 将要发生改变.
     使用该 Model 的 View, 会在接收到通知之后, 进行 View 的更新操作.
     var brain: CalculatorBrain = .left("0") {
        willSet { objectWillChange.send() }
     }
     
     通过这种方式, 就可以自由的组合数据了.
     Model 里面, 当需要触发外界改变的时候, 主动地调用 objectWillChange.send(), 这样外界使用到 model 的地方, 就会及时更新自己的显示.
     而 Model 里面的属性, 不一定都是 View 相关的, 或者, Model 里面, 需要进行 coordinate 操作, 将其他关联的数据一并更新之后, 最后进行一次
     objectWillChange.send() 的操作.
     通过将监听者, 被监听者进行分离, 使得 Model 比 @State 有了更大的灵活性.
     
     Binding 的运行机制应该是一样的. Binding 之后的数据发生改变, 会触发数据原有位置的通知, 这个不管是在 State 里面, 还是在 ObservableObject 里面.
     */
    
    @Published var brain: CalculatorBrain = .left("0")
    
    // 这里面, 记录的是, 每一次用户的操作.
    @Published var history: [CalculatorButtonItem] = []
    
    /*
     但是对于更复杂的情况，例如含有很多属性和方法的类型，可能其 中只有很少几个属性需要触发 UI 更新，也可能各个属性之间彼此有关联，那 么我们应该选择引用类型和更灵活的可自定义方式。
     这里, 其实是说明了, State 修饰的数据如果改变, 那么所有挂钩的 View 都会被改变.
     也就是说, State 的没有区分哪个 property 会影响到哪个 View. 只要值有变化, 就是 View 的整体变化.
     */
    @State var isListening = false

    
    // 当操作记录向前回溯的时候, 要存储已经回溯的 CalculatorButtonItem, 以便可以 redo.
    var temporaryKept: [CalculatorButtonItem] = []

    // model 应对用户操作数据协调的方法.
    // 之前只有 brain = brain.apply(item: item) 这一个方法.
    // 在有了 history 之后, 增加了对于历史记录的处理.
    func apply(_ item: CalculatorButtonItem) {
        brain = brain.apply(item: item)
        history.append(item)

        temporaryKept.removeAll()
        slidingIndex = Float(totalCount)
    }

    // 这是一个 View 相关的操作, 就是将操作记录里面所有的值串联起来进行界面的显示.
    var historyDetail: String {
        history.map { $0.description }.joined()
    }

    // 这是根据当前的用户手势行为, 进行数据改变的逻辑.
    func keepHistory(upTo index: Int) {
        precondition(index <= totalCount, "Out of index.")

        let total = history + temporaryKept

        // 首先, 根据 index 的值, 将应该显示的 history 和缓存的回溯值 temporaryKept 分别进行存储.
        history = Array(total[..<index])
        temporaryKept = Array(total[index...])

        // 然后 history 进行 reduce, 计算出当前应该显示到 View 上的 brain 到底应该是什么.
        brain = history.reduce(CalculatorBrain.left("0")) {
            result, item in
            result.apply(item: item)
        }
    }

    var totalCount: Int {
        history.count + temporaryKept.count
    }

    var slidingIndex: Float = 0 {
        didSet {
            keepHistory(upTo: Int(slidingIndex))
        }
    }
}
