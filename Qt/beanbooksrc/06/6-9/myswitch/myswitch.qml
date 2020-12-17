import QtQuick 2.2
import QtQuick.Controls 1.2
import QtQuick.Window 2.1

ApplicationWindow {
    Column {
        Column {
            CheckBox {
                checked: true
                text: qsTr("First")
            }
            CheckBox {
                text: qsTr("Second")
            }
            CheckBox {
                checked: true
                text: qsTr("Third")
            }
        }
    }
}


