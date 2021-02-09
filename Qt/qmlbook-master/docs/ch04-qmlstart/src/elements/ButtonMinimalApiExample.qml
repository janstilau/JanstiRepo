// button_minimalapi.qml

import QtQuick 2.5

Item {
    id: root
    width: 116; height: 26

    // export button properties
    property alias text: label.text
    signal clicked

    Rectangle {
        anchors.fill: parent
        color: "lightsteelblue"
        border.color: "slategrey"
    }
    Text {
        id: label
        anchors.centerIn: parent
        text: "Start"
    }
    MouseArea {
        anchors.fill: parent
        onClicked: {
            // 这里, 必须使用 root.clicked 才对.
            // 原因在于, MouseArea 本身自己是有 Clicked 方法的, 如果不表明 id 调用clicked. 其实是调用Mouse
            root.clicked()
        }
    }
}
