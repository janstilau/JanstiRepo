//
//  AppDelegate.swift
//  LBFM-Swift
//
//  Created by liubo on 2019/1/31.
//  Copyright © 2019 刘博. All rights reserved.
//

import UIKit
import ESTabBarController_swift
import SwiftMessages

@UIApplicationMain

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    /*
     UIApplication.LaunchOptionsKey 是 UIApplication 的内部类型,
     
     public protocol RawRepresentable {
         associatedtype RawValue
         public init?(rawValue: Self.RawValue)
         public var rawValue: Self.RawValue { get }
     }
     标识这个类型, 可以通过一个值, 创建该值, 并且可以获取该值.
     */
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        /*
         很少使用 self. 直接调用.
         因为大部分情况下, 其实类里面调用的函数就是自身的函数.
         全局函数, 相对来说还是要少很多的.
         */
        setupRootViewController()
        
        /*
         作为类型相关的常量, 用类的静态属性, 达到统一管理的目的.
         */
        window?.backgroundColor = UIColor.white
        window?.makeKeyAndVisible()
        
        return true
    }
    
    func setupRootViewController() {
        let rootVC = ESTabBarController()
        rootVC.title = "Irregularity"
        rootVC.tabBar.shadowImage = UIImage(named: "transparent")
        setupClickHandler(rootVC)
        setupViewControllers(rootVC)
        window?.rootViewController = rootVC
    }

    func setupClickHandler(_ rootVC:ESTabBarController) {
        rootVC.shouldHijackHandler = {
            tabbarController, viewController, index in
            if index == 2 {
                return true
            }
            return false
        }
        rootVC.didHijackHandler = {
            tabbarController, viewController, index in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let warning = MessageView.viewFromNib(layout: .cardView)
                warning.configureTheme(.warning)
                warning.configureDropShadow()
                let iconText = ["🤔", "😳", "🙄", "😶"].sm_random()!
                warning.configureContent(title: "Warning", body: "暂时没有此功能", iconText: iconText)
                warning.button?.isHidden = true
                var warningConfig = SwiftMessages.defaultConfig
                warningConfig.presentationContext = .window(windowLevel: UIWindow.Level.statusBar)
                SwiftMessages.show(config: warningConfig, view: warning)
            }
        }
    }
    
    func setupViewControllers(_ rootVC:ESTabBarController) {
        let home = LBFMHomeController()
        home.title = "首页"
        home.tabBarItem = ESTabBarItem.init(LBFMIrregularityBasicContentView(), title: "首页", image: UIImage(named: "home"), selectedImage: UIImage(named: "home_1"))
        
        let listen = LBFMListenController()
        listen.title = "我听"
        listen.tabBarItem = ESTabBarItem.init(LBFMIrregularityBasicContentView(), title: "我听", image: UIImage(named: "find"), selectedImage: UIImage(named: "find_1"))
        
        let play = LBFMPlayController()
        play.title = "播放"
        play.tabBarItem = ESTabBarItem.init(LBFMIrregularityContentView(), title: nil, image: UIImage(named: "tab_play"), selectedImage: UIImage(named: "tab_play"))
        
        let find = LBFMFindController()
        find.title = "发现"
        find.tabBarItem = ESTabBarItem.init(LBFMIrregularityBasicContentView(), title: "发现", image: UIImage(named: "favor"), selectedImage: UIImage(named: "favor_1"))
        
        let mine = LBFMMineController()
        mine.title = "我的"
        mine.tabBarItem = ESTabBarItem.init(LBFMIrregularityBasicContentView(), title: "我的", image: UIImage(named: "me"), selectedImage: UIImage(named: "me_1"))
        
        rootVC.viewControllers = [
            LBFMNavigationController.init(rootViewController: home),
            LBFMNavigationController.init(rootViewController: listen),
            LBFMNavigationController.init(rootViewController: find),
            LBFMNavigationController.init(rootViewController: mine),
            LBFMNavigationController.init(rootViewController: play),
        ]
    }
    

}

