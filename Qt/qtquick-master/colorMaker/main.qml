import QtQuick 2.2
import QtQuick.Controls 1.4
//[1]
import an.qt.ColorMaker 1.0
Rectangle {

    width: 480;
        height: 320;
        visible: true;

        StackView {
            id: stack;
            anchors.centerIn: parent;
            width: 600;
            height: 300;
            clip: true;
            property var home: null;

            Text {
                text: "Click to create first page";
                font.pointSize: 14;
                font.bold: true;
                color: "blue";
                anchors.centerIn: parent;
                MouseArea {
                    anchors.fill: parent;
                    onClicked: if(stack.depth == 0)stack.push(page);
                }
            }
        }

        Component {
            id: page;

            Rectangle {
                color: Qt.rgba(stack.depth*0.1, stack.depth*0.2, stack.depth*0.3);

                Text {
                    anchors.centerIn: parent;
                    text: "depth - " + stack.depth;
                    font.pointSize: 24;
                    font.bold: true;
                    color: stack.depth <= 4 ? Qt.lighter(parent.color) : Qt.darker(parent.color);
                }

                Button {
                    id: next;
                    anchors.right: parent.right;
                    anchors.bottom: parent.bottom;
                    anchors.margins: 8;
                    text: "Next";
                    width: 70;
                    height: 30;
                    onClicked: {
                        if(stack.depth < 8) stack.push(page, {}, StackView.PopTransition);
                    }
                }

                Button {
                    id: back;
                    anchors.right: next.left;
                    anchors.top: next.top;
                    anchors.rightMargin: 8;
                    text: "Back";
                    width: 70;
                    height: 30;
                    onClicked: {
                        if(stack.depth > 0) stack.pop();
                    }
                }

                Button {
                    id: home;
                    anchors.right: back.left;
                    anchors.top: next.top;
                    anchors.rightMargin: 8;
                    text: "Home";
                    width: 70;
                    height: 30;
                    onClicked: {
                        if(stack.depth > 0)stack.pop(stack.initialItem);
                    }
                }

                Button {
                    id: clear;
                    anchors.right: home.left;
                    anchors.top: next.top;
                    anchors.rightMargin: 8;
                    text: "Clear";
                    width: 70;
                    height: 30;
                    onClicked: {
                        if(stack.depth > 0)stack.clear();
                    }
                }
            }
        }
}
