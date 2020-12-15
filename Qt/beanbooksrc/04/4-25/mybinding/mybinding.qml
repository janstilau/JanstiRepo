import QtQuick 2.2

Item {
    width: 600; height: 600

    Rectangle {
        width: 10; height: width * 2
        color: "red"; anchors.centerIn: parent; focus: true
        Keys.onSpacePressed: height = width * 3

        // 由于 height: width * 2 这种属性绑定, 所以不断地点击, 改变 width, height 会随着更改
        // 但是 Keys.onSpacePressed 里面, 重新赋值为 height = width * 3, 之后的点击只会增加 width 的值, 而高度的值不在随着变化.
        MouseArea {
            anchors.fill: parent
            onClicked: parent.width += 10
        }
    }
}
