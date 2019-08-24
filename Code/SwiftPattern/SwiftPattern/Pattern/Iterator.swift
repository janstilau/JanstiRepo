//
//  Iterator.swift
//  SwiftPattern
//
//  Created by JustinLau on 2019/8/3.
//  Copyright © 2019 JustinLau. All rights reserved.
//

import Foundation

/**
 迭代器.
 
 迭代器其实就是一组接口, 不同语言的接口不一样, 比如, swift 里面就是用的 next , next 如果返回 nil, 代表着迭代结束了, 否则返回容器响应位置的值.
 而 C++ 里面, 其实是用了 ++ 操作符进行下移的操作, 用了
 
 
 */

struct MyIterator<Element>: IteratorProtocol {
    
    let collection: MyCollection<Element>
    var index: Int = 0
    
    init(collection: MyCollection<Element>) { // 这里, 按照 swift 的规则, 是没有进行新的一份 MyCollection 生成的.
        self.collection = collection
    }
    
    /**
     迭代器只要可以拿到容器的下一个元素就可以了, 如果, 容器提供了获取的方法的话, 那么没有必要拿到容器的底层的数据结构.
     这种情况一般出现在, 这个迭代器是对已有的容器的包装而已, 比如, 我们如果想要达成一个 reverseArrayIter, 那么其实就是控制 index 的值就可以了.
     而编写新的容器, 用到 C 数组那种概念的话, 就应该将底层的数据也暴露给 Iter.
     */
    mutating func next() -> Element? {
        defer {
            index += 1
        }
        return index >= collection.count ? nil : collection[index]
    }
}

struct MyCollection<Element>: Sequence {
    var containers: [Element]
    init() {
        print(" Mycollection contruct ")
        containers = [Element]()
    }
    var count: Int {
        return containers.count
    }
    subscript(index: Int) -> Element {
        get {
            return containers[index]
        }
        set {
            containers[index] = newValue
        }
    }
    mutating func append(ele: Element) {
        containers.append(ele)
    }
    __consuming func makeIterator() -> MyIterator<Element> {
        return MyIterator(collection: self)
    }
}

func iteratorDemo() {
    var value = MyCollection<Int>()
    // for in 中的 value 值都是 let 的, 并且不能写 let 关键字, 而想要 var 的话, 可以特地写下面的这种 var
    for i in 1...20 {
        value.append(ele: i)
    }
    for var itemInt  in 1..<20 {
        itemInt = 20
        print("\(itemInt)")
    }
    for v in value {
        print("It's value: \(v)")
    }
    
}
