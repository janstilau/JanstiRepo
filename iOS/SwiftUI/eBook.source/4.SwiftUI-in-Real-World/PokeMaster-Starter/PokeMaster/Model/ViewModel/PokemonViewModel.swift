//
//  PokemonViewModel.swift
//  PokeMaster
//
//  Created by 王 巍 on 2019/08/06.
//  Copyright © 2019 OneV's Den. All rights reserved.
//

import SwiftUI

/*
 ViewModel 是和 View 强绑定在一起的.
 所以, 它里面有多少 DataModel, 有多少属性暴露出去, 其实是和业务强相关的.
 */
struct PokemonViewModel: Identifiable, Codable {

    var id: Int { pokemon.id }

    let pokemon: Pokemon
    let species: PokemonSpecies

    init(pokemon: Pokemon, species: PokemonSpecies) {
        self.pokemon = pokemon
        self.species = species
    }

    // 虽然, ViewModel 里面进行数据到展示的转化. 但是, 通用的部分, 还是写到了 Model 里面.
    // View Model 是从操作最上层的 Model, 将如何进行值的提取工作, 直接用自己的属性体现出来了.
    // 这样, View 层就不会出现, Model.property.property.property 这种长链的调用了.
    var color: Color { species.color.name.color }
    var height: String { "\(Double(pokemon.height) / 10)m" }
    var weight: String { "\(Double(pokemon.weight) / 10)kg" }
    var name: String { species.names.CN }
    var nameEN: String { species.names.EN }
    var genus: String { species.genera.CN }
    var genusEN: String { species.genera.EN }

    var types: [Type] {
        // self.pokemon.types 中存储的是原始数据.
        // Type 是 ViewModel 里面的 Type, 里面的数据部分, 可以从这些原始数据中进行提取. 而 Type 存在的意义, 主要是各种 View 层的显示转化.
        self.pokemon.types
            .sorted { $0.slot < $1.slot }
            .map { Type(pokemonType: $0) }
    }

    var iconImageURL: URL {
        URL(string: "https://raw.githubusercontent.com/onevcat/pokemaster-images/master/images/Pokemon-\(id).png")!
    }

    var detailPageURL: URL {
        URL(string: "https://cn.portal-pokemon.com/play/pokedex/\(String(format: "%03d", id))")!
    }

    var descriptionText: String { species.flavorTextEntries.CN.newlineRemoved }
    var descriptionTextEN: String { species.flavorTextEntries.EN.newlineRemoved }
}

extension PokemonViewModel: CustomStringConvertible {
    var description: String {
        "PokemonViewModel - \(id) - \(self.name)"
    }
}

extension PokemonViewModel {
    
    
    struct `Type`: Identifiable {

        // 对于 Identifiable 的支持.
        var id: String { return name }

        let name: String
        let color: Color

        init(name: String, color: Color) {
            self.name = name
            self.color = color
        }

        // 专门定义一个 init 函数用作转化.
        // 如果是自己去写这个函数, 大部分的逻辑, 还是要写在 init(pokemonType: Pokemon.`Type`) 里面.
        init(pokemonType: Pokemon.`Type`) {
            if let v = TypeInternal(rawValue: pokemonType.type.name)?.value {
                self = v
            } else {
                self.name = "???"
                self.color = .gray
            }
        }

        enum TypeInternal: String {
            case normal
            case fighting
            case flying
            case poison
            case ground
            case rock
            case bug
            case ghost
            case steel
            case fire
            case water
            case grass
            case electric
            case psychic
            case ice
            case dragon
            case dark
            case fairy
            case unknown
            case shadow

            var value: Type {
                switch self {
                case .normal:
                    return Type(name: "一般", color: Color(hex: 0xBBBBAC))
                case .fighting:
                    return Type(name: "格斗", color: Color(hex: 0xAE5B4A))
                case .flying:
                    return Type(name: "飞行", color: Color(hex: 0x7199F8))
                case .poison:
                    return Type(name: "毒", color: Color(hex: 0x9F5A96))
                case .ground:
                    return Type(name: "地面", color: Color(hex: 0xD8BC65))
                case .rock:
                    return Type(name: "岩石", color: Color(hex: 0xB8AA6F))
                case .bug:
                    return Type(name: "虫", color: Color(hex: 0xADBA44))
                case .ghost:
                    return Type(name: "幽灵", color: Color(hex: 0x6667B5))
                case .steel:
                    return Type(name: "钢", color: Color(hex: 0xAAAABA))
                case .fire:
                    return Type(name: "火", color: Color(hex: 0xEB5435))
                case .water:
                    return Type(name: "水", color: Color(hex: 0x5198F7))
                case .grass:
                    return Type(name: "草", color: Color(hex: 0x8BC965))
                case .electric:
                    return Type(name: "电", color: Color(hex: 0xF7CD55))
                case .psychic:
                    return Type(name: "超能力", color: Color(hex: 0xEC6298))
                case .ice:
                    return Type(name: "冰", color: Color(hex: 0x90DBFB))
                case .dragon:
                    return Type(name: "龙", color: Color(hex: 0x7469E6))
                case .dark:
                    return Type(name: "恶", color: Color(hex: 0x725647))
                case .fairy:
                    return Type(name: "妖精", color: Color(hex: 0xF3AFFA))
                case .unknown:
                    return Type(name: "???", color: Color(hex: 0x749E91))
                case .shadow:
                    return Type(name: "暗", color: Color(hex: 0x9F5A96))
                }
            }
        }
    }
}
