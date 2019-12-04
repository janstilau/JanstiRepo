//
//  ManagedObject.swift
//  Moody
//
//  Created by Florian on 29/05/15.
//  Copyright (c) 2015 objc.io. All rights reserved.
//

import CoreData

// 可以直接用 class 指代 AnyObject

protocol ManagedObject: class, NSFetchRequestResult {
    static var entityName: String { get }
    static var defaultSortDescriptors: [NSSortDescriptor] { get }
}


extension ManagedObject {
    
    // 默认的实现, 实现类可以覆盖.
    static var defaultSortDescriptors: [NSSortDescriptor] {
        return []
    }

    static var sortedFetchRequest: NSFetchRequest<Self> {
        // 这里, 调用的是 entityName, 而不是 entity().name. entityName 作为协议的一部分, 是一定可以调用成功的.
        // 而下面的实现是, 在 实现类是 NSManagedObject 的情况下, entityName 就是 entity().name!
        let request = NSFetchRequest<Self>(entityName: entityName)
        request.sortDescriptors = defaultSortDescriptors
        return request
    }
}

extension ManagedObject where Self: NSManagedObject {
    static var entityName: String { return entity().name!  }
}

