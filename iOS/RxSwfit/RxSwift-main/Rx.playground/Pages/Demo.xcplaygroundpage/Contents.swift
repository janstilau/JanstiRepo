//: [Previous](@previous)
import RxSwift

import Foundation

var greeting = "Hello, playground"

let pushlihser = Observable.of("1", "2", "3", "4", "5", "6", "7", "8", "9")
    .compactMap { Int($0) }
    .filter { $0 % 2 == 0 }
    


print("In The End")
//: [Next](@next)
