//
//  Created by zhouzhuo on 07/01/2017.
//

protocol PointerType : Equatable {
    associatedtype Pointee
    var pointer: UnsafePointer<Pointee> { get set }
}

extension PointerType {
    init<T>(pointer: UnsafePointer<T>) {
        func cast<T, U>(_ value: T) -> U {
            return unsafeBitCast(value, to: U.self)
        }
        self = cast(UnsafePointer<Pointee>(pointer))
    }
}

// 两个, 同类型 Pointer 的相等判断, 就是原始指针的相等判断.
func == <T: PointerType>(lhs: T, rhs: T) -> Bool {
    return lhs.pointer == rhs.pointer
}
