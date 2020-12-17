import QtQuick 2.2

Item {
    width: 100
    height: 50
    TextInput {
        validator: IntValidator{ bottom: 11; top: 9999999; }
        focus: true

        Rectangle {
            color: "red"
            z:0
            anchors.fill: parent
            border.width: 2
        }
    }
}
