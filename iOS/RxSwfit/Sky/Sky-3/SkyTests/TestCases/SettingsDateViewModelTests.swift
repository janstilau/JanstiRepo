//
//  SettingsDateViewModelTests.swift
//  SkyTests
//
//  Created by Mars on 11/02/2018.
//  Copyright © 2018 Mars. All rights reserved.
//

import XCTest
@testable import Sky

class SettingsDateViewModelTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
        
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.dateMode)
    }
    
    func test_date_display_in_text_mode() {
        let vm = SettingsDateViewModel(dateMode: .text)
        XCTAssertEqual(vm.labelText, "Fri, 01 December")
    }
    
    func test_date_display_in_digit_mode() {
        let vm = SettingsDateViewModel(dateMode: .digit)
        XCTAssertEqual(vm.labelText, "F, 12/01")
    }
    
    func test_text_date_mode_selected() {
        let dateMode: DateMode = .text
        
        UserDefaults.standard.set(dateMode.rawValue, forKey: UserDefaultsKeys.dateMode)
        let vm = SettingsDateViewModel(dateMode: dateMode)
        
        XCTAssertEqual(vm.accessory, UITableViewCellAccessoryType.checkmark)
    }
    
    func test_text_date_mode_unselected() {
        let dateMode: DateMode = .text
        
        UserDefaults.standard.set(dateMode.rawValue, forKey: UserDefaultsKeys.dateMode)
        let vm = SettingsDateViewModel(dateMode: .digit)
        
        XCTAssertEqual(vm.accessory, UITableViewCellAccessoryType.none)
    }
    
    func test_digit_date_mode_selected() {
        let dateMode: DateMode = .digit
        
        UserDefaults.standard.set(dateMode.rawValue, forKey: UserDefaultsKeys.dateMode)
        let vm = SettingsDateViewModel(dateMode: .digit)
        
        XCTAssertEqual(vm.accessory, UITableViewCellAccessoryType.checkmark)
    }
    
    func testdigit_date_model_unselected() {
        let dateMode: DateMode = .digit
        
        UserDefaults.standard.set(dateMode.rawValue, forKey: UserDefaultsKeys.dateMode)
        let vm = SettingsDateViewModel(dateMode: .text)
        
        XCTAssertEqual(vm.accessory, UITableViewCellAccessoryType.none)
    }
}
