import QtQuick 2.2

// QML 提供了内建的属性值改变信号. 当属性改变之后, 对应的信号就会发出.
Rectangle {
    id: rect
    width: 100; height: 100

    // MouseArea 后面的 {} 内, 其实就是定制化的过程. 这个过程, 变为代码就是生产对象, 属性设置, connect 的过程.
    // 所以, 把回调写到这里面, 倒也是合理的.
    // 一定需要注意的是, 这是定制化的过程, 而不是定义的过程.
    MouseArea {
        anchors.fill: parent
        onClicked: {
            rect.color = Qt.rgba(Math.random(),
                                 Math.random(),
                                 Math.random(),
                                 1);
        }
    }
}

