//
//  PokemonInfoPanelHeader.swift
//  PokeMaster
//
//  Created by JustinLau on 2021/5/7.
//  Copyright © 2021 OneV's Den. All rights reserved.
//

import SwiftUI

extension PokemonInfoPanel {
    struct Header: View {

        let model: PokemonViewModel
        
        /*
         大部分的 View, 都是一个 Container 而已, 在里面, 按照 UI 进行 DrawView 的布局.
         在 UIKit 里面, 会定义各个 Container, 然后各个 Container 里面, 在进行小范围的布局控制.
         在 SwiftUI 里面, 可以使用函数的方式.
         但是, Swift 里面, 更加的方便的是计算属性的方式.
         */
        var body: some View {
            HStack(spacing: 18) {
                pokemonIcon
                nameSpecies
                verticalDivider
                VStack(spacing: 12) {
                    bodyStatus
                    typeInfo
                }
            }
        }

        var pokemonIcon: some View {
            Image("Pokemon-\(model.id)")
                .resizable()// 如果, 不先调用 resizable, 那么 Image 还是显示 Image 的原有的尺寸
                .frame(width: 68, height: 68)
        }

        var nameSpecies: some View {
            // 两个组件之间的距离, 通过 sapcing 进行控制.
            VStack(spacing: 10) {
                // 毗邻的文字之间的距离, 没有进行控制, 使用系统默认值.
                VStack {
                    Text(model.name)
                        .font(.system(size: 22))
                        .fontWeight(.bold)
                        .foregroundColor(model.color)
                    Text(model.nameEN)
                        .font(.system(size: 13))
                        .fontWeight(.bold)
                        .foregroundColor(model.color)
                }
                Text(model.genus)
                    .font(.system(size: 13))
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
            }.border(Color.red, width: 1)
        }

        var verticalDivider: some View {
            // 一个简单的 RoundedRectangle.
            RoundedRectangle(cornerRadius: 1)
                .frame(width: 1, height: 44)
                .opacity(0.1)
        }

        var bodyStatus: some View {
            VStack(alignment: .leading) {
                // 标签 内容, 使用 HStack 进行显示.
                HStack {
                    Text("身高")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text(model.height)
                        .font(.system(size: 11))
                        .foregroundColor(model.color)
                }
                HStack {
                    Text("体重")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text(model.weight)
                        .font(.system(size: 11))
                        .foregroundColor(model.color)
                }
            }
        }

        var typeInfo: some View {
            HStack {
                ForEach(self.model.types) { t in
                    // ZStack 就是从下往上进行 View 的叠加.
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(t.color)
                            .frame(width: 36, height: 14)
                        Text(t.name)
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

struct PokemonInfoPanelHeader_Previews: PreviewProvider {
    static var previews: some View {
        PokemonInfoPanel.Header(model: .sample(id: 1))
    }
}
