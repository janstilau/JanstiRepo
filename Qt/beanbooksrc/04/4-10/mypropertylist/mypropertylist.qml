import QtQuick 2.2

Rectangle {
    // 使用 list 的方式更好, 更加清晰.
    // 只声明，不初始化
    property list<Rectangle> siblingRects

    // 声明并且初始化
    property list<Rectangle> childRects: [
        Rectangle { color: "red" },
        Rectangle { color: "blue"}
    ]

    MouseArea {
        anchors.fill:parent
        onClicked: {
            for (var i = 0; i < childRects.length; i++) {
                console.log("color", i, childRects[i])
                // qml: color 0 QQuickRectangle(0x7ff17ecb18d0)
                // qml: color 1 QQuickRectangle(0x7ff17ecb1b70)
                // 从上面的打印可以看出, 最终还是变味了 QQuick 中的对象, 进行最终的显示工作.
            }
        }
    }
}



