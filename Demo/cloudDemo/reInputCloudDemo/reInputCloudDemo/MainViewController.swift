//
//  MainViewController.swift
//  reInputCloudDemo
//
//  Created by jansti on 16/11/24.
//  Copyright © 2016年 jansti. All rights reserved.
//

import UIKit

private let kShowDetailSegueId = "showDetailSegueId"

class MainViewController: BaseViewController{
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    
    fileprivate var cities = [City]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        reloadCities()
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == kShowDetailSegueId{
            let selectedIndexPath = tableView.indexPathForSelectedRow!
            
            
        }
        
    }
    
    
}


//MARK: - Actions
extension MainViewController{
    
    @IBAction func reloadCities() {
        shouldAnimateIndicator(true)
        CloudKitManager.checkLoginStatus { (isLogged) in
            self.shouldAnimateIndicator(false)
            if isLogged{
                self.updateData()
            } else {
                print("account unavailbale")
            }
        }
    }
    
}


// MARK: Private

fileprivate extension MainViewController{
    
    func setupViews(){
        self.privateMethod()// 这里可以调用privateMethod(),前面的privte???
        
        let cellNib = UINib.init(nibName: CityTableViewCell.nibName, bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: CityTableViewCell.reuseIdentifier)
        tableView.tableFooterView = UIView()
    }
    
    func shouldAnimateIndicator(_ animate: Bool){
        if animate {
            indicatorView.startAnimating()
        } else {
            indicatorView.stopAnimating()
        }
        
        tableView.isUserInteractionEnabled = !animate
        navigationController?.navigationBar.isUserInteractionEnabled = !animate
    }
    
    func addCity(_ city: City){
        cities.insert(city, at: 0)
        tableView.reloadData()
    }
    
    func removeCity(_ cityToRemove: City){
        cities = cities.filter({ (currentCity) -> Bool in
            return currentCity != cityToRemove
        })
        tableView.reloadData()
    }
    
    
    func updateData(){
        
        shouldAnimateIndicator(true)
        
        CloudKitManager.fetchAllCities { (records, error) in
            
            self.shouldAnimateIndicator(false)
            
            guard let cities = records else {
                self.presentMessage(error!.localizedDescription)
                return
            }
            
            guard !cities.isEmpty else {
                self.presentMessage("现在没有数据,手动添加一个吧")
                return
            }
            
            
            self.cities = cities
            self.tableView.reloadData()
        }
        
        
    }
    
    
}

extension MainViewController{
    
    
    
    
}



private extension MainViewController{
    
    func privateMethod(){
        
    }
    
}
