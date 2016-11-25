//
//  SeatingType.swift
//  BabiFud
//
//  Created by Darren Ferguson on 6/4/16.
//  Copyright © 2016 raywenderlich. All rights reserved.
//

import UIKit

struct SeatingType: OptionSet {

  // MARK: - Properties
  var rawValue: UInt = 0

  var boolValue: Bool {
    return self.rawValue != 0
  }

  // MARK: - Initializer
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

    if intersection(.Booster).boolValue {
      images.append(UIImage(named: "booster")!)
    }

    if intersection(.HighChair).boolValue {
      images.append(UIImage(named: "highchair")!)
    }

    return images
  }
}

// MARK: - Static
extension SeatingType {

  // MARK: - Properties
  static var allZeros: SeatingType {
    return self.init(rawValue: 0)
  }

  static var None: SeatingType {
    return self.init(rawValue: 0)
  }

  static var Booster: SeatingType {
    return self.init(rawValue: 1 << 0)
  }

  static var HighChair: SeatingType {
    return self.init(rawValue: 1 << 1)
  }

  // MARK: - Methods
  static func convertFromNilLiteral() -> SeatingType {
    return .None
  }

  static func fromRaw(_ raw: UInt) -> SeatingType? {
    return self.init(rawValue: raw)
  }

  static func fromMask(_ raw: UInt) -> SeatingType {
    return self.init(rawValue: raw)
  }
}

func == (lhs: SeatingType, rhs: SeatingType) -> Bool {
  return lhs.rawValue == rhs.rawValue
}

func | (lhs: SeatingType, rhs: SeatingType) -> SeatingType {
  return SeatingType(rawValue: lhs.rawValue | rhs.rawValue)
}

func & (lhs: SeatingType, rhs: SeatingType) -> SeatingType {
  return SeatingType(rawValue: lhs.rawValue & rhs.rawValue)
}

func ^ (lhs: SeatingType, rhs: SeatingType) -> SeatingType {
  return SeatingType(rawValue: lhs.rawValue ^ rhs.rawValue)
}
