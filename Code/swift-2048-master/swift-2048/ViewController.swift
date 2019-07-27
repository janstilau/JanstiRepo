//
//  ViewController.swift
//  swift-2048
//
//  Created by Austin Zheng on 6/3/14.
//  Copyright (c) 2014 Austin Zheng. Released under the terms of the MIT license.
//

import UIKit

class ViewController: UIViewController {
                            
  @IBAction func startGameButtonTapped(_ sender : UIButton) {
    let game = NumberTileGameViewController(dimension: 4, threshold: 4096)
    self.present(game, animated: true, completion: nil)
  }
}

