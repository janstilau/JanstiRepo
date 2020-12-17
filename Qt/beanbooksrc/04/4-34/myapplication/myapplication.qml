import QtQuick 2.2

// SquareButton 里面, 并没有 color 属性, 这个属性, 是 Rectangle 的.
// 从这个角度来看, QML 自定义的类型, 根对象的类型, 和自定义类型之前的关系, 更多的应该是继承, 而不是组合.

//SquareButton {
//    color: "blue"
//}

Rectangle {
    color: "green"
    InnerBtn {
        id: aBtn
        z:1
        color: "red"
        width: parent.width * 0.5;
        height: parent.height * 0.5
        Keys.onSpacePressed:  {
            console.log(this)
        }
    }

    MouseArea {
        anchors.fill: parent
        z:0
        onClicked:  {
            // 必须上层 MouseArea 设置为 propagateComposedEvents, 并且 mouse 事件, 设置为 not Accepted 才可以.
            console.log("Clicked")
        }
    }
}
