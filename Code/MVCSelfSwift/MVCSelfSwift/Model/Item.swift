//
//  Item.swift
//  MVCSelfSwift
//
//  Created by JustinLau on 2019/8/22.
//  Copyright © 2019 JustinLau. All rights reserved.
//

import UIKit

class Item {
    
    let uuid: UUID
    private(set) var name: String
    weak var parent: Folder?
    
    init(name: String, uuid: UUID) {
        self.name = name
        self.uuid = uuid
    }
    
    func setName(_ newName: String) {
        self.name = newName
        if let parent = parent {
            
        }
    }
    
    func delete() {
        parent = nil
    }
    
    var uuidPath: [UUID] {
        var result = parent?.uuidPath ?? []
        result.append(uuid)
        return result
    }
    
}

extension Item {
    static let changeReasonKey = "reason"
    static let newValueKey = "newValue"
    static let oldValueKey = "oldValue"
    static let parentFolderKey = "parentFolder"
    static let renamed = "renamed"
    static let added = "added"
    static let removed = "removed"
}
