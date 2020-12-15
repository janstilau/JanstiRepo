import QtQuick 2.2

Rectangle {
    id: root

    // 自定义的信号, 对于这种自定义的信号, 需要主动在代码里面触发才可以.
    // QML 的这种写法, 就使得对应的槽函数, 就写到空间的初始化过程里面了.
    // 在初始化的时候, 进行相关对象的所有创建工作.
    signal activated(real xPosition, real yPosition)
    signal deactivated

    width: 100; height: 100

    MouseArea {
        anchors.fill: parent
        onPressed: root.activated(mouse.x, mouse.y) // 在 MouseArea 的信号处理函数里面, 主动发送自定义的信号.
        onReleased: root.deactivated()
    }
}
