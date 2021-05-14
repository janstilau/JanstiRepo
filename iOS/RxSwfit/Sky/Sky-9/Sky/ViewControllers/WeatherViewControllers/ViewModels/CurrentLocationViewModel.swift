//
//  CurrentLocationViewModel.swift
//  Sky
//
//  Created by Mars on 22/02/2018.
//  Copyright © 2018 Mars. All rights reserved.
//

import Foundation

struct CurrentLocationViewModel {
    var location: Location
    static let empty = CurrentLocationViewModel(location: Location.empty)
    
    var city: String {
        return location.name
    }
    
    var isEmpty: Bool {
        return self.location == Location.empty
    }
}
