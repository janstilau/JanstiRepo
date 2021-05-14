//
//  CurrentWeatherViewController.swift
//  Sky
//
//  Created by Mars on 05/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import RxCocoa
import RxSwift
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
    
    var delegate: CurrentWeatherViewControllerDelegate?
    
    private var bag = DisposeBag()

    var weatherVM: BehaviorRelay<CurrentWeatherViewModel> = BehaviorRelay(value: CurrentWeatherViewModel.empty)
    var locationVM: BehaviorRelay<CurrentLocationViewModel> = BehaviorRelay(value: CurrentLocationViewModel.empty)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let viewModel = Observable.combineLatest(locationVM, weatherVM) {
                return ($0, $1)
            }
            .filter {
                let (location, weather) = $0
                return !(location.isEmpty) && !(weather.isEmpty)
            }
            .share(replay: 1, scope: .whileConnected)
            .observeOn(MainScheduler.instance)
        
        viewModel.map { _ in false }.bind(to: self.activityIndicatorView.rx.isAnimating).disposed(by: bag)
        viewModel.map { _ in false }.bind(to: self.weatherContainerView.rx.isHidden).disposed(by: bag)
        
        viewModel.map { $0.0.city }.bind(to: self.locationLabel.rx.text).disposed(by: bag)
        
        viewModel.map { $0.1.temperature }.bind(to: self.temperatureLabel.rx.text).disposed(by: bag)
        viewModel.map { $0.1.weatherIcon }.bind(to: self.weatherIcon.rx.image).disposed(by: bag)
        viewModel.map { $0.1.humidity }.bind(to: self.humidityLabel.rx.text).disposed(by: bag)
        viewModel.map { $0.1.summary }.bind(to: self.summaryLabel.rx.text).disposed(by: bag)
        viewModel.map { $0.1.date }.bind(to: self.dateLabel.rx.text).disposed(by: bag)
        
// ------------ DO NOT NEED THESE CODES ANYMORE --------------
//            .subscribe(onNext: {
//                let (location, weather) = $0
//                self.activityIndicatorView.stopAnimating()
//                self.weatherContainerView.isHidden = false
//
//                self.locationLabel.text = location.city
//
//                self.temperatureLabel.text = weather.temperature
//                self.weatherIcon.image = weather.weatherIcon
//                self.humidityLabel.text = weather.humidity
//                self.summaryLabel.text = weather.summary
//                self.dateLabel.text = weather.date
//            }).disposed(by: bag)
// ------------ DO NOT NEED THESE CODES ANYMORE --------------
    }
    
    func updateView() {
        weatherVM.accept(weatherVM.value)
        locationVM.accept(locationVM.value)
    }
    
    @IBAction func locationButtonPressed(_ sender: UIButton) {
        delegate?.locationButtonPressed(controller: self)
    }
    
    @IBAction func settingsButtonPressed(_ sender: UIButton) {
        delegate?.settingsButtonPressed(controlled: self)
    }
}

