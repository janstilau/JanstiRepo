import QtQuick 2.2

Rectangle {
    width: 100; height: 100; color: "red"

    Component.onCompleted: {
        console.log("Square btn complete")
    }

    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        onClicked: {
            console.log("Button clicked!")
            console.log(mouse)
            mouse.accepted = false
        }
    }
}

