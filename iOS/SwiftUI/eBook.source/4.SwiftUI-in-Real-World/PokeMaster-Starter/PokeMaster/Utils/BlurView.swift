//
//  BlurView.swift
//  PokeMaster
//
//  Created by JustinLau on 2021/5/7.
//  Copyright © 2021 OneV's Den. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

struct BlurView: UIViewRepresentable {

    let style: UIBlurEffect.Style

    func makeUIView(context: UIViewRepresentableContext<BlurView>) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear

        let blurEffect = UIBlurEffect(style: style)
        let blurView = UIVisualEffectView(effect: blurEffect)

        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blurView)
        NSLayoutConstraint.activate([
            blurView.heightAnchor.constraint(equalTo: view.heightAnchor),
            blurView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
        return view
    }

    func updateUIView(
        _ uiView: UIView,
        context: UIViewRepresentableContext<BlurView>)
    {
    }
}

extension View {
    func blurBackground(style: UIBlurEffect.Style) -> some View {
        ZStack {
            BlurView(style: style)
            self
        }
    }
}
