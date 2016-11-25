//
//  SelectCityViewController.swift
//  reInputCloudDemo
//
//  Created by jansti on 16/11/25.
//  Copyright © 2016年 jansti. All rights reserved.
//

import UIKit


private let kCellReuseId = "selectCityReuseId"
private let kUnwindSelectCitySegue = "unwindSelectCityToMainId"

class SelectCityViewController: BaseViewController {
    
    var selectedCity: City!
    fileprivate var selectedIndexPath: IndexPath?
    
    @IBOutlet fileprivate var tableView: UITableView!
    @IBOutlet fileprivate var indicatorView: UIActivityIndicatorView!
    
    @IBAction func save(_ sender: Any) {
        
        if let selectedIndexPath = tableView.indexPathsForSelectedRows?.last {
            let cityData = City.cities[selectedIndexPath.row]
            shouldAnimateIndicator(true)
            
            CloudKitManager.createRecord(cityData) { record, error in
                self.shouldAnimateIndicator(false)
                
                if let record = record {
                    self.selectedCity = City(record: record)
                    self.performSegue(withIdentifier: kUnwindSelectCitySegue, sender: self)
                } else if let error = error {
                    self.presentMessage(error.localizedDescription)
                }
            }
        }
    }
    // MARK: IBActions
    @IBAction  func saveButtonDidPresses(_ button:UIButton) {
        
    }
    
    // MARK: Private
    fileprivate func shouldAnimateIndicator(_ animate: Bool) {
        if animate {
            indicatorView.startAnimating()
        } else {
            indicatorView.stopAnimating()
        }
        
        tableView.isUserInteractionEnabled = !animate
        navigationController!.navigationBar.isUserInteractionEnabled = !animate
    }
}

// MARK: UITableViewDataSource
extension SelectCityViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return City.cities.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kCellReuseId, for: indexPath)
        
        let cityName = City.cities[indexPath.row]["name"]
        cell.textLabel?.text = cityName
        cell.accessoryType = indexPath == selectedIndexPath ? .checkmark : .none
        
        return cell
    }
}

// MARK: UITableViewDelegate
extension SelectCityViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        
        cell?.accessoryType = .checkmark
        selectedIndexPath = indexPath
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        
        cell?.accessoryType = .none
        selectedIndexPath = nil
    }
}
