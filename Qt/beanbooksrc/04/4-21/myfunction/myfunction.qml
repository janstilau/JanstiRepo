import QtQuick 2.2

Item {
    id: root
    width: 200; height: 200

    MouseArea {
        anchors.fill: parent
        onClicked: label.move(mouse.x, mouse.y)
    }

    Text {
        id: label
        text: "Move me!"
        function move(newX, newY) {
            console.log(root)

            console.log(label)
            console.log(this)
            console.log(this === label)
            moveTo(newX, newY)
        }

        // JS 里面的参数, 没有类型.
        // 由于对于 JS 里面, 函数内 this 不是很熟悉, 函数内统一用 id 进行索引.
        function moveTo(newX, newY) {
            label.x = newX;
            label.y = newY;
            console.log(label)
            console.log(this)
            console.log(this === label)
        }
    }
}

