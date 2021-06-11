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
    
    var city: String {
        return location.name
    }
    
    static let empty = CurrentLocationViewModel(location: .empty)
    
    var isEmpty: Bool {
        return self.location == Location.empty
    }
    
    static let invalid = CurrentLocationViewModel(location: .invalid)
    
    var isInvalid: Bool {
        return self.location == Location.invalid
    }
}
