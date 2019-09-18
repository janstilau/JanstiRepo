//
//  Store.swift
//  MVCSelfSwift
//
//  Created by JustinLau on 2019/8/22.
//  Copyright © 2019 JustinLau. All rights reserved.
//

import Foundation

final class Store {
    static let changedNotification = Notification.Name("StoreChanged")
    static let shared = Store()
    
    let storeLocationName = "store.json"
    let baseURL: URL?
    private(set) var rootFolder: Folder
    
    private init() {
        let documentDir = try? FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        self.baseURL = documentDir
        
        if  let url = documentDir,
            let data = try? Data(contentsOf: url.appendingPathComponent(storeLocationName)),
            let folder = try? JSONDecoder().decode(Folder.self, from: data) {
            self.rootFolder = folder
        }
    }
    
    func save() {
        
    }
}
