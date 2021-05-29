//
//  ViewController.swift
//  AutoLayoutTest
//
//  Created by 刘国强 on 2021/5/29.
//

import UIKit

class ViewController: UIViewController {
    
    var redView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let width = self.view.frame.size.width * 0.6;
        let height = self.view.frame.size.height * 0.6;
        var left = self.view.frame.size.width - width;
        left *= 0.5;
        var top = self.view.frame.size.height - height;
        top *= 0.5;
        let subView = UIView()
        subView.frame = CGRect(x: left, y: top, width: width, height: height)
        subView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        subView.backgroundColor = .red
        self.view.addSubview(subView)
        
        self.redView = subView
        
        
        self.view.safeAreaLayoutGuide
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print(event)
    }

}

