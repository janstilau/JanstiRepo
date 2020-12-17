import QtQuick 2.2
import QtQuick.Controls 1.2
// Window 没有在 Controls 模块下, 而是在 Window 模块下.
import QtQuick.Window 2.1

ApplicationWindow {

    width: 400; height: 400
    color: "gray"; opacity: 1.0
    x: 300; y: 300

    Window {
        id: dialog; title: "Dialog"
        width: 200; height: 200
        visible: true
        Label {
            width: parent.width;
            height: parent.height
            text: "This is a dialog."
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        onClosing: console.log("quit!");
    }

    Button {
        text: qsTr("Open"); anchors.centerIn: parent
        onClicked: { dialog.show(); }
    }
}
