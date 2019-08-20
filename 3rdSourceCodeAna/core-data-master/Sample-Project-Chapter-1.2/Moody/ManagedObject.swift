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


extension ManagedObject where Self: NSManagedObject {
    static var entityName: String { return entity().name!  }

    /**
     * configurationBlock 这里有一个默认参数, 所以这个函数的定义比较难看懂.
     NSManagedObjectContext:fetch
     An array of objects that meet the criteria specified by request fetched from the receiver and from the persistent stores associated with the receiver’s persistent store coordinator.
     */
    static func fetch(in context: NSManagedObjectContext,
                      configurationBlock: (NSFetchRequest<Self>) -> () = { _ in }) -> [Self] {
        let request = NSFetchRequest<Self>(entityName: Self.entityName)
        configurationBlock(request)
        return try! context.fetch(request)
    }

    static func findOrCreate(in context: NSManagedObjectContext,
                             matching predicate: NSPredicate,
                             configure: (Self) -> ()) -> Self {
        if let object = findOrFetch(in: context, matching: predicate) {
            return object
        }
        let newObject: Self = context.insertObject()
        configure(newObject)
        return newObject
    }

    static func findOrFetch(in context: NSManagedObjectContext, matching predicate: NSPredicate) -> Self? {
//        这里, 用 guard 感觉怪怪的, 应该就是正常的guard. guard 不应该用在这个地方.
//        guard let object = materializedObject(in: context, matching: predicate) else {
//            return fetch(in: context) { request in
//                request.predicate = predicate
//                request.returnsObjectsAsFaults = false
//                request.fetchLimit = 1
//            }.first
//        }
//        return object
        if let object = materializedObject(in: context, matching: predicate) {
            return object
        }
        return fetch(in: context) { request in
            request.predicate = predicate
            request.returnsObjectsAsFaults = false
            request.fetchLimit = 1
        }.first
    }

    static func materializedObject(in context: NSManagedObjectContext, matching predicate: NSPredicate) -> Self? {
        for object in context.registeredObjects where !object.isFault {
            guard let result = object as? Self, predicate.evaluate(with: result) else { continue }
            return result
        }
        return nil
    }
}

