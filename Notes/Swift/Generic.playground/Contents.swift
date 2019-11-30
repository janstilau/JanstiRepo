import UIKit

var str = "Hello, playground"
print(str)


class A {
    func sayHi<Indics: Equatable>(value: Indics) -> Void where Indics:NSCoding{
        print("SayHi")
        let value2 = value
        print(value2 == value)
    }
}

