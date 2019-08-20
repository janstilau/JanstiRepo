//
//  ManagedObjectChangeObserver.swift
//  Moody
//
//  Created by Daniel Eggert on 15/05/2015.
//  Copyright (c) 2015 objc.io. All rights reserved.
//

import Foundation
import CoreData


final class ManagedObjectObserver {
    enum ChangeType {
        case delete
        case update
    }

    /**
     接受 托管对象和回调方法. 内部的细节, 在使用过的时候不用考虑.
     */
    init?(object: NSManagedObject, changeHandler: @escaping (ChangeType) -> ()) {
        guard let moc = object.managedObjectContext else { return nil }
        token = moc.addObjectsDidChangeNotificationObserver { [weak self] note in
            guard let changeType = self?.changeType(of: object, in: note) else { return }
            changeHandler(changeType)
        }
    }

    /**
     在析构方法的内部, 进行了通知中心的注销操作, 减少了使用者的负担.
     */
    deinit {
        NotificationCenter.default.removeObserver(token)
    }

    // MARK: Private

    fileprivate var token: NSObjectProtocol!

    fileprivate func changeType(of object: NSManagedObject, in noti: NotiParser) -> ChangeType? {
        let deleted = noti.deletedObjects.union(noti.invalidatedObjects)
        if noti.invalidatedAllObjects || deleted.containsObjectIdentical(to: object) {
            return .delete
        }
        let updated = noti.updatedObjects.union(noti.refreshedObjects)
        if updated.containsObjectIdentical(to: object) {
            return .update
        }
        return nil
    }
}

