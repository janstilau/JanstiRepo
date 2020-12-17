import QtQuick 2.2
import QtQuick.Layouts 1.1
import QtQuick.Window 2.1

Window {
    RowLayout {
        id: layout
        anchors.fill: parent

        Item {
            id: leftMargin
            Layout.minimumWidth: 5
            Layout.maximumWidth: 5
        }

        Rectangle {
            color: 'green'
            Layout.fillWidth: true
            Layout.minimumWidth: 50
            Layout.preferredWidth: 100
            Layout.maximumWidth: 300
            Layout.minimumHeight: 150
        }

        Item {
            id: rightMargin
            Layout.minimumWidth: 5
            Layout.maximumWidth: 5
        }
    }
}


