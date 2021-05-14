//
//  WeatherViewController.swift
//  Sky
//
//  Created by Mars on 13/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import UIKit

class WeatherViewController: UIViewController {

    @IBOutlet weak var weatherContainerView: UIView!
    @IBOutlet weak var loadingFailedLabel: UILabel!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    private func setupView() {
        weatherContainerView.isHidden = true
        loadingFailedLabel.isHidden = true
        
        activityIndicatorView.startAnimating()
        activityIndicatorView.hidesWhenStopped = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
    }
}
