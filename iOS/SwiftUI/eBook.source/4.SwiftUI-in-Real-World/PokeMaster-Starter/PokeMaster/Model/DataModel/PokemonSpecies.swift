//
//  PokemonSpecies.swift
//  PokeMaster
//
//  Created by 王 巍 on 2019/08/06.
//  Copyright © 2019 OneV's Den. All rights reserved.
//

import SwiftUI

struct PokemonSpecies: Codable {

    struct Color: Codable {
        enum Name: String, Codable {
            case black, blue, brown, gray, green, pink, purple, red, white, yellow
            
            var color: SwiftUI.Color {
                return SwiftUI.Color("pokemon-\(rawValue)")
            }
        }

        let name: Name
    }

    struct Name: Codable, LanguageTextEntry {
        let language: Language
        let name: String

        var text: String { name }
    }

    struct FlavorTextEntry: Codable, LanguageTextEntry {
        let language: Language
        let flavorText: String

        var text: String { flavorText }
    }

    struct Genus: Codable, LanguageTextEntry {
        let language: Language
        let genus: String

        var text: String { genus }
    }

    let color: Color
    /*
     之所以, 各种属性是一个数组, 是一位 JSON 文件里面, 各种对应的 value 值, 是多语言版本的.
     */
    let names: [Name]
    let genera: [Genus]
    let flavorTextEntries: [FlavorTextEntry]
}
