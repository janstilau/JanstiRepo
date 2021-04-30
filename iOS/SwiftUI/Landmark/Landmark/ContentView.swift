//
//  ContentView.swift
//  Landmark
//
//  Created by JustinLau on 2021/4/28.
//

import SwiftUI

/*
 @State 这个类型, 应该是将声明的属性, 纳入到 Binding 系统里面. 这个值, 被框架所接管. 这样, 在这个值发生了改变之后, View 可以直接被框架进行更新.
 Use the state as the single source of truth for a given view.
 
 $coutner 这个值, 返回的是一个绑定后的值, coutner 改变之后, 其他的使用到 $cunter 的地方, 也会刷新.
 */
struct ContentView: View {
    @State var counter = 0
    
    var body: some View {
        VStack {
            Button("TapMe"){self.counter += 1}
            if 0 < counter && counter <= 10 {
                Text("Bingo \(counter)")
            } else if counter > 10 {
                Text("More Than 10")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
        }
    }
}
