//
//  ScheduledItemType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 11/7/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

// 可被调用的数据结构, 只有一个要求, 那就是 invoable.
protocol ScheduledItemType
    : Cancelable
    , InvocableType {
    func invoke()
}
