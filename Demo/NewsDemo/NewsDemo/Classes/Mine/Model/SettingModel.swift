//
//  SettingModel.swift
//  NewsDemo
//
//  Created by JustinLau on 2020/5/4.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation
import HandyJSON

struct SettingModel: HandyJSON {
    
    var title: String = ""
    var subtitle: String = ""
    var rightTitle: String = ""
    var isHiddenSubtitle: Bool = false
    var isHiddenRightTitle: Bool = false
    var isHiddenSwitch: Bool = false
    var isHiddenRightArraw: Bool = false
    
    
}
