//
//  ScopeDemo.swift
//  reInputCloudDemo
//
//  Created by jansti on 16/11/24.
//  Copyright © 2016年 jansti. All rights reserved.
//

import UIKit


class Demo {
    
    static func method() {
        let vc = MainViewController()
        vc.viewDidLoad() // 这里viewdidload可以使用
//        vc.setupViews() // 这里,setupView不可以调用,因为extension 被filePrivate了.
//        vc.privateMethod() // 这里privateMethod也不能执行,private的权限比filePrivate还小
    }
    
    
}


