//
//  ContentView.swift
//  Calculator
//
//  Created by Wang Wei on 2019/06/17.
//  Copyright © 2019 OneV's Den. All rights reserved.
//

import SwiftUI
import Combine

let scale = UIScreen.main.bounds.width / 414

/*
 @State 和 @Binding 提供 View 内部 的状态存储，它们应该是被标记为 private 的简单值类型，仅在内部使用。
 ObservableObject 和 @ObservedObject 则针对跨越 View 层级的状态共享，它可以 处理更复杂的数据类型，其引用类型的特点，也让我们需要在数据变化时通过某种 手段向外发送通知 (比如手动调用 objectWillChange.send() 或者使用 @Published)， 来触发界面刷新。
 对于 “跳跃式” 跨越多个 View 层级的状态，@EnvironmentObject 能让我们更方便地使用 ObservableObject，以达到简化代码的目的。
 */

struct ContentView : View {

    /*
     如果, 不使用 EnvironmentObject 的话, 那么每一个 SubView 在使用 CalculatorModel 的时候, 都要在初始化方法里面, 把这个值特意的传递过去, 这样, SubView 才能够正确的使用到 Model.
     但是, 实际上, Pad, History 两个 SubView 并不是和 CalculatorModel 进行紧密相关的, 是它们上面的 SubView 的操作, 和 CalculatorModel 进行紧密相关.
     在 UIKit 上面, 这个是一定要显示的传递的.
     SwiftUI 里面, 提供了 EnvironmentObject 这样的技术, 可以让 SubView 向全局环境里面, 获取资源.
     其实这是一种, 类似于使用全局变量的写法. 所以, 一定要控制好使用的范围.
     */
    /*
     View 提供了 environmentObject(_:) 方法，来 把某个 ObservableObject 的值注入到当前 View 层级及其子层级中去。
     在这个 View 的子层级中，可以使用 @EnvironmentObject 来直接获取这个绑定的环境值。
     在对应的 View 生成时，我们不需要手动为被标记为 @EnvironmentObject 的值进行指定，
     它们会自动去查询 View 的 Environment 中是否有符合的类型的值。
     如果有则使用它们，如没有则抛出运行时的错误。
     */
    
    // 不是自动生成的, 在 SceneDelegate 里面, 专门进行了环境变量的注册.
    @EnvironmentObject var model: CalculatorModel
    @State private var editingHistory = false
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Button("操作履历: \(model.history.count)") {
                self.editingHistory = true
            }.sheet(isPresented: self.$editingHistory) {
                // 这里, 没有设置 editingHistory = false 的操作.
                // 当用户使用手势, 关闭 HistoryView 的时候, 会将这个 binding 的值, 设置为 false.
                HistoryView(model: self.model)
            }

            Text(model.brain.output)
                .font(.system(size: 76))
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 24 * scale)
                .lineLimit(1)
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    alignment: .trailing)
            CalculatorButtonPad()
                .padding(.bottom)
        }
    }
}

struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
            ContentView().previewDevice("iPhone SE")
            ContentView().previewDevice("iPad Air 2")
        }
    }
}

/*
 CalculatorButton
 */
struct CalculatorButton : View {

    let fontSize: CGFloat = 38
    let title: String
    let size: CGSize
    let backgroundColorName: String
    let foregroundColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize * scale))
                .foregroundColor(foregroundColor)
                .frame(width: size.width * scale, height: size.height * scale)
                .background(Color(backgroundColorName))
                .cornerRadius(size.width * scale / 2)
        }
    }
}

struct CalculatorButtonRow : View {
    let row: [CalculatorButtonItem]
    @EnvironmentObject var model: CalculatorModel
    var body: some View {
        HStack {
            ForEach(row, id: \.self) { item in
                CalculatorButton(
                    title: item.title,
                    size: item.size,
                    backgroundColorName: item.backgroundColorName,
                    foregroundColor: item.foregroundColor)
                {
                    // 这里是 Button 的 Action.
                    // 当 Button 被点击之后, 将 Button 的 Item 传递到最终的数据里面进行操作.
                    // 当, 没有使用 EnvironmentObject 之前, 在创建 CalculatorButtonRow 的时候, 需要将 Model 逐层的传递下来.
                    self.model.apply(item)
                }
            }
        }
    }
}

// 在 Pad 里面, 是不会直接使用到 CalculatorModel 的, 而是在 CalculatorButtonRow 的 Button 的 Action 回调里面, 会使用到 CalculatorButtonRow.
// 之前在 Pad 里面, 传递 Model 仅仅也是为了 Model 的传递.
// 在使用了 EnvironmentObject 这种环境变量全局获取的方式之后, 就没有在中间层, 专门为了传递而设置 model 这样的一个无用的属性了.
struct CalculatorButtonPad: View {
    let pad: [[CalculatorButtonItem]] = [
        [.command(.clear), .command(.flip),
         .command(.percent), .op(.divide)],
        [.digit(7), .digit(8), .digit(9), .op(.multiply)],
        [.digit(4), .digit(5), .digit(6), .op(.minus)],
        [.digit(1), .digit(2), .digit(3), .op(.plus)],
        [.digit(0), .dot, .op(.equal)]
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(pad, id: \.self) { row in
                CalculatorButtonRow(row: row)
            }
        }
    }
}

struct HistoryView: View {
    @ObservedObject var model: CalculatorModel
    var body: some View {
        VStack {
            // ConditionView 会在这里生成.
            if model.totalCount == 0 {
                Text("没有履历")
            } else {
                HStack {
                    Text("履历").font(.headline)
                    Text("\(model.historyDetail)").lineLimit(nil)
                }
                HStack {
                    Text("显示").font(.headline)
                    Text("\(model.brain.output)")
                }
                // 这里, 直接通过 $model.slidingIndex, 将 View 层的数据, 和 Model 层的数据, 进行了绑定.
                /*
                    Slider
                    最主要的特点是接受一个 Binding 值来显示当前滑动值
                    用户通过滑动操作 的设置的新值，也通过 Binding 反过来设定被包装的底层变量。
                    在这里， $model.slidingIndex 作为 Binding 被绑定到了控件上。用户的滑动操作将直 接设定 slidingIndex，并触发它的 didSet。
                */
                Slider(value: $model.slidingIndex, in: 0...Float(model.totalCount), step: 1)
            }
        }.padding()
    }
}
