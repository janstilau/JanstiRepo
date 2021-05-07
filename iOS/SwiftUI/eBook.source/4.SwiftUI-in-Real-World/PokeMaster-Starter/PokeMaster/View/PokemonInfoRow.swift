//
//  PokemonInfoRow.swift
//  PokeMaster
//
//  Created by JustinLau on 2021/5/7.
//  Copyright © 2021 OneV's Den. All rights reserved.
//

import SwiftUI

struct PokemonInfoRow: View {
    let model: PokemonViewModel
    @State var expanded: Bool
    
    var body: some View {
        VStack {
            /*
             相比较 UIKit 的各种指令式的写法, 描述式, 代码更少, 效果更快.
             当然, 是框架的内部, 将绘制的过程进行了接管.
             */
            HStack {
                // 这种方式, 感觉没有 qml 更加的直接和方便.
                Image("Pokemon-\(model.id)")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .aspectRatio(contentMode: .fit)
                    .shadow(radius: 4)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(model.name)
                        .font(.title)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    Text(model.nameEN)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }.padding(.top, 0)
            
            Spacer()
            
            /*
             Swift 的标签的方式, 使得很多闭包看起来像是声明式的写法, 但是其实是闭包. 是需要执行的.
             */
            HStack(spacing: expanded ? CGFloat(20) : CGFloat(-30)) {
                Spacer()
                Button(action: { print("Fav") }) {
                    Image(systemName: "star")
                        .modifier(ToolButtonModifier())
                }
                Button(action: { print("Panel") }) {
                    Image(systemName: "chart.bar")
                        .modifier(ToolButtonModifier())
                }
                Button(action: { print("Web") }) {
                    Image(systemName: "info.circle")
                        .modifier(ToolButtonModifier())
                }
            }
            .padding(.bottom, 12)
            .opacity(expanded ? 1.0: 0.0)
            .frame(maxHeight: expanded ? .infinity : CGFloat(0))
        }
        .frame(height: expanded ? CGFloat(120.0) : CGFloat(80.0))
        .padding(.leading, 23)
        .padding(.trailing, 15)
        .background(
            // Shape 作为一种特殊的 View, 提供了 fill 方法.
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                      .stroke(model.color, style: StrokeStyle(lineWidth: 4))
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                                gradient: Gradient(colors: [.white, model.color]),
                                startPoint: .leading,
                                endPoint: .trailing
                        )
                    )
            }
        )
        .onTapGesture {
            withAnimation(
                .spring(response: 0.55,
                        dampingFraction:
                            0.425, blendDuration: 0))
            {
                self.expanded.toggle()
            }
        }
    }
}

/*
 由于 ViewModifier 可以跨越页面并作用在任意 View 上，因此在大型项目中
 合理使用 ViewModifier 来减少重复和维护难度会是很常见的做法。
 */
struct ToolButtonModifier: ViewModifier {
    // 这个协议, 就是抽取对于 View 的配置操作到特定类型的一个协议.
    // 自己写的话, 就是各种 Tool 类.
    func body(content: Content) -> some View {
        content
            .font(.system(size: 25))
            .foregroundColor(.white)
            .frame(width: 30, height: 30, alignment: .center)
    }
}

struct PokemonInfoRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            PokemonInfoRow(model: .sample(id: 1), expanded: false)
            PokemonInfoRow(model: .sample(id: 21), expanded: true)
            PokemonInfoRow(model: .sample(id: 25), expanded: false)
        }
    }
}
