//
//  UIViewController.swift
//  Sky
//
//  Created by Mars on 06/03/2018.
//  Copyright © 2018 Mars. All rights reserved.
//

import UIKit

extension UIViewController {
    func modalAlert(title: String,
                    message: String,
                    accept: String = .ok,
                    cancel: String = .cancel,
                    callback: @escaping () -> ()) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: cancel, style: .cancel) { _ in
            return
        })
        alert.addAction(UIAlertAction(title: accept, style: .default) { _ in
            callback()
        })
        
        return alert
    }
}

fileprivate extension String {
    static let ok = NSLocalizedString("Retry", comment: "")
    static let cancel = NSLocalizedString("Cancel", comment: "")
}

