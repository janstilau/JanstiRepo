//
//  MyTabBarController.swift
//  NewsDemo
//
//  Created by JustinLau on 2020/5/3.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import UIKit

class MyTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupViewControllers()
    }
    
    func setupViewControllers() {
        
    }
    
    func setupChildController(_ childVC: UIViewController,
                              title: String,
                              imageName: String,
                              selectedImageName: String) {
        childVC.tabBarItem.title = title
        childVC.tabBarItem.image = UIImage(named: imageName)
        childVC.tabBarItem.selectedImage = UIImage(named: selectedImageName)
        
        let navVC = MyNavigationController(rootViewController: childVC)
        self.addChild(childVC)
    }
    

}
