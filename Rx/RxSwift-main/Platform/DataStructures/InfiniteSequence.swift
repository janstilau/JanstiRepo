//
//  InfiniteSequence.swift
//  Platform
//
//  Created by Krunoslav Zaher on 6/13/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

// 其实就是不断的重复一个 element;
// 能够实现, 主要是依靠了 AnyIterator 的闭包.

struct InfiniteSequence<Element> : Sequence {
    typealias Iterator = AnyIterator<Element>
    
    private let repeatedValue: Element
    
    init(repeatedValue: Element) {
        self.repeatedValue = repeatedValue
    }
    
    func makeIterator() -> Iterator {
        let repeatedValue = self.repeatedValue
        return AnyIterator { repeatedValue }
    }
}
