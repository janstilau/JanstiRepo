import QtQuick 2.2

// Item 是没有颜色信息的, 但是 Rectangle 是可以的. 所以, 这个东西更加像 iOS 的 View.
//Rectangle {
//    width: 100; height: 100
//    color: "red"
//    border.color: "black"
//    border.width: 5
//    radius: 10
//}

//Rectangle {
//    y: 0; width: 80; height: 80
//    color: "lightsteelblue"
//}

//Rectangle {
//    y: 100; width: 80; height: 80
//    // Gradient 更多的是构造函数的调用这样理解.
//    gradient: Gradient {
//        GradientStop { position: 0.0; color: "lightsteelblue" }
//        GradientStop { position: 1.0; color: "blue" }
//    }
//}

Rectangle {
    y: 200; width: 80; height: 80
    rotation: 90
    gradient: Gradient {
        GradientStop { position: 0.0; color: "lightsteelblue" }
        GradientStop { position: 1.0; color: "blue" }
    }
}
