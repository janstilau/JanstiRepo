import QtQuick 2.2

Item {
    width: 200; height: 200

    MouseArea {
        anchors.fill: parent
        onClicked: label.moveTo(mouse.x, mouse.y)
    }

    Text {
        id: label
        text: "Move me!"
        // JS 里面的参数, 没有类型.
        // 不过, QML 里面应该逻辑都比较简单, 不会有类型错传的机会发生.
        function moveTo(newX, newY) {
            label.x = newX;
            label.y = newY;
        }
    }
}

