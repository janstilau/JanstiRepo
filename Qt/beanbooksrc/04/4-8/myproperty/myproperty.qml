import QtQuick 2.2

Rectangle {
    id: rect
    color: "yellow"

    property color nextColor: "blue"
    Component.onCompleted: {
        rect.color = "red"
    }
    MouseArea {
        anchors.fill:parent
        onClicked: {
            // 这里需要注意, color 是一个引用语义的值, 想要拷贝的话, 要抽取基本数据类型然后重新构建.
            var {r, g, b} = color
            console.log(r + "" + g + "" + b)
            color = nextColor
            nextColor = Qt.rgba(r, g, b, 1)
            console.log("color is :" + color + " " + "nextcolor is :" + nextColor)
        }

    }
}



