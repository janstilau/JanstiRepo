//
//  ViewController.swift
//  2048Self
//
//  Created by JustinLau on 2019/7/29.
//  Copyright © 2019 JustinLau. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let game = GameBoardViewController()
    }

}

