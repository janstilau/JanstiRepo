//
//  PokemonList.swift
//  PokeMaster
//
//  Created by JustinLau on 2021/5/7.
//  Copyright © 2021 OneV's Den. All rights reserved.
//

import SwiftUI

/*
 Qml 里面的 List UI 控件.
 */
struct PokemonList: View {
    
    @State var expandingIndex: Int?
    
    var body: some View {
        ScrollView {
            LazyVStack {
                // 类似于 Repeater.
                ForEach(PokemonViewModel.all) { pokemon in
                    let isExpanded = self.expandingIndex == pokemon.id
                    PokemonInfoRow(model: pokemon,expanded: isExpanded)
                        .onTapGesture {
                            let springAnimation = Animation.spring(response: 0.55,
                                                                   dampingFraction: 0.425,
                                                                   blendDuration: 0)
                            withAnimation(springAnimation) {
                                if self.expandingIndex == pokemon.id {
                                    self.expandingIndex = nil
                                } else {
                                    self.expandingIndex = pokemon.id
                                }
                            }
                        }
                }
            }
        }
    }
}

struct PokemonList_Previews: PreviewProvider {
    static var previews: some View {
        PokemonList()
    }
}
