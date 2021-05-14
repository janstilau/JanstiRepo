//
//  WeekWeatherTableViewCell.swift
//  SkyDemo
//
//  Created by Mars on 26/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import UIKit

class WeekWeatherTableViewCell: UITableViewCell {
    
    static let reuseIdentifier = "WeekWeatherCell"
    
    @IBOutlet weak var week: UILabel!
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var temperature: UILabel!
    @IBOutlet weak var weatherIcon: UIImageView!
    @IBOutlet weak var humid: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    func configure(with vm: WeekWeatherDayRepresentable) {
        week.text = vm.week
        date.text = vm.date
        humid.text = vm.humidity
        temperature.text = vm.temperature
        weatherIcon.image = vm.weatherIcon
    }
}
