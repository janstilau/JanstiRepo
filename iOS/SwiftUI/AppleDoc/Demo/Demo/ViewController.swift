//
//  ViewController.swift
//  Demo
//
//  Created by 刘国强 on 2021/6/11.
//

import UIKit

class ViewController: UIViewController {

    var theQueue = DispatchQueue(label: "myqueue", attributes: [.concurrent])
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        print(theQueue)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        struct counter {
            static var count = 1
        }
        
        for _ in 1...10 {
            let task = DispatchWorkItem.init(flags: [.barrier]) {
                Thread.sleep(forTimeInterval: 0.1)
                print(counter.count)
                print(Thread.current)
                counter.count += 1
            }
            theQueue.async(execute: task)
        }
        theQueue.sync {
            print(Thread.current)
            print("sync")
        }
        print(Thread.current)
        print("end")
    }
    
}

