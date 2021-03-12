//
//  ViewController.swift
//  3RDLibContainer
//
//  Created by JustinLau on 2021/3/12.
//

import UIKit
import HandyJSON

class BasicTypes: HandyJSON {
    var int: Int = 2
    var doubleOptional: Double?
    var stringImplicitlyUnwrapped: String!

    required init() {}
}

enum AnimalType: String, HandyJSONEnum {
    case Cat = "cat"
    case Dog = "dog"
    case Bird = "bird"
}

struct Animal: HandyJSON {
    var name: String?
    var type: AnimalType?
}


class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let jsonString = "{\"doubleOptional\":1.1,\"stringImplicitlyUnwrapped\":\"hello\",\"int\":1}"
        if let object = BasicTypes.deserialize(from: jsonString) {
            print(object)
        }
        
//        let jsonString = "{\"type\":\"cat\",\"name\":\"Tom\"}"
//        if let animal = Animal.deserialize(from: jsonString) {
//            print(animal.type?.rawValue)
//        }
    }

}

