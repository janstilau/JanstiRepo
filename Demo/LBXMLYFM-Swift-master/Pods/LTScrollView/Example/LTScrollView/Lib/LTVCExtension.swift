//
//  LTVCExtension.swift
//  LTScrollView
//
//  Created by 高刘通 on 2018/2/3.
//  Copyright © 2018年 LT. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
    
    /*
     Swift 版本的关联对象的实现方式. 这里, key 值被一个结构体进行管理了.
     之所以用结构体进行管理, 主要是为了
     1. 代码结构比较清晰. 所有的 key 值在一个统一的地方.
     1. private 定义在结构体上就可以了, 这样里面的各个 key 值不用专门用 private 来进行定义了.
     
     虽然我们知道, 结构体里面的静态变量其实就是一个全局变量. 但是, 这种写法显得更加的 clear code.
     */
    private struct LTVCKey {
        static var sKey = "glt_scrollViewKey"
        static var oKey = "glt_upOffsetKey"
    }
    
    @objc public var glt_scrollView: UIScrollView? {
        get { return objc_getAssociatedObject(self, &LTVCKey.sKey) as? UIScrollView }
        set { objc_setAssociatedObject(self, &LTVCKey.sKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public var glt_upOffset: String? {
        get { return objc_getAssociatedObject(self, &LTVCKey.oKey) as? String }
        set { objc_setAssociatedObject(self, &LTVCKey.oKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

