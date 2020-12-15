import QtQuick 2.2

Rectangle {
    // 使用 list 的方式更好, 更加清晰.
    // 只声明，不初始化
    property list<Rectangle> siblingRects

    // 声明并且初始化
    property list<Rectangle> childRects: [
        Rectangle { color: "red" },
        Rectangle { color: "blue"}
        // 组件名, 大括号, 里面的属性:value 对应. 这就是在进行对象的创建工作.
    ]

    MouseArea {
        anchors.fill:parent
        onClicked: {
            for (var i = 0; i < childRects.length; i++) {
                console.log("color", i, childRects[i].color)
            }
        }
    }
}



