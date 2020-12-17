import QtQuick 2.2

Item {
    width: 600; height: 600
    Rectangle {
        width: 10; height: width * 2
        color: "red";
        anchors.centerIn: parent;
        focus: true;

        // 先简单地理解, height: width * 2 会被内部, 增加一个 Qt.binding 的映射关系.
        Keys.onSpacePressed: height = Qt.binding( function() { return width * 3 } )
        MouseArea {
            anchors.fill: parent
            onClicked: parent.width += 10
        }
    }
}
