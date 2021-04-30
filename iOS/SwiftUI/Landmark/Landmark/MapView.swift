//
//  MapView.swift
//  Landmark
//
//  Created by JustinLau on 2021/4/28.
//

import SwiftUI
import MapKit

struct LabelView: View {
    var counter: Int
    var body: some View {
if counter > 0 {
Text("You've tapped \(counter) times")
    Group {
        
    }
} }
}

//struct MapView: View {
//    @State private var region = MKCoordinateRegion(
//        center: CLLocationCoordinate2D(latitude: 34.011_286, longitude: -116.166_868),
//        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
//    )
//
//    var body: some View {
//        Map(coordinateRegion: $region)
//    }
//}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        LabelView(counter: 1)
    }
}
