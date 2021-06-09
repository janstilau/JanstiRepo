//
//  SettingsTemperatureViewModel.swift
//  Sky
//
//  Created by Mars on 03/12/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import UIKit

struct SettingsTemperatureViewModel: SettingsRepresentable {
    let temperatureMode: TemperatureMode
    
    var labelText: String {
        return temperatureMode == .celsius ? "Celsius" : "Fahrenheit"
    }
    
    var accessory: UITableViewCellAccessoryType {
        if UserDefaults.temperatureMode() == temperatureMode {
            return .checkmark
        }
        else {
            return .none
        }
    }
}
