import QtQuick 2.2
import QtQuick.Controls 1.2
import QtQuick.Window 2.1

ApplicationWindow {
    Button {
        x: 10; y: 10; width: 140
        text: qsTr("Button with Menu")
        onClicked: {
            console.log()
        }
    }
}

