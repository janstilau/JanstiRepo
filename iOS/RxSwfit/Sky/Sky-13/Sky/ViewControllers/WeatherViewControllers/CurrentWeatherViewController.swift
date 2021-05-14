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
    @IBOutlet weak var retryBtn: UIButton!
    
    var delegate: CurrentWeatherViewControllerDelegate?
    
    private var bag = DisposeBag()

    var weatherVM: BehaviorRelay<CurrentWeatherViewModel> = BehaviorRelay(value: .empty)
    var locationVM: BehaviorRelay<CurrentLocationViewModel> = BehaviorRelay(value: .empty)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        Observable.just(11).materialize().do(onNext: { print("Materialize: \($0)") }).dematerialize().subscribe(onNext: { print("Subscribe: \($0)") })

        let combined = Observable.combineLatest(locationVM, weatherVM) { ($0, $1) }
            .share(replay: 1, scope: .whileConnected)
        
//        let viewModel = combined.filter { !$0.0.isEmpty && !$0.1.isEmpty && !$0.0.isInvalid && !$0.1.isInvalid }
        let viewModel = combined.filter { self.shouldDisplayWeatherContainer(locationVM: $0.0, weatherVM: $0.1) }
            .asDriver(onErrorJustReturn: (.empty, .empty))
        
        viewModel.map { $0.1.temperature }.drive(self.temperatureLabel.rx.text).disposed(by: bag)
        viewModel.map { $0.1.weatherIcon }.drive(self.weatherIcon.rx.image).disposed(by: bag)
        viewModel.map { $0.1.humidity }.drive(self.humidityLabel.rx.text).disposed(by: bag)
        viewModel.map { $0.1.summary }.drive(self.summaryLabel.rx.text).disposed(by: bag)
        viewModel.map { $0.0.city }.drive(self.locationLabel.rx.text).disposed(by: bag)
        viewModel.map { $0.1.date }.drive(self.dateLabel.rx.text).disposed(by: bag)
        
//        combined.map { return $0.0.isEmpty || $0.1.isEmpty || $0.0.isInvalid || $0.1.isInvalid }
        combined.map { self.shouldHideWeatherContainer(locationVM: $0.0, weatherVM: $0.1) }
            .asDriver(onErrorJustReturn: true)
            .drive(self.weatherContainerView.rx.isHidden)
            .disposed(by: bag)
        
//        combined.map { (!$0.0.isEmpty && !$0.1.isEmpty) || ($0.0.isInvalid || $0.1.isInvalid) }
        combined.map { self.shouldHideActivityIndicator(locationVM: $0.0, weatherVM: $0.1) }
            .asDriver(onErrorJustReturn: false)
            .drive(self.activityIndicatorView.rx.isHidden)
            .disposed(by: bag)
        
//        combined.map { $0.0.isEmpty || $0.1.isEmpty }
        combined.map { self.shouldAnimateActivityIndicator(locationVM: $0.0, weatherVM: $0.1) }
            .asDriver(onErrorJustReturn: true)
            .drive(self.activityIndicatorView.rx.isAnimating)
            .disposed(by: bag)
        
        let errorCond = combined.map { self.shouldDisplayErrorPrompt(locationVM: $0.0, weatherVM: $0.1) }
            .asDriver(onErrorJustReturn: true)
        
        errorCond.map { !$0 }.drive(self.retryBtn.rx.isHidden).disposed(by: bag)
        errorCond.map { !$0 }.drive(self.loadingFailedLabel.rx.isHidden).disposed(by: bag)
        errorCond.map { _ in return String.ok }.drive(self.loadingFailedLabel.rx.text).disposed(by: bag)
        
        self.retryBtn.rx.tap.subscribe(onNext: { _ in
            self.weatherVM.accept(.empty)
            self.locationVM.accept(.empty)
            
            (self.parent as? RootViewController)?.fetchCity()
            (self.parent as? RootViewController)?.fetchWeather()
        }).disposed(by: bag)
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

fileprivate extension String {
    static let ok = NSLocalizedString("Whoops! Something is wrong...", comment: "")
}

fileprivate extension CurrentWeatherViewController {
    func shouldHideWeatherContainer(
        locationVM: CurrentLocationViewModel,
        weatherVM: CurrentWeatherViewModel) -> Bool {
        return locationVM.isEmpty || locationVM.isInvalid ||
            weatherVM.isEmpty || weatherVM.isInvalid
    }
    
    func shouldHideActivityIndicator(
        locationVM: CurrentLocationViewModel,
        weatherVM: CurrentWeatherViewModel) -> Bool {
        return (!locationVM.isEmpty && !weatherVM.isEmpty) ||
            locationVM.isInvalid || weatherVM.isInvalid
    }
    
    func shouldAnimateActivityIndicator(
        locationVM: CurrentLocationViewModel,
        weatherVM: CurrentWeatherViewModel) -> Bool {
        return locationVM.isEmpty || weatherVM.isEmpty
    }
    
    func shouldDisplayErrorPrompt(
        locationVM: CurrentLocationViewModel,
        weatherVM: CurrentWeatherViewModel) -> Bool {
        return locationVM.isInvalid || weatherVM.isInvalid
    }
    
    func shouldDisplayWeatherContainer(
        locationVM: CurrentLocationViewModel,
        weatherVM: CurrentWeatherViewModel) -> Bool {
        return !locationVM.isEmpty && !locationVM.isInvalid &&
            !weatherVM.isEmpty && !weatherVM.isInvalid
    }
}

