//
//  AbilitiesViewModel.swift
//  PokeMaster
//
//  Created by 王 巍 on 2019/08/09.
//  Copyright © 2019 OneV's Den. All rights reserved.
//

import SwiftUI


/*
    View Model.
    UI 需要显示的内容, 和某个中间类型的属性一一对应, 而不是在 View 中在对数据 Model 进行变形和计算.
 */

// 对于 Alibity 的再次封装.
struct AbilityViewModel: Identifiable, Codable {

    let ability: Ability

    init(ability: Ability) {
        self.ability = ability
    }

    var id: Int { ability.id } // 对于 Identifiable 的实现 var id: Self.ID { get };
    
    var name: String { ability.names.CN }
    var nameEN: String { ability.names.EN }
    
    var descriptionText: String { ability.flavorTextEntries.CN.newlineRemoved }
    var descriptionTextEN: String { ability.flavorTextEntries.EN.newlineRemoved }
}

extension AbilityViewModel: CustomStringConvertible {
    var description: String {
        "AbilityViewModel - \(id) - \(self.name)"
    }
}
