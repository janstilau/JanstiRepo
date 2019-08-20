//
//  ManagedObject.swift
//  Moody
//
//  Created by Florian on 29/05/15.
//  Copyright (c) 2015 objc.io. All rights reserved.
//

import CoreData


protocol ManagedObject: class, NSFetchRequestResult {
    static var entityName: String { get }
    static var defaultSortDescriptors: [NSSortDescriptor] { get }
}


extension ManagedObject {
    static var defaultSortDescriptors: [NSSortDescriptor] {
        return []
    }

    static var sortedFetchRequest: NSFetchRequest<Self> {
        // 一个 get 方法, 一个计算属性.
        let request = NSFetchRequest<Self>(entityName: entityName) // entityName 是ManagedObject 中的一个方法, 下面给出了一个默认的实现.
        request.sortDescriptors = defaultSortDescriptors
        return request
    }
}


extension ManagedObject where Self: NSManagedObject {
    static var entityName: String { return entity().name!  }
}

