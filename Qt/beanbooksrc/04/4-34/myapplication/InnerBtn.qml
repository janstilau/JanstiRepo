import QtQuick 2.0

SquareButton {
    id: root
    Rectangle {
        width: root.width * 0.5
        height: root.height * 0.5
    }
    Component.onCompleted:  {
        console.log("Inner btn completed")
    }
}
