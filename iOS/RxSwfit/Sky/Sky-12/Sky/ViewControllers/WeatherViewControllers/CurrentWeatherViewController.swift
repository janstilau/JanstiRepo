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
            .asDriver(onErrorJustReturn: (CurrentLocationViewModel.empty, CurrentWeatherViewModel.empty))

        viewModel.map { _ in false }.drive(self.activityIndicatorView.rx.isAnimating).disposed(by: bag)
        viewModel.map { _ in false }.drive(self.weatherContainerView.rx.isHidden).disposed(by: bag)

        viewModel.map { $0.0.city }.drive(self.locationLabel.rx.text).disposed(by: bag)

        viewModel.map { $0.1.temperature }.drive(self.temperatureLabel.rx.text).disposed(by: bag)
        viewModel.map { $0.1.weatherIcon }.drive(self.weatherIcon.rx.image).disposed(by: bag)
        viewModel.map { $0.1.humidity }.drive(self.humidityLabel.rx.text).disposed(by: bag)
        viewModel.map { $0.1.summary }.drive(self.summaryLabel.rx.text).disposed(by: bag)
        viewModel.map { $0.1.date }.drive(self.dateLabel.rx.text).disposed(by: bag)        
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

