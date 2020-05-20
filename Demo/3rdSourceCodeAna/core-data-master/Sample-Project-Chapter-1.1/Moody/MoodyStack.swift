//
//  MoodyStack.swift
//  Moody
//
//  Created by Florian on 18/08/15.
//  Copyright © 2015 objc.io. All rights reserved.
//

import CoreData


// 这是一个全局函数, 在这里创建, 然后调用回调.
func createMoodyContainer(completion: @escaping (NSPersistentContainer) -> ()) {
    let container = NSPersistentContainer(name: "Moody")
    container.loadPersistentStores { _, error in
        guard error == nil else { fatalError("Failed to load store: \(error!)") }
        DispatchQueue.main.async { completion(container) }
    }
}

func createMoodyContain(completion: @escaping (NSPersistentContainer) -> Void) {
    let container = NSPersistentContainer(name: "Moody")
    container.loadPersistentStores { (_, error) in
        guard error == nil else {
            fatalError("Fail to load the store, \(error!)")
        }
        DispatchQueue.main.async {
            completion(container) // 这里, completion 因为不是一个 Optional 值, 所以不用判断空状态.
        }
    }
}
