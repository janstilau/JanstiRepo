//
//  Notifications.swift
//  Moody
//
//  Created by Daniel Eggert on 24/05/2015.
//  Copyright (c) 2015 objc.io. All rights reserved.
//

import Foundation
import CoreData


struct NotiParser {

    private let notification: Notification
    
    init(note: Notification) {
        assert(note.name == NSNotification.Name.NSManagedObjectContextObjectsDidChange)
        notification = note
    }

    // 这里, 通过明确的函数, 对松散的字符串 key 字典取值的方法, 做了强类型的封装操作.
    var insertedObjects: Set<NSManagedObject> {
        return objects(forKey: NSInsertedObjectsKey)
    }

    var updatedObjects: Set<NSManagedObject> {
        return objects(forKey: NSUpdatedObjectsKey)
    }

    var deletedObjects: Set<NSManagedObject> {
        return objects(forKey: NSDeletedObjectsKey)
    }

    var refreshedObjects: Set<NSManagedObject> {
        return objects(forKey: NSRefreshedObjectsKey)
    }

    var invalidatedObjects: Set<NSManagedObject> {
        return objects(forKey: NSInvalidatedObjectsKey)
    }

    var invalidatedAllObjects: Bool {
        return (notification as NSNotification).userInfo?[NSInvalidatedAllObjectsKey] != nil
    }

    var managedObjectContext: NSManagedObjectContext {
        guard let c = notification.object as? NSManagedObjectContext else { fatalError("Invalid notification object") }
        return c
    }

    // MARK: Private

    fileprivate func objects(forKey key: String) -> Set<NSManagedObject> {
        // as 在无缝衔接的时候使用 ?? 这里有些不明白.
        return ((notification as NSNotification).userInfo?[key] as? Set<NSManagedObject>) ?? Set()
    }

}


extension NSManagedObjectContext {

    // 将通知的监听, 通过 block 的方式进行了监听. block 的内部会构造一个 parser 对象, 然后调用业务处理 block.
    func addObjectsDidChangeNotificationObserver(_ handler: @escaping (NotiParser) -> ()) -> NSObjectProtocol {
        let nc = NotificationCenter.default
        return nc.addObserver(forName: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: self, queue: nil) { notification in
            let wrappedNote = NotiParser(note: notification)
            handler(wrappedNote)
        }
    }
}


