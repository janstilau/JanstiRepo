//
//  PokemonInfoPanel.swift
//  PokeMaster
//
//  Created by JustinLau on 2021/5/7.
//  Copyright © 2021 OneV's Den. All rights reserved.
//

import SwiftUI

struct PokemonInfoPanel: View {
    
    let model: PokemonViewModel
    
    var abilities: [AbilityViewModel] {
        AbilityViewModel.sample(pokemonID: model.id)
    }
    
    //  可以直接这样, 定义一个计算属性.
    var topIndicator: some View {
        RoundedRectangle(cornerRadius: 3)
            .frame(width: 40, height: 6)
            .opacity(0.2)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            topIndicator
        }
    }
}

extension PokemonInfoPanel {
    // 对于这种嵌套类型, 可以大大减少前缀的使用.
    // OC 里面, 习惯了定义顶级类型, 并且以超长前缀来命名, 在 Swift 里面, 要杜绝这种写法.
    struct Header: View {
        
        var body: some View {
            
        }
    }
}

struct PokemonInfoPanel_Previews: PreviewProvider {
    static var previews: some View {
        PokemonInfoPanel(model: .sample(id: 1))
    }
}
