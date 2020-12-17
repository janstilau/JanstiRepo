import QtQuick 2.0
import QtQuick.Controls 2.4
import QtQuick.Dialogs 1.2

ApplicationWindow {

    // ...

    // 可以在 QML 里面写逻辑. 没有问题.
    // 这两个方法, 是写出去给别人用的.
    function openFileDialog() { fileOpenDialog.open(); }
    function openAboutDialog() { aboutDialog.open(); }

    visible: true
    title: qsTr("Image Viewer")

    background: Rectangle {
        color: "darkGray"
    }

    Image {
        id: image
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }

    FileDialog {
        id: fileOpenDialog

        // ...

        title: "Select an image file"
        folder: shortcuts.documents
        nameFilters: [ "Image files (*.png *.jpeg *.jpg)" ]
        onAccepted: { // 在回调里面, 进行图片路径的绑定
            image.source = fileOpenDialog.fileUrl;
        }
    }

    Dialog {
        id: aboutDialog

        // ...

        title: qsTr("About")
        standardButtons: StandardButton.Ok

        Label {
            anchors.fill: parent
            text: qsTr("QML Image Viewer\nA part of the QmlBook\nhttp://qmlbook.org")
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // ...

}
