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

class CurrentWeatherViewController: WeatherViewController {
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var weatherIcon: UIImageView!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var summaryLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    var viewModel: CurrentWeatherViewModel? {
        didSet {
            DispatchQueue.main.async { self.updateView() }
        }
    }
    
    var delegate: CurrentWeatherViewControllerDelegate?
    
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
