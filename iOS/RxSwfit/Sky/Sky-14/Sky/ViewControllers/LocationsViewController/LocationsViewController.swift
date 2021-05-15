//
//  LocationsViewController.swift
//  Sky
//
//  Created by Mars on 13/02/2018.
//  Copyright © 2018 Mars. All rights reserved.
//

import UIKit
import CoreLocation

protocol LocationsViewControllerDelegate {
    func controller(_ controller: LocationsViewController, didSelectLocation location: CLLocation)
}

class LocationsViewController: UITableViewController {
    private let segueAddLocationView = "SegueAddLocationView"
    
    var currentLocation: CLLocation?
    
    var delegate: LocationsViewControllerDelegate?
    
    var favourites = UserDefaults.loadLocations()
    
    private var hasFavourites: Bool {
        return favourites.count > 0
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else { return }
        
        switch identifier {
        case segueAddLocationView:
            let dest = segue.destination
            if let addLocationViewController = dest as? AddLocationViewController {
                // TODO: add delegate
                addLocationViewController.delegate = self
            }
            else {
                fatalError("Unexpected destination view controller.")
            }
        default:
            break
        }
    }
    
    @IBAction func unwindToLocationsViewController(segue: UIStoryboardSegue) {}
}

extension LocationsViewController {
    // 专门用一个 enum, 来表示 TableView 的不同的 Section 的内容.
    // 这比之前自己在业务类里面, 使用不同的 Int 做区分要好.
    // Enum 的 case, 自带表意字符串.
    private enum Section: Int {
        case current
        case favourite
        
        var title: String {
            switch self {
            case .current:
                return "Current Location"
            case .favourite:
                return "Favourite Locations"
            }
        }
        
        // 专门定义一个特殊的类型属性, 来返回 Section 的总数信息.
        static var count: Int {
            return Section.favourite.rawValue + 1
        }
    }
    
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return Section.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else {
            fatalError("Unexpected Section")
        }
        
        switch section {
        case .current:
            return 1
        case .favourite:
            return max(favourites.count, 1)
        }
    }
    
    // 具体的显示信息, 聚焦在一点. 让所有的和 Section 的概念, 都在 Section 的定义里面可以找到. 避免了之后修改, 要在不同的方法里面进行查找.
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else {
            fatalError("Unexpected Section")
        }
        
        return section.title
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            fatalError("Unexpected section")
        }
        
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: LocationTableViewCell.reuseIdentifier,
            for: indexPath) as? LocationTableViewCell else {
            fatalError("Unexpected table view cell")
        }

        var vm: LocationsViewModel?
        
        switch section {
        case .current:
            if let currentLocation = currentLocation {
                vm = LocationsViewModel(location: currentLocation, locationText: nil)
            }
            else {
                cell.label.text = "Current Location Unknown"
            }
        case .favourite:
            if favourites.count > 0 {
                let fav = favourites[indexPath.row]
                vm = LocationsViewModel(location: fav.location, locationText: fav.name)
            }
            else {
                cell.label.text = "No Favourites Yet..."
            }
        }
        
        if let vm = vm {
            cell.configure(with: vm)
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let section = Section(rawValue: indexPath.section) else { fatalError("Unexpected Section") }
        
        switch section {
        case .current: return false
        case .favourite: return hasFavourites
        }
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        let location = favourites[indexPath.row]
        UserDefaults.removeLocation(location)
        
        favourites.remove(at: indexPath.row)
        tableView.reloadData()
       
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else {
            fatalError("Unexpected Section")
        }
        
        var location: CLLocation?
        
        switch (section) {
        case .current:
            if let currentLocation = currentLocation {
                location = currentLocation
            }
        case .favourite:
            if hasFavourites {
                location = favourites[indexPath.row].location
            }
        }
        
        if location != nil {
            delegate?.controller(self, didSelectLocation: location!)
            dismiss(animated: true)
        }
    }
}

extension LocationsViewController: AddLocationViewControllerDelegate {
    
    func controller(_ controller: AddLocationViewController, didAddLocation location: Location) {
        // Update User Defaults
        UserDefaults.addLocation(location)
        
        // Update Locations
        favourites.append(location)
        
        // Update Table View
        tableView.reloadData()
    }
    
}

