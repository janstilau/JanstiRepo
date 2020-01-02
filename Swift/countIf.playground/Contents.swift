import UIKit

func countIf<T>(_ container: [T], condition:(T)->Bool) -> Int {
    var result: Int = 0
    for item in container {
        if (condition(item)) { result += 1}
    }
    return result
}

func not<T>(_ sourceBlock:@escaping (T)->Bool) -> (T)->Bool {
    return {
        !sourceBlock($0);
    }
}

func bind2nd<T>(_ sourceBlock:@escaping (T,T)->Bool, secondParam: T) -> (T)->Bool {
    return { (first: T) -> Bool in
        sourceBlock(first, secondParam)
    }
}

func less<T: Comparable>() -> (T, T)->Bool {
    return {
        $0 < $1
    }
}

var numbers = [1, 2, 50, 60, 88, 99, 100, 233, 890, 9, 1000]

let result = countIf(numbers, condition: not(bind2nd(less(), secondParam: 40)))
print(result)

var texts = ["ddd", "acs", "abbb", "ccc", "aewqwe",]

let resultText = countIf(texts, condition: not(bind2nd(less(), secondParam: "b")))
print(resultText)

// Generic
struct Container<T: Comparable, N>: Comparable {
    let item: T
    var tempItem: N?
    init(_ cargo: T) {
        item = cargo
    }
    static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.item < rhs.item
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.item == rhs.item
    }
    
    func logN() {
        if let nValue = tempItem {
            print("haveValue")
        } else {
            print("NoValue")
        }
    }
}

// Specialization
extension Container where T == String {
    static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.item.count < rhs.item.count
    }
}

extension Container where N == Double {
    func logN() {
        if let nValue = tempItem {
            print("have Double Value")
        } else {
            print("NoValue")
        }
    }
}

let container1 = Container<String, Int>("abcd")
var container2 = Container<String, Int>("bbb")
var container3 = Container<String, Double>("bbb")
print(container1 < container2)
container2.tempItem = 1
container3.tempItem = 23.3
container2.logN()
container3.logN()

