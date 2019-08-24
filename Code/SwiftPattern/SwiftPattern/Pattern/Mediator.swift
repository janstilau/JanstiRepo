
//
//  Mediator.swift
//  SwiftPattern
//
//  Created by JustinLau on 2019/8/3.
//  Copyright © 2019 JustinLau. All rights reserved.
//

import Foundation


/**
 
 使用一个中介对象, 来封装一系列的对象的交互, 中介者使得各个对象之间不需要显示的互相引用, 从而实现耦合设计.
 
 基本上, MVC 里面的 C 就是处于这样的一个中介者的部件. 基本上, 中介者会保留对于各个子部件的引用, 然后作为一个协调器的作用, 来协调各个部件的交互作用.
 
 协调器基本上会和其他的设计一起使用, 各个部件会运用监听者设计, 将自己的状态改变事件传递出去, 也会提供一些方法, 来改变自身的数据. 而中介者, 就是监听变化, 以及修改数据的总的协调者. 如果没有中介者的话, 就需要各个部件之间相互引用, 关系复杂, 引用线纷乱. 有了中介者, 至少有了一个核心的结点, 来理清数据的流向.
 协调器往往会代码过多, 这种过多的代码, 一般是由于责任不清导致的.
 
 这个模式更多的是思想, 将数据的流向从相互引用的线, 变成有一个中心结点的数据流向的图.
 
 */

protocol Receiver {
    func receive(updatedItem: Sender)
}

protocol Sender {
    var recipients: [Receiver] { get }
    mutating func addRecipient(_ recipient: Receiver)
    func send(updatedItem: Sender)
}

struct Button: Sender {
    var recipients: [Receiver]
    mutating func addRecipient(_ recipient: Receiver) {
        recipients.append(recipient)
    }
    func send(updatedItem: Sender) {
        for recipient in recipients {
            recipient.receive(updatedItem: self)
        }
    }
}

/**
    swift 的 protocol 中可以指定 associateType, 但是指定了这个东西之后, 这个 protocol 就不能当做单独的类型来使用, 感觉这是一个大坑啊.
 */
