//
//  ViewExtension.swift
//  NewsDemo
//
//  Created by JustinLau on 2020/5/4.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import UIKit

// 这个协议, 解决了之前自己感觉到的一个问题, 命名都是从 XIB 里面加载, 为什么每一次都要进行不同的函数调用呢.
// 将从 XIB 里面加载的这个功能抽取出来, 放到一个协议里面, 然后所有能够从 XIB 里面加载的类, 只要实现这个协议, 然后调用同样的一个方法就可以了.

protocol NibLoadable {}

extension NibLoadable {
    static func loadViewFromNib() -> Self {
        return Bundle.main.loadNibNamed("\(self)", owner: nil, options: nil)?.last as! Self
    }
}

protocol RegisterCellOrNib {}

extension RegisterCellOrNib {
    
    static var identifier: String {
        return "\(self)"
    }
    
    static var nib: UINib? {
        return UINib(nibName: "\(self)", bundle: nil)
    }
}

extension UIView {
    
    func addBorderLine() {
        self.layer.borderColor = UIColor.randomColor().cgColor
        self.layer.borderWidth = 1.5
    }
    
    func addTip(_ tip: String) {
        let tipTag = 87903
        var tipLabel = self.viewWithTag(tipTag)
        if let tipLabel = tipLabel as? UILabel{
            tipLabel.text = tip
        } else {
            let createdLabel = UILabel()
            createdLabel.font = UIFont.systemFont(ofSize: 11)
            createdLabel.textColor = UIColor.randomColor()
            createdLabel.text = tip;
            createdLabel.tag = tipTag
            self.addSubview(createdLabel)
            tipLabel = createdLabel
        }
        tipLabel?.sizeToFit()
        tipLabel?.center = CGPoint(x: 0, y: self.frame.height * 0.5)
    }
}

/*
 还是原来的问题, Frame 是一个返回值, 而改变返回值, 是没有办法影响到真正的 Frame 的. 对于这种返回值类型的数据来说, 每次其实都要整体替换值类型数据才行.
 */
extension UIView {
    
    /// x
    var x: CGFloat {
        get {
            return frame.origin.x
        }
        set(newValue) {
            var tempFrame: CGRect = frame
            tempFrame.origin.x    = newValue
            frame                 = tempFrame
        }
    }
    
    /// y
    var y: CGFloat {
        get {
            return frame.origin.y
        }
        set(newValue) {
            var tempFrame: CGRect = frame
            tempFrame.origin.y    = newValue
            frame                 = tempFrame
        }
    }
    
    /// height
    var height: CGFloat {
        get {
            return frame.size.height
        }
        set(newValue) {
            var tempFrame: CGRect = frame
            tempFrame.size.height = newValue
            frame                 = tempFrame
        }
    }
    
    /// width
    var width: CGFloat {
        get {
            return frame.size.width
        }
        set(newValue) {
            var tempFrame: CGRect = frame
            tempFrame.size.width = newValue
            frame = tempFrame
        }
    }
    
    /// size
    var size: CGSize {
        get {
            return frame.size
        }
        set(newValue) {
            var tempFrame: CGRect = frame
            tempFrame.size = newValue
            frame = tempFrame
        }
    }
    
    /// centerX
    var centerX: CGFloat {
        get {
            return center.x
        }
        set(newValue) {
            var tempCenter: CGPoint = center
            tempCenter.x = newValue
            center = tempCenter
        }
    }
    
    /// centerY
    var centerY: CGFloat {
        get {
            return center.y
        }
        set(newValue) {
            var tempCenter: CGPoint = center
            tempCenter.y = newValue
            center = tempCenter;
        }
    }
}

