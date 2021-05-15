//
//  WeekWeatherTableViewCell.swift
//  Sky
//
//  Created by Mars on 23/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import UIKit

class WeekWeatherTableViewCell: UITableViewCell {
    
    static let reuseIdentifier = "WeekWeatherCell"
    
    @IBOutlet weak var week: UILabel!
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var temperature: UILabel!
    @IBOutlet weak var weatherIcon: UIImageView!
    @IBOutlet weak var humidity: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    // cell, 是直接和一个 protocol 进行交互.
    func configure(with vm: WeekWeatherDayRepresentable) {
        week.text = vm.week
        date.text = vm.date
        humidity.text = vm.humidity
        temperature.text = vm.temperature
        weatherIcon.image = vm.weatherIcon
    }
}
