//
//  ContentView.swift
//  Calculate
//
//  Created by JustinLau on 2021/4/29.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        HStack {
            CalculateButton(title: "1", size: CGSize(width: 88, height: 88), backgroundColorName: "CardBackground") {
                print("Button 1")
            }
            CalculateButton(title: "2", size: CGSize(width: 88, height: 88), backgroundColorName: "CardBackground") {
                print("Button 2")
            }
            CalculateButton(title: "3", size: CGSize(width: 88, height: 88), backgroundColorName: "CardBackground") {
                print("Button 3")
            }
            CalculateButton(title: "+", size: CGSize(width: 88, height: 88), backgroundColorName: "CardBackground") {
                print("Button +")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPhone 8")
    }
}

// 也可以在 View 里面, 定义属性, 然后在 body 里面, 可以直接使用这些属性.
// 在 SwiftUI 里面, 可以直接使用 init 的 memberWise 方式, 进行初始化的操作.
struct CalculateButton: View {
    
    let fontSize: CGFloat = 38
    let title: String
    let size: CGSize
    let backgroundColorName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize))
                .foregroundColor(.white)
                .frame(width: size.width, height: size.height, alignment: .center)
                .background(Color(backgroundColorName))
                .cornerRadius(size.width / 2)
        }
    }
}

// 虽然是 Enum, 但是这个类型的本意其实是传输值.
// Enum 来表示, 是因为这个类型, 就是有着固定的 Type 区分.
enum calculatorItem {
    // 这里, 设置 RawValue 其实是因为, 想要使用 RawValue 进行显示.
    enum Operator: String {
        case plus = "+"
        case minus = "-"
        case divide = "÷"
        case multiply = "×"
        case equal = "="
    }
    
    enum Command: String {
        case clear = "AC"
        case filp = "+/-"
        case percent = "%"
    }
    
    case digit(Int)
    case dot
    case op(Operator)
    case command(Command)
}

extension calculatorItem {
    var title: String {
        switch self {
        case .digit(let value):
            return String(value)
        case .dot:
            return "."
        case .op(let op):
            return op.rawValue
        case .command(let command):
            return command.rawValue
        }
    }
    
    var size: CGSize {
        return CGSize.init(width: 88, height: 88)
    }
    
    // 原来, 带有关联值的 Enum, 也可以直接使用 case 进行判断.
    var backgroundColor: String {
        switch self {
        case .dot:
            return "NumberColor"
        case .digit:
            return "NumberColor"
        case .op:
            return "OperatorColor"
        case .command:
            return "CommandColor"
        }
    }
}
