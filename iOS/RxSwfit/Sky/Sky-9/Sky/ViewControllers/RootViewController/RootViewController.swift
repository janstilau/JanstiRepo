//
//  ViewController.swift
//  Sky
//
//  Created by Mars on 28/09/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit
import RxSwift
import RxCocoa

class RootViewController: UIViewController {
    private let segueCurrentWeather = "SegueCurrentWeather"
    private let segueWeekWeather = "SegueWeekWeather"
    private let segueSettings = "SegueSettings"
    private let segueLocations = "SegueLocations"
    private var bag = DisposeBag()
    
    var currentWeatherViewController: CurrentWeatherViewController!
    var weekWeatherViewController: WeekWeatherViewController!
    
    private var currentLocation: CLLocation? {
        didSet {
            fetchCity()
            fetchWeather()
        }
    }
    
    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        
        manager.distanceFilter = 1000
        manager.desiredAccuracy = 1000
        
        return manager
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupActiveNotification()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else { return }
        
        switch identifier {
        case segueCurrentWeather:
            guard let destination = segue.destination as? CurrentWeatherViewController else {
                fatalError("Invalid destination view controller!")
            }
            
            destination.delegate = self
            currentWeatherViewController = destination
            // ------------ DO NOT NEED THESE CODES ANYMORE --------------
            // destination.viewModel = Variable<CurrentWeatherViewModel>(CurrentWeatherViewModel())
            // ------------ DO NOT NEED THESE CODES ANYMORE --------------
            
        case segueWeekWeather:
            guard let destination = segue.destination as? WeekWeatherViewController else {
                fatalError("Invalid destination view controller!")
            }
            
            weekWeatherViewController = destination
        case segueSettings:
            guard let navigationController = segue.destination as? UINavigationController else {
                fatalError("Invalid destination view controller!")
            }
            
            guard let destination = navigationController.topViewController as? SettingsViewController else {
                fatalError("Invalid destination view controller!")
            }
            
            destination.delegate = self
        case segueLocations:
            guard let navigationController = segue.destination as? UINavigationController else {
                fatalError("Invalid destination view controller!")
            }
            
            guard let destination = navigationController.topViewController as? LocationsViewController else {
                fatalError("Invalid destination view controller!")
            }
            
            destination.delegate = self
            destination.currentLocation = currentLocation
        default:
            break
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func applicationDidBecomeActive(notification: Notification) {
        print("Sky becomes activate")
        requestLocation()
    }
    
    @IBAction func unwindToRootViewController(segue: UIStoryboardSegue) {
        
    }
    
    private func setupActiveNotification() {
        let selector = #selector(RootViewController.applicationDidBecomeActive(notification:))
        NotificationCenter.default.addObserver(
            self,
            selector: selector,
            name: Notification.Name.UIApplicationDidBecomeActive,
            object: nil)
    }
    
    private func requestLocation() {
        locationManager.delegate = self
        
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
        else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    private func fetchCity() {
        guard let currentLocation = currentLocation else { return }
        
        CLGeocoder().reverseGeocodeLocation(currentLocation) {
            placemarks, error in
            if let error = error {
                dump(error)
            } else if let city = placemarks?.first?.locality {
                let location = Location(
                    name: city,
                    latitude: currentLocation.coordinate.latitude,
                    longitude: currentLocation.coordinate.longitude)
                
                self.currentWeatherViewController.locationVM.accept(CurrentLocationViewModel(location: location))
                // ------------ DO NOT NEED THESE CODES ANYMORE --------------
                //self.currentWeatherViewController.viewModel.value.location = location
                // ------------ DO NOT NEED THESE CODES ANYMORE --------------
            }
        }
    }
    
    private func fetchWeather() {
        guard let currentLocation = currentLocation else { return }
        
        let lat = currentLocation.coordinate.latitude
        let lon = currentLocation.coordinate.longitude
        
        // 在使用的时候, 是直接在后面, 注册一下后续的流程.
        WeatherDataManager.shared.weatherDataAt(latitude: lat, longitude: lon)
            .subscribe(onNext: {
                self.currentWeatherViewController.weatherVM.accept(CurrentWeatherViewModel(weather: $0))
                self.weekWeatherViewController.viewModel = WeekWeatherViewModel(weatherData: $0.daily.data)
            })
            .disposed(by: bag)
// ------------ DO NOT NEED THESE CODES ANYMORE --------------
//            completion: { response, error in
//                if let error = error {
//                    dump(error)
//                }
//                else if let response = response {
//                    self.currentWeatherViewController.viewModel?.weather = response
//                    self.weekWeatherViewController.viewModel = WeekWeatherViewModel(weatherData: response.daily.data)
//                }
//            })
// ------------ DO NOT NEED THESE CODES ANYMORE --------------
    }
}

extension RootViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            currentLocation = location
            manager.delegate = nil
            
            manager.stopUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        dump(error)
    }
}

extension RootViewController: CurrentWeatherViewControllerDelegate {
    func locationButtonPressed(controller: CurrentWeatherViewController) {
        print("Open locations.")
        performSegue(withIdentifier: segueLocations, sender: self)
    }
    
    func settingsButtonPressed(controlled: CurrentWeatherViewController) {
        print("Open Settings")
        performSegue(withIdentifier: segueSettings, sender: self)
    }
}

extension RootViewController: SettingsViewControllerDelegate {
    private func reloadUI() {
        currentWeatherViewController.updateView()
        weekWeatherViewController.updateView()
    }
    
    func controllerDidChangeTimeMode(controller: SettingsViewController) {
        reloadUI()
    }
    
    func controllerDidChangeTemperatureMode(controller: SettingsViewController) {
        reloadUI()
    }
}

extension RootViewController: LocationsViewControllerDelegate {
    func controller(_ controller: LocationsViewController, didSelectLocation location: CLLocation) {
        currentLocation = location
    }
}

