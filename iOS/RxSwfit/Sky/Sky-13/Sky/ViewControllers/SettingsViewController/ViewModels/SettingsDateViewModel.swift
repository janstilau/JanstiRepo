//
//  SettingsDateViewModel.swift
//  Sky
//
//  Created by Mars on 03/12/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import UIKit

struct SettingsDateViewModel: SettingsRepresentable {
    let dateMode: DateMode
    
    var labelText: String {
        return dateMode == .text ? "Fri, 01 December" : "F, 12/01"
    }
    
    var accessory: UITableViewCellAccessoryType {
        if UserDefaults.dateMode() == dateMode {
            return .checkmark
        }
        else {
            return .none
        }
    }
}
