// M1>>
// Button.qml

import QtQuick 2.5

Rectangle {
    id: root
    // export button properties

    property alias text: label.text // 给了用户自定义的机会.
    signal clicked

    width: 116; height: 26 // 继承的属性, 外界还可以改变.
    color: "lightsteelblue"
    border.color: "slategrey"

    Text { // 子控件, 外界无法改变.
        id: label
        anchors.centerIn: parent
        text: "Start"
    }
    MouseArea { // 子控件, 外界无法改变.
        anchors.fill: parent
        onClicked: {
            root.clicked()
        }
    }
}

// <<M1
