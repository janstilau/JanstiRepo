//
//  SettingsTableViewCell.swift
//  Sky
//
//  Created by Mars on 01/12/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import UIKit

class SettingsTableViewCell: UITableViewCell {

    static let reuseIdentifier = "SettingsTableViewCell"
    
    @IBOutlet var label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        selectionStyle = .none
    }
    
    /*
     实际上，这就是protocol在这种就用法里发挥的重要作用。如果，我们在SettingsTableViewCell中直接访问了SettingsDateViewModel或者SettingsTemperatureViewModel，显然我们就犯规了。
     但我们使用的是SettingRepresentable，其实，它只约束了一些接口。对于我们具体用哪些View Model实际提供了数据，View仍旧是一无所知的，因此也并没有打破MVVM设定的原则，并且通过这种做法，我们进一步从View Controller中抽离了一些UI相关的细节，让它只承担了连接的作用。而这，就是所谓面向protocol编程优雅和简洁的地方。
     */

    func configure(with vm: SettingsRepresentable) {
        label.text = vm.labelText
        accessoryType = vm.accessory
    }
}
