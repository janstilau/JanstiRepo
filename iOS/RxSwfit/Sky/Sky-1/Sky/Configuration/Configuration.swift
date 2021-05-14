//
//  Configuration.swift
//  Sky
//
//  Created by Mars on 28/09/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation


/*
 将配置相关的信息, 专门放到一个地方集中配置.
 这个应该是按照业务来的, 不要将不同业务的配置, 统统放到一起. 
 */
struct API {
    static let key = "af7aa5cfc14d558e720caff21791f148"
    static let baseURL = URL(string: "https://api.darksky.net/forecast/")!
    static let authenticatedURL = baseURL.appendingPathComponent(key)
}
