
//
//  Command.swift
//  SwiftPattern
//
//  Created by JustinLau on 2019/8/3.
//  Copyright © 2019 JustinLau. All rights reserved.
//

import Foundation


/**
 
 命令模式.
 
 软件的构建过程中, 行为的请求者和行为的实现者, 经常出现紧耦合.
 这里, 消息的发送者, 消息的接受者 之前同样不太理解. 其实这个概念很简单, 代码写在了哪里, 哪里就是请求者发送者, 比如, visiter.buy 这个函数调用, 行为的实现者, 消息的接受者就是 visiter, 而这个函数, 是在vc 里面被调用, 那么请求者和消息的发送者, 就是 vc.
 
 命令模式想要实现的目的在于, 存储行为. 在没有命令对象的时候, 行为是函数调用, 是静态硬编码到回调函数里面. 而用了命令这个对象之后, 这就变成了一个内存值, 而这个内存值就可以进行操作了.
 在 Command 的子类里面, 可以有自己各自的参数, execute 里面, 也必定是调用参数的方法, 比如, 编辑器里面, 必定有 doc 参数, 而不同的命令, 则是调用 doc 的不同函数. 在按钮点击的回调里面, 也是在不同的回调里面, 生成了不同的命令子类对象, 然后放到了 commandStack 里面. 看着好像是, 不同的回调调用不同的方法, 和直接在回调里面调用没有什么不同.
 但是, 一旦是用命令对象这种方式, 就可以进行了存储. CommandStack 里面的操作, 就可以延后执行, 就可以 undo, redo. 这一切, 都是建立在对象这个占据内存空间的概念的基础上的.
 
 在实现 command 的模式, 需要注意以下的几点.
 1. 如果要实现 undo, redo 的操作, 那么一旦使用 command 模式, 所有的操作都应该用 command. 不然, 一些数据的修改通过了 command, 一些数据的修改又没有通过. 数据就不能完全的还原回去了.
 2. 如果需要 undo, redo, command 的对象里面, 要承担起参数的生命周期的管理的作用. 这在 oc 里面不是问题, 但是在 c++ 中, 需要人工管理内存的时候, 要将对象的释放操作, 放到 command 的 dealloc 中去.
 3. CommandStack. command 仅仅是记录行为, 需要有一个管理者. 也就是说, 大部分的处理逻辑, 是要放到 commandStack 中, 所以, 如果有机会要看一下这个类的源码, 因为这个模式的主要逻辑, 是在这里的.

class Command {
    public:
    virtual void execute() = 0;
};

class ConcreteCommand: public Command {
    string mDescripiton;
    public:
    ConcreteCommand(const string& desc): mDescripiton(desc){}
    void execute() {
        cout << mDescripiton;
    }
};

class MacroCommand: public Command {
    vector<Command*> mCommands;
    public:
    void addCommand(Command *c) {
        mCommands.push_back(c);
    }
    
    void execute() {
        for (auto &c: mCommands) {
            c.execute();
        }
    }
};
 */

protocol Command {
    func execute();
}

final class CopyCommand: Command {
    let desc: String
    
    required init(desc: String) {
        self.desc = desc
    }
    
    func execute() {
        print("Copy")
    }
}




