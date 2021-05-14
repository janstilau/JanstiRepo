//
//  CurrentWeatherViewController.swift
//  Sky
//
//  Created by Mars on 05/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import UIKit

protocol CurrentWeatherViewControllerDelegate {
    func locationButtonPressed(controller: CurrentWeatherViewController)
    func settingsButtonPressed(controlled: CurrentWeatherViewController)
}

// 这个类, 是 WeatherViewController 的子类.
// 没有必要. 为了复用这样就引入了父子关系了.
class CurrentWeatherViewController: WeatherViewController {
    
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var weatherIcon: UIImageView!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var summaryLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    // 当 ViewModel 变化的时候, 触发了整体的 UI 更新的方法.
    var viewModel: CurrentWeatherViewModel? {
        didSet {
            DispatchQueue.main.async { self.updateView() }
        }
    }
    
    var delegate: CurrentWeatherViewControllerDelegate?
    
    // 一个专门的 Update 统一的方法, 在这里面, 做所有的 View 的更新的工作.
    func updateView() {
        activityIndicatorView.stopAnimating()
        
        if let vm = viewModel, vm.isUpdateReady {
            updateWeatherContainer(with: vm)
        }
        else {
            loadingFailedLabel.isHidden = false
            loadingFailedLabel.text =
                "Load Location/Weather failed!"
        }
    }
    
    // 在 ViewModel 里面, 暴露所有的 UI 层需要的东西.
    // View Model 里面, 属性是和 UI 绑定在一起的. ViewModel 在这里, 没有使用响应式编程, 仅仅是提供了, 从 Model 到 View 的转化的工作.
    func updateWeatherContainer(with model: CurrentWeatherViewModel) {
        weatherContainerView.isHidden = false
        
        locationLabel.text = model.city
        temperatureLabel.text = model.temperature
        weatherIcon.image = model.weatherIcon
        humidityLabel.text = model.humidity
        summaryLabel.text = model.summary
        dateLabel.text = model.date
    }
    
    @IBAction func locationButtonPressed(_ sender: UIButton) {
        delegate?.locationButtonPressed(controller: self)
    }
    
    @IBAction func settingsButtonPressed(_ sender: UIButton) {
        delegate?.settingsButtonPressed(controlled: self)
    }
}
