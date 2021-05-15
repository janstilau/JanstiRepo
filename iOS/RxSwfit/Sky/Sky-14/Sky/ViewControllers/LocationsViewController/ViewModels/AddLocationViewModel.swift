//
//  AddLocationViewModel.swift
//  Sky
//
//  Created by Mars on 17/02/2018.
//  Copyright © 2018 Mars. All rights reserved.
//

import Foundation
import CoreLocation


// 没有使用 RXSwfit 的 ViewModel.
// 使用了存储闭包的形式, 通知外界, 数据修改了, 需要更新.
class AddLocationViewModel {
    
    var queryText: String = "" {
        didSet {
            geocode(address: queryText)
        }
    }
    
    private func geocode(address: String?) {
        guard let address = address, !address.isEmpty else {
            locations = []
            return
        }
        
        isQuerying = true
        
        geocoder.geocodeAddressString(address) {
            [weak self] (placemarks, error) in
            self?.processResponse(with: placemarks, error: error)
        }
    }
    
    private func processResponse(with placemarks: [CLPlacemark]?, error: Error?) {
        isQuerying = false
        var locs: [Location] = []
        
        if let error = error {
            print("Cannot handle Geocode Address! \(error)")
        }
        else if let placemarks = placemarks {
            locs = placemarks.compactMap {
                guard let name = $0.name else { return nil }
                guard let location = $0.location else { return nil }
                
                return Location(name: name,
                                latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude)
            }
            
            self.locations = locs
        }
    }
    
    private var isQuerying = false {
        didSet {
            queryingStatusDidChange?(isQuerying)
        }
    }
    
    private var locations: [Location] = [] {
        didSet {
            locationsDidChange?(locations)
        }
    }
    
    private lazy var geocoder = CLGeocoder()
    
    var queryingStatusDidChange: ((Bool) -> Void)?
    var locationsDidChange: (([Location]) -> Void)?
    
    var numberOfLocations: Int { return locations.count }
    var hasLocationsResult: Bool {
        return numberOfLocations > 0
    }
    
    func location(at index: Int) -> Location? {
        guard index < numberOfLocations else {
            return nil
        }
        
        return locations[index]
    }
    
    func locationViewModel(at index: Int) -> LocationRepresentable? {
        guard let location = location(at: index) else {
            return nil
        }
        
        return LocationsViewModel(location: location.location, locationText: location.name)
    }
}
