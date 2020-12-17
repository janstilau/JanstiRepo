import QtQuick 2.2

// Item 是类似于 View 的一个东西. 本身没有显示效果, 一般当做容器使用, 是所有可见元素的父类.
// opacity 不会影响到事件处理, enable 和 visible 会影响.
Item {
    Rectangle {
        color: "red"
        width: 100; height: 100
        Rectangle {
            color: "blue"
            x: 50; y: 50; width: 100; height: 100
        }
    }
}

//Item {
//    Rectangle {
//        opacity: 0.5
//        color: "red"
//        width: 100; height: 100
//        Rectangle {
//            color: "blue"
//            x: 50; y: 50; width: 100; height: 100
//        }
//    }
//}
