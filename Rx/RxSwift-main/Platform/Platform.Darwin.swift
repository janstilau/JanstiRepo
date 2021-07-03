//
//  Platform.Darwin.swift
//  Platform
//
//  Created by Krunoslav Zaher on 12/29/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

    import Darwin
    import Foundation

    extension Thread {
        /*
         threadDictionary 本身是系统就提供的方法
         在 GnuFoundation 的实现里面, 还是利用的 getSepecific, setSepecific 这两个 API
         */
        static func setThreadLocalStorageValue<T: AnyObject>(_ value: T?, forKey key: NSCopying) {
            let currentThread = Thread.current
            let threadDictionary = currentThread.threadDictionary
            if let newValue = value {
                threadDictionary[key] = newValue
            } else {
                threadDictionary[key] = nil
            }
        }

        static func getThreadLocalStorageValueForKey<T>(_ key: NSCopying) -> T? {
            let currentThread = Thread.current
            let threadDictionary = currentThread.threadDictionary
            return threadDictionary[key] as? T
        }
    }

#endif
