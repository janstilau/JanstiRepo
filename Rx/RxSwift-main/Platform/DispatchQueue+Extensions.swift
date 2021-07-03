//
//  DispatchQueue+Extensions.swift
//  Platform
//
//  Created by Krunoslav Zaher on 10/22/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import Dispatch

extension DispatchQueue {
    
    // 为 MainQueue 添加了特殊的 Key.  根据这个 Key 来判断是不是主线程.
    private static var token: DispatchSpecificKey<()> = {
        let key = DispatchSpecificKey<()>()
        DispatchQueue.main.setSpecific(key: key, value: ())
        return key
    }()

    static var isMain: Bool {
        DispatchQueue.getSpecific(key: token) != nil
    }
}
