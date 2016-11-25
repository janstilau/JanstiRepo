//
//  BaseViewController.swift
//  reInputCloudDemo
//
//  Created by jansti on 16/11/24.
//  Copyright © 2016年 jansti. All rights reserved.
//

import UIKit


class BaseViewController: UIViewController{
    
    func presentMessage(_ message: String) {
        let alertViewController = UIAlertController.init(title: "CloudKit", message: message, preferredStyle: .alert)
        let okAction = UIAlertAction.init(title: "OK", style: .default, handler: nil)
        alertViewController.addAction(okAction)
        present(alertViewController, animated: true, completion: nil)
    }
    
}


