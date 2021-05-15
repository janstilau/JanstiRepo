//
//  SettingsViewController.swift
//  Sky
//
//  Created by Mars on 01/12/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import UIKit

protocol SettingsViewControllerDelegate {
    func controllerDidChangeTimeMode(controller: SettingsViewController)
    func controllerDidChangeTemperatureMode(controller: SettingsViewController)
}

class SettingsViewController: UITableViewController {

    var delegate: SettingsViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension SettingsViewController {
    // MARK: - Table view data source
    
    private enum Section: Int {
        case date
        case temperature
        
        var numberOfRows: Int {
            return 2
        }
        
        static var count: Int {
            return Section.temperature.rawValue + 1
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return Section.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        guard let section = Section(rawValue: section) else {
            fatalError("Unexpected section index")
        }
        
        return section.numberOfRows
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if (section == 0){
            return "Date format"
        }
        
        return "Temperature unit"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else {
                fatalError("Unexpected talbe view cell")
        }
        
        guard let section = Section(rawValue: indexPath.section) else {
            fatalError("Unexpected section index")
        }
        
        UIScrollViewDelegate
        
        // 个人感觉这层抽象没有什么意义.
        // 各个 Cell 的显示, 其实是不同的, 仅仅是在这个 App 里面, 可以找到统一的抽象而已.
        // 所以, 在不同的 IndexPath 里面, 取得不同种类的 Cell, 配置不同种类的 Model, 返回是合理的现象, 没有必要在这里进行协议的抽象.
        var vm: SettingsRepresentable?
        
        switch section {
        case .date:
            guard let dateMode = DateMode(rawValue: indexPath.row) else {
                fatalError("Invalid IndexPath")
            }
            
            vm = SettingsDateViewModel(dateMode: dateMode)
        case .temperature:
            guard let temperatureMode = TemperatureMode(rawValue: indexPath.row) else {
                fatalError("Invalid IndexPath")
            }
            
            vm = SettingsTemperatureViewModel(temperatureMode: temperatureMode)
        }
        
        if let vm = vm {
            // 让cell从view model进行自我设置
            cell.configure(with: vm)
        }
        
        return cell
    }
    
    // MARK: - Table View Delegate Methods
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let section = Section(rawValue: indexPath.section) else {
            fatalError("Unexpected section index")
        }
        
        switch section {
        case .date:
            let dateMode = UserDefaults.dateMode()
            guard indexPath.row != dateMode.rawValue else { return }
            
            if let newMode = DateMode(rawValue: indexPath.row) {
                UserDefaults.setDateMode(to: newMode)
            }
            
            delegate?.controllerDidChangeTimeMode(controller: self)
            
        case .temperature:
            let temperatureMode = UserDefaults.temperatureMode()
            guard indexPath.row != temperatureMode.rawValue else { return }
            
            if let newMode = TemperatureMode(rawValue: indexPath.row) {
                UserDefaults.setTemperatureMode(to: newMode)
            }
            
            delegate?.controllerDidChangeTemperatureMode(controller: self)
        }
        
        tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
    }
}
