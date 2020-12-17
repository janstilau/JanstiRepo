import QtQuick 2.2

Rectangle {
    id: root
    width: 360; height: 360

    // 注意, 这里, MyLael 是新的类名
    // 所以, QML 的组件化的逻辑是, Qml 文件名, 就是新的类.
    MyLabel {
        id: label
        anchors.centerIn: parent
        Text { text: "world!" }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            console.log(typeof(label.data))
            console.log(typeof(label.children))
            console.log(label.someText)

            console.log("-------------")
            console.log(root.children)
            console.log(root.data)
        }
    }
}

