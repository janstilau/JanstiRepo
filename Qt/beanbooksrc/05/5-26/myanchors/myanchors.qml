import QtQuick 2.2

Item {
    Rectangle{
        id: rect1
        width: 50; height: 50; color: "blue"
    }
    Rectangle{
        id: rect2
        width: 50; height: 50; color: "red"

        // 使用 anchors 可以实现, 类似于 autolayout 的效果.
        anchors.left: rect1.right
        anchors.top: rect1.bottom
    }
}
