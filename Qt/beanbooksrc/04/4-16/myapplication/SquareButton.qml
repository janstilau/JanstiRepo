import QtQuick 2.2

// 文件名, 才是 QML 文档的真正类名, 这是一定要注意的问题.
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
        // pressed, released 信号, 什么时候发射是在 MouseArea 类内部定义的, 而他的处理函数, 是在对象的定制化过程中写明的.
        onPressed: root.activated(mouse.x, mouse.y)
        onReleased: root.deactivated()
        // 没有了 QWidget 里面, emit 这种装饰, 直接就是函数调用.
    }
}
