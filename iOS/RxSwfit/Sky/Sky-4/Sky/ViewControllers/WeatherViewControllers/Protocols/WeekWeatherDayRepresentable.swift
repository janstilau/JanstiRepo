//
//  WeekWeatherDayRepresentable.swift
//  Sky
//
//  Created by Mars on 04/12/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import UIKit

protocol WeekWeatherDayRepresentable {
    var week: String { get }
    var date: String { get }
    var temperature: String { get }
    var weatherIcon: UIImage? { get }
    var humidity: String { get }
}
