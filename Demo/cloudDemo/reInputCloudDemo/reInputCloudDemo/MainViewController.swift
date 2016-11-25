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
            let detailedVC = segue.destination as! DetailedViewController
            detailedVC.city = cities[selectedIndexPath.row]
        }
    }
    
    
}


//MARK: - Actions
extension MainViewController{
    
    
    @IBAction func unwindToMainViewController(_ segue: UIStoryboardSegue){
        if let source = segue.source as? SelectCityViewController{
            addCity(source.selectedCity)
        }else if let source = segue.source as? DetailedViewController{
            removeCity(source.city)
        }
        self.tableView.reloadData()
//        _ = navigationController?.popToViewController(self, animated: true)
    }
    
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


// MARK: - UITableViewDataSource
extension MainViewController: UITableViewDataSource{
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cities.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CityTableViewCell.reuseIdentifier, for: indexPath) as! CityTableViewCell
        let city = cities[indexPath.row]
        cell.setCity(city)
        return cell
    }
}


// MARK: UITableViewDelegate
extension MainViewController: UITableViewDelegate{
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: kShowDetailSegueId, sender: self)
    }
}



private extension MainViewController{
    
    func privateMethod(){
        
    }
    
}
