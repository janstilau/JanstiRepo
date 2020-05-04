//
//  ViewExtension.swift
//  NewsDemo
//
//  Created by JustinLau on 2020/5/4.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import UIKit

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
