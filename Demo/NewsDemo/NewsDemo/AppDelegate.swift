//
//  AppDelegate.swift
//  NewsDemo
//
//  Created by JustinLau on 2020/5/3.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = MyTabBarController()
        window?.makeKeyAndVisible()
        return true
    }
    
}

