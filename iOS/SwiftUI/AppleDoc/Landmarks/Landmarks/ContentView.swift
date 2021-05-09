//
//  ContentView.swift
//  Landmarks
//
//  Created by 刘国强 on 2021/5/8.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Turtle Rock")
            .font(.body)
            .fontWeight(.medium)
            .foregroundColor(Color.blue)
            .multilineTextAlignment(.trailing)
            .lineLimit(5)
            .padding(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/)
            
            
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
        }
    }
}
