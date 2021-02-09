
// ClickableImage.qml
// Simple image which can be clicked

import QtQuick 2.5


Image {
    id: root
    signal clicked

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}

