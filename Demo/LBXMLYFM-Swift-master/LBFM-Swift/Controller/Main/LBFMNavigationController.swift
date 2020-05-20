//
//  LBFMNavigationController.swift
//  LBFM-Swift
//
//  Created by liubo on 2019/2/1.
//  Copyright © 2019 刘博. All rights reserved.
//

import UIKit


class LBFMNavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavBarAppearence()
    }
    
    func setupNavBarAppearence() {
        WRNavigationBar.defaultNavBarBarTintColor = UIColor.init(red: 245/255.0, green: 245/255.0, blue: 245/255.0, alpha: 1)
        WRNavigationBar.defaultNavBarTintColor = LBFMButtonColor
        WRNavigationBar.defaultNavBarTitleColor = UIColor.black
        WRNavigationBar.defaultShadowImageHidden = true
    }

}

/*
 这个写到分类里面的意义???
 */
extension LBFMNavigationController{
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if children.count > 0 {
            viewController.hidesBottomBarWhenPushed = true
        }
        super.pushViewController(viewController, animated: animated)
    }
}
