import UIKit

var str = "Hello, playground"

let maximumNumberOfLoginAttemptes = 10
var welcomeMessage: String
welcomeMessage = "heheda"

print(welcomeMessage)

Int.max
UInt16.max
UInt16.min
print(UInt.max)
print(Int.max)


let three = 3
let pointOneFourOneFiveNine = 0.14159
let pi = Double(three) + pointOneFourOneFiveNine

struct Size {
    var width = 0.0, height = 0.0
    init() {
        print("Size init")
    }
}

struct Point {
    var x = 0.0, y = 0.0
    init() {
        print("Point init")
    }
    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

struct Rect {
    var origin = Point()
    var size = Size()
    init() {}
    init(origin: Point, size: Size) {
//        self.origin = origin
//        self.size = size
    }
    init(center: Point, size: Size) {
        let originX = center.x - (size.width / 2)
        let originY = center.y - (size.height / 2)
        self.init(origin: Point(x: originX, y: originY), size: size)
    }
}

let point = Point()
let size = Size()
var rect = Rect()



