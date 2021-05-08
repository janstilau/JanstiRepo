//
//  Language.swift
//  PokeMaster
//
//  Created by Wang Wei on 2019/08/20.
//  Copyright © 2019 OneV's Den. All rights reserved.
//

import Foundation

struct Language: Codable {
    let name: String
    let url: URL

    // 两个计算属性, 方便外界使用.
    var isCN: Bool { name == "zh-Hans" }
    var isEN: Bool { name == "en" }
}

/*
    一层抽象.
    可以返回一个 text 属性, 用于界面的显示.
    里面有个 language 的属性, 标明实现对象, 是和语言配置相关的一个对象.
 
 LanguageTextEntry 这层抽象, 之所以会出现, 是因为 JSON 文件里面, 各种名词, 种类, 图鉴介绍, 都是和语言绑定在一起的.
 */
protocol LanguageTextEntry {
    var language: Language { get }
    var text: String { get }
}

// LanguageTextEntry 这层抽象的意义, 是在这里.
extension Array where Element: LanguageTextEntry {
    var CN: String { first { $0.language.isCN }?.text ?? EN }
    var EN: String { first { $0.language.isEN }?.text ?? "Unknown" }
}
