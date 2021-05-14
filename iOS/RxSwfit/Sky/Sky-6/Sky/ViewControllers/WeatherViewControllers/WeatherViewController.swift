//
//  WeatherViewController.swift
//  Sky
//
//  Created by Mars on 05/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import UIKit

class WeatherViewController: UIViewController {
    
    @IBOutlet weak var weatherContainerView: UIView!
    @IBOutlet weak var loadingFailedLabel: UILabel!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 只在viewDidLoad方法里表明各种初始化的语义，而把各种初始化的细节放在独立的方法里。否则，viewDidLoad方法也很容易变成一个包含各种初始化细节的“巨型方法”
        setupView()
    }
    
    private func setupView() {
        weatherContainerView.isHidden = true
        loadingFailedLabel.isHidden = true

        activityIndicatorView.startAnimating()
        activityIndicatorView.hidesWhenStopped = true
    }
}
