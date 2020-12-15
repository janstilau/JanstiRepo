import QtQuick 2.2

Rectangle {
    id: rect
    color: "yellow"
    // 自定义了一个 property, 自定义的 property 并不会直接参与到业务逻辑里面, 需要使用代码读取该值, 然后覆盖已有的属性才能改变 view 的 UI 效果.
    property color nextColor: "blue"
    Component.onCompleted: {
        rect.color = "red"
    }
    MouseArea {
        anchors.fill:parent
        onClicked: {
            color = nextColor
        }

    }
}



