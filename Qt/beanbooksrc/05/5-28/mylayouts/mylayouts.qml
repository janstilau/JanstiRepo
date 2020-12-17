import QtQuick 2.2
import QtQuick.Layouts 1.1

Item {
    RowLayout {
        id: layout
        // 这个必须设置, 这样才能撑起整个空间.
        anchors.fill: parent
        spacing: 6
        Rectangle {
            color: 'green'
            // 这里的设置, 和 QLayout 没有太大的区别.
            Layout.fillWidth: true
            Layout.minimumWidth: 50
            Layout.preferredWidth: 100
            Layout.maximumWidth: 300
            Layout.minimumHeight: 150
            Text {
                anchors.centerIn: parent
                text: parent.width + 'x' + parent.height
            }
        }
        Rectangle {
            color: 'red'
            Layout.fillWidth: true
            Layout.minimumWidth: 100
            Layout.preferredWidth: 200
            Layout.preferredHeight: 100
            Text {
                anchors.centerIn: parent
                text: parent.width + 'x' + parent.height
            }
        }
    }
}

