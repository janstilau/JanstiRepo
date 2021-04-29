//
//  ContentView.swift
//  Calculate
//
//  Created by JustinLau on 2021/4/29.
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        // 由于 para label 的存在, 可以直接使用其他的默认值, 仅仅在() 内写出, 需要定制化的参数的 label 出来.
        VStack(spacing: 8) {
            CalculateRow(row: [
                .command(.clear), .command(.filp), .command(.percent), .command(.divide)
            ])
            CalculateRow(row: [
                .digit(7), .digit(8), .digit(9), .op(.multiply)
            ])
            CalculateRow(row: [
                .digit(4), .digit(5), .digit(6), .op(.minus)
            ])
            CalculateRow(row: [
                .digit(0), .dot, .op(.equal)
            ])
        }
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
enum CalculatorItem {
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
        case divide = "/"
    }
    
    case digit(Int)
    case dot
    case op(Operator)
    case command(Command)
}


/*
 使用 Enum 来表示数据, 需要编写一些 extension, 做里面的值的抽取工作.
 因为实际上, 外界使用这个数据类型的时候, 其实是希望可以有方便快捷的方法, 直接提取到最需要得到的数据的.
 如何进行数据的保存, 是类的设计者的事情, 外界认为这是一个数据, 所以直接读取里面的属性来操作, 是最符合期望的做法.
 Extensin, 就是将这部分的逻辑进行封装.
 */
extension CalculatorItem {
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

extension CalculatorItem: Hashable {}

struct CalculateRow: View {
    let row: [CalculatorItem]
    var body: some View {
        HStack {
            ForEach(row, id:\.self) { item in
                CalculateButton(title: item.title,
                                size: item.size,
                                backgroundColorName: item.backgroundColor)
                {
                    print(item.title)
                }
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
