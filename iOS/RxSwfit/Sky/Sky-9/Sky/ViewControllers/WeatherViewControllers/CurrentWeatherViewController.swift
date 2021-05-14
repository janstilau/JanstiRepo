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
// ------------ DO NOT NEED THESE CODES ANYMORE --------------
//    var viewModel: Variable<CurrentWeatherViewModel>!
//    {
//        didSet {
//            DispatchQueue.main.async { self.updateView() }
//        }
//    }
// ------------ DO NOT NEED THESE CODES ANYMORE --------------

    override func viewDidLoad() {
        super.viewDidLoad()

        Observable.combineLatest(locationVM, weatherVM) {
                return ($0, $1)
            }
            .filter {
                let (location, weather) = $0
                return !(location.isEmpty) && !(weather.isEmpty)
            }
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [unowned self] in
    		    let (location, weather) = $0

                self.activityIndicatorView.stopAnimating()
    		    self.weatherContainerView.isHidden = false

                self.locationLabel.text = location.city

    		    self.temperatureLabel.text = weather.temperature
    		    self.weatherIcon.image = weather.weatherIcon
    		    self.humidityLabel.text = weather.humidity
    		    self.summaryLabel.text = weather.summary
    		    self.dateLabel.text = weather.date
    		}).disposed(by: bag)
    }

// ------------ DO NOT NEED THESE CODES ANYMORE --------------
//    func updateWeatherContainer(with model: CurrentWeatherViewModel) {
//        weatherContainerView.isHidden = false
//        locationLabel.text = model.city
//
//        self.temperatureLabel.text = model.temperature
//        self.weatherIcon.image = model.weatherIcon
//        self.humidityLabel.text = model.humidity
//        self.summaryLabel.text = model.summary
//        self.dateLabel.text = model.date
//    }
// ------------ DO NOT NEED THESE CODES ANYMORE --------------

    func updateView() {
        weatherVM.accept(weatherVM.value)
        locationVM.accept(locationVM.value)
    }

// ------------ DO NOT NEED THESE CODES ANYMORE --------------
//    func updateView() {
//        activityIndicatorView.stopAnimating()
//
//        if let vm = viewModel, vm.isUpdateReady {
//            updateWeatherContainer(with: vm)
//        }
//        else {
//            loadingFailedLabel.isHidden = false
//            loadingFailedLabel.text =
//            "Load Location/Weather failed!"
//        }
//    }
// ------------ DO NOT NEED THESE CODES ANYMORE --------------

    @IBAction func locationButtonPressed(_ sender: UIButton) {
        delegate?.locationButtonPressed(controller: self)
    }

    @IBAction func settingsButtonPressed(_ sender: UIButton) {
        delegate?.settingsButtonPressed(controlled: self)
    }
}

