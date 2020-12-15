import QtQuick 2.2

// 属性别名最大的用途, 可以是定义一个属性, 然后这个属性的 get, set 方法, 是操作它的一个成员的一个属性.
Rectangle {
    id: coloredrectangle
    property alias color: bluerectangle.color
    color: "red"

    Rectangle {
        id: bluerectangle
        color: "#1234ff"
    }

    Component.onCompleted: {
        console.log(coloredrectangle.color) // #1234ff
        console.log(color)
        setInternalColor()
        console.log(coloredrectangle.color) // #111111
        console.log(color)
        coloredrectangle.color = "#884646"
        console.log(coloredrectangle.color) // #884646\
        console.log(color)
    }

    // 内部函数访问内部属性
    function setInternalColor() {
        color = "#111111"
    }
}


