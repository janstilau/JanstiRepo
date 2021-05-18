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
         这里的实现, 其实是利用的 NSDict 的这种可扩展容器的特性.
         Thread 存值, 是用到了系统级别的 setSpecific 方法. Thread 仅仅存储的是这个可扩展容器的一个指针. 
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
