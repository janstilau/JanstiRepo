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
    static  var defaultSortDescriptors: [NSSortDescriptor] { return [] }
    
    static var sortedFetchRequest: NSFetchRequest<Self> {
        let request = NSFetchRequest<Self>(entityName: entityName)
        request.sortDescriptors = defaultSortDescriptors
        return request
    }
    
    public static func sortedFetchRequest(with predicate: NSPredicate) -> NSFetchRequest<Self> {
        let request = sortedFetchRequest
        request.predicate = predicate
        return request
    }
}

// 当实现类本身是一个 NSManagedObject 的子类的话, 会添加下面的这些方法.
extension ManagedObject where Self: NSManagedObject {
    static var entityName: String { return entity().name!  }
    
    /**
     NSManagedObjectContext:fetch
     An array of objects that meet the criteria specified by request fetched from the receiver and from the persistent stores associated with the receiver’s persistent store coordinator.
     configurationBlock 并不是必须的, 将这个值得类型, 设置为 Optional 不更好一点吗.
     */
    static func fetch(in context: NSManagedObjectContext,
                      configurationBlock: (NSFetchRequest<Self>) -> Void = { _ in }) -> [Self] {
        let request = NSFetchRequest<Self>(entityName: Self.entityName) // 这里, 其实可以写成 entityName
        configurationBlock(request) // 通过传入的 Block, 做 request 的配置工作, 最后, 进行 fetch 的操作.
        return try! context.fetch(request)
    }
    
    // 先查找有没有这个对象, 如果没有, 进行创建.
    static func findOrCreate(in context: NSManagedObjectContext,
                             matching predicate: NSPredicate,
                             configure: (Self) -> Void) -> Self {
        if let object = findOrFetch(in: context, matching: predicate) {
            return object
        }
        let newObject: Self = context.insertObject()
        configure(newObject)
        return newObject
    }
    
    // 先从缓存中找, 没有的话, 执行重新的 fetch 操作.
    static func findOrFetch(in context: NSManagedObjectContext, matching predicate: NSPredicate) -> Self? {
        if let object = materializedObject(in: context, matching: predicate) {
            return object
        }
        return fetch(in: context) { request in
            request.predicate = predicate
            request.returnsObjectsAsFaults = false
            request.fetchLimit = 1 // 只拿一条.
        }.first
    }
    
    static func materializedObject(in context: NSManagedObjectContext, matching predicate: NSPredicate) -> Self? {
        for object in context.registeredObjects where !object.isFault {
            // 如果, 这个对象是自己的类型, 并且符合 predictate 的话, 直接返回.
            guard let result = object as? Self, predicate.evaluate(with: result) else { continue }
            return result
        }
        return nil
    }
}

