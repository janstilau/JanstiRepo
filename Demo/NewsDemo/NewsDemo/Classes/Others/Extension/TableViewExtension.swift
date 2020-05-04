//
//  TableViewExtension.swift
//  NewsDemo
//
//  Created by JustinLau on 2020/5/4.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import UIKit

extension UITableView {
    func disableEstimateHeight() {
        self.estimatedSectionHeaderHeight = 0
        self.estimatedSectionFooterHeight = 0
        self.estimatedRowHeight = 0
    }
    
    func disableAdjustBehavior() {
        if #available(iOS 13.0, *) {
            self.automaticallyAdjustsScrollIndicatorInsets = false
        } else {
            if #available(iOS 11.0, *) {
                self.contentInsetAdjustmentBehavior = UIScrollView.ContentInsetAdjustmentBehavior.never
            }
        }
    }
}
