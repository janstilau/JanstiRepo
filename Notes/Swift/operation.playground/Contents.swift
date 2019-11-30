import UIKit

//let a: Int? = nil
//let b: String = "BBB"
//print(a ?? b)

// 区间运算符


let range = 0..<10
print(range.count)

let partialRange = ...10 // 没有 count 属性.

extension UIView {
    static func + (left: UIView, right: UIView) {
        print("view ++");
    }
}

extension NSDictionary {
    static func + (left: NSDictionary, right: NSDictionary) -> Int {
        print("Dict ++")
        return 1;
    }
}

UIView() + UIView()
NSDictionary() + NSDictionary()
