//
//  CircleImage.swift
//  Landmark
//
//  Created by JustinLau on 2021/4/28.
//

import SwiftUI

struct CircleImage: View {
    var body: some View {
       Image("img_game_entrance_bg")
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.green, lineWidth: 4))
        .shadow(radius: 7)
    }
}

struct CircleImage_Previews: PreviewProvider {
    static var previews: some View {
        CircleImage()
    }
}
