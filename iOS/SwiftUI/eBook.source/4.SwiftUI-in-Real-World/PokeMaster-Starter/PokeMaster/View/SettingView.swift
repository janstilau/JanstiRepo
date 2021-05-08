//
//  SettingView.swift
//  PokeMaster
//
//  Created by JustinLau on 2021/5/7.
//  Copyright © 2021 OneV's Den. All rights reserved.
//

import SwiftUI

// Model 部分.
// ObservableObject 代表着, 实现类里面, 会有一个名为 objectWillChange 的 publisher, 当实现类内部数据发生变化的时候, 可以调用该属性的 send 方法.
class Settings: ObservableObject {

    enum AccountBehavior: CaseIterable {
        case register, login
    }

    enum Sorting: CaseIterable {
        case id, name, color, favorite
    }

    // @Published 代表着, 这个属性 willset, 会调用 publisher.send 方法. 发送变化信号.
    @Published var accountBehavior = AccountBehavior.login
    @Published var email = ""
    @Published var password = ""
    @Published var verifyPassword = ""

    @Published var showEnglishName = true
    @Published var sorting = Sorting.id
    @Published var showFavoriteOnly = false
}


struct SettingView: View {
    
    // @ObservedObject 代表着, View 里面会监听 Model 的变化. 当 Model 发出信号, 表示自己数据改变之后, 对应的 View 会重新进行渲染.
    @ObservedObject var settings = Settings()
    
    var body: some View {
        Form {
            accountSection
            optionSection
            actionSection
        }
    }

    var accountSection: some View {
        Section(header: Text("账户")) {
            Picker(selection: $settings.accountBehavior, label: Text("")) {
                ForEach(Settings.AccountBehavior.allCases, id: \.self) {
                    Text($0.text)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            TextField("电子邮箱", text: $settings.email)
            SecureField("密码", text: $settings.password)
            if settings.accountBehavior == .register {
                SecureField("确认密码", text: $settings.verifyPassword)
            }
            Button(settings.accountBehavior.text) {
                print("登录/注册")
            }
        }
    }

    var optionSection: some View {
        Section(header: Text("选项")) {
            Toggle(isOn: $settings.showEnglishName) {
                Text("显示英文名")
            }
            Picker(selection: $settings.sorting, label: Text("排序方式")) {
                ForEach(Settings.Sorting.allCases, id: \.self) {
                    Text($0.text)
                }
            }
            Toggle(isOn: $settings.showFavoriteOnly) {
                Text("只显示收藏")
            }
        }
    }

    var actionSection: some View {
        Section {
            Button(action: {
                print("清空缓存")
            }) {
                Text("清空缓存").foregroundColor(.red)
            }
        }
    }
}

extension Settings.Sorting {
    var text: String {
        switch self {
        case .id: return "ID"
        case .name: return "名字"
        case .color: return "颜色"
        case .favorite: return "最爱"
        }
    }
}

extension Settings.AccountBehavior {
    var text: String {
        switch self {
        case .register: return "注册"
        case .login: return "登录"
        }
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}

