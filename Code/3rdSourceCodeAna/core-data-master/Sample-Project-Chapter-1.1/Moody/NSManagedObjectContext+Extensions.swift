//
//  Extensions.swift
//  Moody
//
//  Created by Florian on 07/05/15.
//  Copyright (c) 2015 objc.io. All rights reserved.
//

import CoreData

/*
 NSManagedObjectContext 的一些扩展方法, 目的在于让调用更加的方便.
 */

extension NSManagedObjectContext {
    // 利用返回值的类型, 完成泛型类型的绑定工作. 这是 C++ 不能够做到的事情.
    func insertObject<A: NSManagedObject>() -> A where A: ManagedObject {
        guard let obj = NSEntityDescription.insertNewObject(forEntityName: A.entityName, into: self) as? A else { fatalError("Wrong object type") }
        return obj
    }

    func saveOrRollback() -> Bool {
        do {
            try save()
            return true
        } catch {
            rollback()
            return false
        }
    }

    // 先做某些操作, 然后执行保存操作. 良好的封装, 使得使用者使用起来没有生硬的感觉.
    func performChanges(block: @escaping () -> ()) {
        perform {
            block()
            _ = self.saveOrRollback()
        }
    }
}

