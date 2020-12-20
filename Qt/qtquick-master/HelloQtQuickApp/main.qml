import QtQuick 2.2
import QtQuick.Window 2.1

Window {
    id: root
    visible: true

    width: 360
    height: 360

    contentOrientation: Qt.PortraitOrientation
    //visibility: Window.Windowed

    MouseArea {
        anchors.fill: parent
        onClicked: {
            for(var item in root.data) {
                console.log(typeof(item.toString()))
            }
        }
    }

    Text {
        text: qsTr("Hello Qt Quick App")
        anchors.centerIn: parent
    }

    Rectangle {
        width: root.width * 0.5
        height: root.height * 0.5
        x: 0
        y: root.height * 0.5
        z: 0
        color: "red"
    }
}
