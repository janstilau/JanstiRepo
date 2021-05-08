//
//  CalculatorBrain.swift
//  Calculator
//
//  Created by 王 巍 on 2019/07/19.
//  Copyright © 2019 OneV's Den. All rights reserved.
//

import Foundation

// 刚开始, 在什么状态???
// .left("0")


/*
 Enum 的好处体现了出来
 状态管理清晰. 虽然, left Op 里面, 有着 left 的数据, 每次切换, 都要手动的将数据传输一次.
 但现在状态下的数据, 都是有用的数据, 没有废数据. 不同状态下的数据, 也不会有交叉.
 */
enum CalculatorBrain {
    case left(String)
    case leftOp(left: String, op: CalculatorButtonItem.Op)
    case leftOpRight(left: String, op: CalculatorButtonItem.Op, right: String)
    case error
    
    mutating func switchState() {
        print("switchState")
    }

    var output: String {
        let result: String
        switch self {
        // 只有左操作数, 显示左操作数
        case .left(let left): result = left
        // 左操作数加操作, 显示左操作数, 提取的时候, 忽略操作值
        case .leftOp(let left, _): result = left
        // 左操作数加操作加右操作数, 显示右操作数, 提取的时候, 忽略不需要的值.
        case .leftOpRight(_, _, let right): result = right
        case .error: return "Error"
        }
        guard let value = Double(result) else {
            return "Error"
        }
        return formatter.string(from: value as NSNumber)!
    }
    
    // 这是一个分发函数. 因为 Swfit 里面, 标签其实就是函数名的一部分, 所以, 这里其实也没有使用 apply 的类型重载, 而是特意定义了几个不同意义的函数名进行的调用.
    
    // CalculatorButtonItem 也是一个 enum.
    // enum 在处理这种, 具有明显的分发的逻辑的时候, 具有很好地作用.
    @discardableResult
    func apply(item: CalculatorButtonItem) -> CalculatorBrain {
        switch item {
        case .digit(let num):
            return apply(num: num)
        case .dot:
            return applyDot()
        case .op(let op):
            return apply(op: op)
        case .command(let command):
            return apply(command: command)
        }
    }

    // private, 代表着这是一个私有函数.
    // 良好的范围控制操作符, 要比下划线更有释义性.
    
    // 对于, 新输入的数字的处理.
    private func apply(num: Int) -> CalculatorBrain {
        switch self {
        case .left(let left):
            // 左操作数输入状态, 更新左操作数.
            return .left(left.apply(num: num))
        case .leftOp(let left, let op):
            // 左操作数, 操作符 输入完的状态, 进入 右操作数输入状态.
            return .leftOpRight(left: left, op: op, right: "0".apply(num: num))
        case .leftOpRight(let left, let op, let right):
            // 右操作数输入状态, 更新右操作数.
            return .leftOpRight(left: left, op: op, right: right.apply(num: num))
        case .error:
            // 错误状态, 进入到左操作数状态.
            return .left("0".apply(num: num)) // 上面出错了. 输入新的值, 结束上面的流程.
        }
    }

    // 输入 dot 的处理, 和输入数字的处理, 几乎相同.
    private func applyDot() -> CalculatorBrain {
        switch self {
        case .left(let left):
            return .left(left.applyDot())
        case .leftOp(let left, let op):
            return .leftOpRight(left: left, op: op, right: "0".applyDot())
        case .leftOpRight(let left, let op, let right):
            return .leftOpRight(left: left, op: op, right: right.applyDot())
        case .error:
            return .left("0".applyDot())
        }
    }

    // 输入运算符的处理.
    private func apply(op: CalculatorButtonItem.Op) -> CalculatorBrain {
        switch self {
        case .left(let left):
            switch op {
            // 二则运算符, 新的状态.
            case .plus, .minus, .multiply, .divide:
                return .leftOp(left: left, op: op)
            // 等号运算符, 返回自身
            case .equal:
                return self
            }
        case .leftOp(let left, let currentOp):
            switch op {
            // 二则运算符, 替换运算符的状态.
            case .plus, .minus, .multiply, .divide:
                return .leftOp(left: left, op: op)
                
            case .equal:
            // 这里, 是将左右操作符, 都用做操作符来代替了. 不是一个常见的思路.
                if let result = currentOp.calculate(l: left, r: left) {
                    return .leftOp(left: result, op: currentOp)
                } else {
                    return .error
                }
            }
        case .leftOpRight(let left, let currentOp, let right):
            switch op {
            case .plus, .minus, .multiply, .divide:
                // 如果新输入了操作符, 那么就是先计算出原来的值, 当做 left 的数据.
                // 然后和新的操作符, 组成新的 leftOp
                if let result = currentOp.calculate(l: left, r: right) {
                    return .leftOp(left: result, op: op)
                } else {
                    return .error
                }
            case .equal:
                if let result = currentOp.calculate(l: left, r: right) {
                    return .left(result)
                } else {
                    return .error
                }
            }
        case .error:
            return self
        }
    }

    private func apply(command: CalculatorButtonItem.Command) -> CalculatorBrain {
        switch command {
        case .clear:
            return .left("0")
        case .flip:
            switch self {
            case .left(let left):
                return .left(left.flipped())
            case .leftOp(let left, let op):
                return .leftOpRight(left: left, op: op, right: "-0")
            case .leftOpRight(left: let left, let op, let right):
                return .leftOpRight(left: left, op: op, right: right.flipped())
            case .error:
                return .left("-0")
            }
        case .percent:
            switch self {
            case .left(let left):
                return .left(left.percentaged())
            case .leftOp:
                return self
            case .leftOpRight(left: let left, let op, let right):
                return .leftOpRight(left: left, op: op, right: right.percentaged())
            case .error:
                return .left("-0")
            }
        }
    }
}

// Swift 里面, 这种初始化方法, 将初始化和定义包裹在一起, 是一种非常常见的初始化的方式.
var formatter: NumberFormatter = {
    let f = NumberFormatter()
    f.minimumFractionDigits = 0
    f.maximumFractionDigits = 8
    f.numberStyle = .decimal
    return f
}()

extension String {
    var containsDot: Bool {
        return contains(".")
    }

    var startWithNegative: Bool {
        return starts(with: "-")
    }

    func apply(num: Int) -> String {
        // 这里, 专门对 0 做了特殊处理. 不会出现 09 这种情况出现.
        return self == "0" ? "\(num)" : "\(self)\(num)"
    }

    // 这里, 如果已经是含有了 dot, 返回当前数字本身, 重复输入 dot 是一个很普遍的行为, 报错不合适.
    func applyDot() -> String {
        return containsDot ? self : "\(self)."
    }

    func flipped() -> String {
        if startWithNegative {
            var s = self
            s.removeFirst()
            return s
        } else {
            return "-\(self)"
        }
    }

    func percentaged() -> String {
        return String(Double(self)! / 100)
    }
}

extension CalculatorButtonItem.Op {
    func calculate(l: String, r: String) -> String? {

        guard let left = Double(l), let right = Double(r) else {
            return nil
        }

        let result: Double?
        switch self {
        case .plus: result = left + right
        case .minus: result = left - right
        case .multiply: result = left * right
        case .divide: result = right == 0 ? nil : left / right
        case .equal: fatalError() // 对于不可能出现的状态, 直接 fataError.
        }
        return result.map { String($0) }
    }
}
