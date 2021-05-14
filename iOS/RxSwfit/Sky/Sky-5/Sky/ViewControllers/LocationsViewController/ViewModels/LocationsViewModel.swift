//
//  LocationsViewModel.swift
//  Sky
//
//  Created by Mars on 13/02/2018.
//  Copyright © 2018 Mars. All rights reserved.
//

import UIKit
import CoreLocation

struct LocationsViewModel {
    let location: CLLocation?
    let locationText: String?
}

extension LocationsViewModel: LocationRepresentable {
    var labelText: String {
        if let locationText = locationText {
            return locationText
        }
        else if let location = location {
            return location.toString
        }
        
        return "Unknown position"
    }
}
