//
//  WeekWeatherViewModel.swift
//  Sky
//
//  Created by Mars on 24/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import UIKit

struct WeekWeatherViewModel {
    
    let weatherData: [ForecastData]
    
    var numberOfSections: Int {
        return 1
    }
    
    var numberOfDays: Int {
        return weatherData.count
    }
    
    func viewModel(for index: Int) -> WeekWeatherDayViewModel {
        return WeekWeatherDayViewModel(weatherData: weatherData[index])
    }
}
