import QtQuick 2.2

Rectangle {
    id: rect; width: 100; height: 100

    MouseArea {
        id: mouseArea
        anchors.fill: parent
    }

    // 使用 Connections, 对项目内的信号进行了管理. 注意, 这里使用了命名规范的作为限制.
    // target, 使用 id 作为对象的标识.
    // onSingaled 固定的方式, 作为对应的回调方法.
    Connections {
        target: mouseArea
        onClicked: {
            rect.color = "red"
        }
        onEntered: {
            console.log("enter")
        }
    }
}


