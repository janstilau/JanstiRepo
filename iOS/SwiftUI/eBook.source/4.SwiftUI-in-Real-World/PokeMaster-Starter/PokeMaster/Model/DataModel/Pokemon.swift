//
//  Pokemon.swift
//  PokeMaster
//
//  Created by 王 巍 on 2019/08/05.
//  Copyright © 2019 OneV's Den. All rights reserved.
//

import Foundation

/*
 这里, 是变量名和 JSON Key 值相同了.
 */
struct Pokemon: Codable {

    struct `Type`: Codable {
        struct Internal: Codable {
            let name: String
            let url: URL
        }

        let slot: Int
        let type: Internal
    }

    struct Stat: Codable {

        // 这里, 是用 Case 代替了 String
        enum Case: String, Codable {
            case speed
            case specialDefense = "special-defense"
            case specialAttack = "special-attack"
            case defense
            case attack
            case hp
        }

        struct Internal: Codable {
            let name: Case
            // 这里, 没有理会 url 这个 JSON key.
        }

        let baseStat: Int // 数值
        let stat: Internal // 数据种类. 速度, 攻击, 防御, 血量.
        // 这里, 没有理会 effort 这个 json key.
    }

    struct SpeciesEntry: Codable {
        let name: String
        let url: URL
    }

    struct AbilityEntry: Codable, Identifiable {
        struct Internal: Codable {
            let name: String
            let url: URL
        }

        var id: URL { ability.url }
        
        let slot: Int
        let ability: Internal
    }

    let id: Int
    let types: [Type]
    let abilities: [AbilityEntry]
    let stats: [Stat] // 数据统计
    let species: SpeciesEntry // 种类.
    let height: Int
    let weight: Int
}

extension Pokemon: Identifiable { }

extension Pokemon: CustomDebugStringConvertible {
    var debugDescription: String {
        "Pokemon - \(id) - \(self.species.name)"
    }
}

