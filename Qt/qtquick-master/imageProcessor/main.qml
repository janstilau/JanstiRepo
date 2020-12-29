import QtQuick 2.2
import QtQuick.Controls 1.1
import QtQuick.Dialogs 1.1
import an.qt.ImageProcessor 1.0
import QtQuick.Controls.Styles 1.1

Rectangle {
    width: 640;
    height: 480;
    color: "lightgreen";

    // loading
    BusyIndicator {
        id: busy;
        running: false;
        anchors.centerIn: parent;
        z: 2;
    }

    // 提示文本
    Label {
        id: stateLabel;
        visible: false;
        anchors.centerIn: parent;
    }

    Image {
        objectName: "imageViewer";
        id: imageViewer;
        asynchronous: true;
        anchors.fill: parent;
        fillMode: Image.PreserveAspectFit;
        onStatusChanged: {
            if (imageViewer.status === Image.Loading) {
                busy.running = true;
                stateLabel.visible = false;
            }
            else if(imageViewer.status === Image.Ready){
                busy.running = false;
            }
            else if(imageViewer.status === Image.Error){
                busy.running = false;
                stateLabel.visible = true;
                stateLabel.text = "ERROR";
            }
        }
    }

    // 在这里, 注册了一个图像处理器.
    ImageProcessor {
        id: processor;
        onFinished: {
            // 在这里, 进行了图像处理的回调.
            imageViewer.source = "file:///" +newFile;
        }
    }

    FileDialog {
        id: fileDialog;
        title: "Please choose a file";
        nameFilters: ["Image Files (*.jpg *.png *.gif)"];
        onAccepted: {
            console.log(this)
            console.log(fileDialog.fileUrl);
            imageViewer.source = fileDialog.fileUrl;
        }
    }

    Component{
        id: btnStyle;
        ButtonStyle {
            background: Rectangle {
                implicitWidth: 70;
                implicitHeight: 25;
                border.width: control.pressed ? 2 : 1;
                border.color: (control.pressed || control.hovered) ? "#00A060" : "#888888";
                radius: 6;
                gradient: Gradient {
                    GradientStop { position: 0 ; color: control.pressed ? "#cccccc" : "#e0e0e0"; }
                    GradientStop { position: 1 ; color: control.pressed ? "#aaa" : "#ccc"; }
                }
            }
        }
    }

    Button {
        id: openFile;
        text: "打开";
        anchors.left:  parent.left;
        anchors.leftMargin: 6;
        anchors.top: parent.top;
        anchors.topMargin: 6;
        onClicked: {
            fileDialog.visible = true;
            // 只能是通过 QML 的方式生成, 不能通过 new 的方式生成一个 fileDialog
//            console.log(typeof(FileDialog))
//            var getFile = new FileDialog
//            getFile.title = "请获取图片"
//            getFile.nameFilters = ["Image Files (*.jpg *.png *.gif)"]
//            getFile.onAccepted = function() {
//                console.log(fileDialog.fileUrl);
//                imageViewer.source = fileDialog.fileUrl;
//            }
        }
        style: btnStyle;
        z: 1;
    }

    Button {
        id: quit;
        text: "退出";
        anchors.left: openFile.right;
        anchors.leftMargin: 4;
        anchors.bottom: openFile.bottom;
        onClicked: {
            Qt.quit()
        }
        style: btnStyle;
        z: 1;
    }

    Rectangle {
        id: topContainer
        anchors.left: parent.left;
        anchors.top: parent.top;
        anchors.bottom: openFile.bottom;
        anchors.bottomMargin: -6;
        anchors.right: quit.right;
        anchors.rightMargin: -6;
        color: "gray"
        opacity: 0.7;
    }



    Grid {
        id: op;
        anchors.left: parent.left;
        anchors.leftMargin: 4;
        anchors.bottom: parent.bottom;
        anchors.bottomMargin: 4;

        rows: 2;
        columns: 3;

        rowSpacing: 4;
        columnSpacing: 4;
        z: 1;

        // 不同的按钮, 绑定不同的事件.
        Button {
            text: "柔化";
            style: btnStyle;
            onClicked: {
                busy.running = true;
                processor.process(fileDialog.fileUrl, ImageProcessor.Soften);
            }
        }

        Button {
            text: "灰度";
            style: btnStyle;
            onClicked: {
                busy.running = true;
                processor.process(fileDialog.fileUrl, ImageProcessor.Gray);
            }
        }

        Button {
            text: "浮雕";
            style: btnStyle;
            onClicked: {
                busy.running = true;
                processor.process(fileDialog.fileUrl, ImageProcessor.Emboss);
            }
        }
        Button {
            text: "黑白";
            style: btnStyle;
            onClicked: {
                busy.running = true;
                processor.process(fileDialog.fileUrl, ImageProcessor.Binarize);
            }
        }

        Button {
            text: "底片";
            style: btnStyle;
            onClicked: {
                busy.running = true;
                processor.process(fileDialog.fileUrl, ImageProcessor.Negative);
            }
        }

        Button {
            text: "锐化";
            style: btnStyle;
            onClicked: {
                busy.running = true;
                processor.process(fileDialog.fileUrl, ImageProcessor.Sharpen);
            }
        }
    }

    Rectangle {
        id: bottomContainer
        anchors.left: parent.left;
        anchors.top: op.top;
        anchors.topMargin: -4;
        anchors.bottom: parent.bottom;
        anchors.right: op.right;
        anchors.rightMargin: -4;
        color: "lightblue";

        opacity: 0.7;
    }
}