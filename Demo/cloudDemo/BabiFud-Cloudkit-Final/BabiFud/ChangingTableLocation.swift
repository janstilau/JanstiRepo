//
//  ChangingTableLocation.swift
//  BabiFud
//
//  Created by Darren Ferguson on 6/4/16.
//  Copyright © 2016 raywenderlich. All rights reserved.
//

import UIKit

struct ChangingTableLocation: OptionSet {

  // MARK: - Properties
  var rawValue: UInt = 0
  
  var boolValue: Bool {
    return rawValue != 0
  }

  // MARK: - Initializers
  init(rawValue: UInt) {
    self.rawValue = rawValue
  }

  init(nilLiteral: ()) {
    self.rawValue = 0
  }

  // MARK: - Methods
  func toRaw() -> UInt {
    return self.rawValue
  }

  func images() -> [UIImage] {
    var images: [UIImage] = []
    if intersection(.Mens).boolValue {
      images.append(UIImage(named: "man")!)
    }
    if intersection(.Womens).boolValue {
      images.append(UIImage(named: "woman")!)
    }
    
    return images
  }
}

// MARK: - Static
extension ChangingTableLocation {

  // MARK: - Properties
  static var allZeros: ChangingTableLocation {
    return self.init(rawValue: 0)
  }

  static var None: ChangingTableLocation {
    return self.init(rawValue: 0)
  }

  static var Mens: ChangingTableLocation {
    return self.init(rawValue: 1 << 0)
  }

  static var Womens: ChangingTableLocation {
    return self.init(rawValue: 1 << 1)
  }

  static var Family: ChangingTableLocation {
    return self.init(rawValue: 1 << 2)
  }

  // MARK: - Methods
  static func convertFromNilLiteral() -> ChangingTableLocation {
    return .None
  }

  static func fromRaw(_ raw: UInt) -> ChangingTableLocation? {
    return self.init(rawValue: raw)
  }

  static func fromMask(_ raw: UInt) -> ChangingTableLocation {
    return self.init(rawValue: raw)
  }
}

func == (lhs: ChangingTableLocation, rhs: ChangingTableLocation) -> Bool {
  return lhs.rawValue == rhs.rawValue
}

func | (lhs: ChangingTableLocation, rhs: ChangingTableLocation) -> ChangingTableLocation {
  return ChangingTableLocation(rawValue: lhs.rawValue | rhs.rawValue)
}

func & (lhs: ChangingTableLocation, rhs: ChangingTableLocation) -> ChangingTableLocation {
  return ChangingTableLocation(rawValue: lhs.rawValue & rhs.rawValue)
}

func ^ (lhs: ChangingTableLocation, rhs: ChangingTableLocation) -> ChangingTableLocation {
  return ChangingTableLocation(rawValue: lhs.rawValue ^ rhs.rawValue)
}
