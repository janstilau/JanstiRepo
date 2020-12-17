import QtQuick 2.2


// 声明一个自定义的属性, 会隐式地为该属性, 增加一个值改变信号, 并且增加一个相应的 onPropertyNameChanged 的槽处理函数.
// 这个信号, 会在属性的值改变的时候触发, 槽函数, 需要在对象定义的时候, 由类的使用者来指定值.
Rectangle {
    // 这里, 仅仅是定义了属性, 但是属性的初始值还没有确认.
    property color previousColor
    property color nextColor
    // 在最新的版本里面, 可以在后面增加默认值了.
    property int value: 1

    property var someNumber: 1.5
    property var list: [1, 2, 3, 4, 5]
    // 如果在本类里面, 定义了 onNextColorChanged 函数, 在使用该类的 qml 里面, 也定义了 onNextColorChanged. 那么先会调用本类的, 然后定义外部定义的.
    onNextColorChanged: {
        console.log("The next color will be: " + nextColor.toString())
        color = nextColor
        console.log(typeof(someNumber))
        console.log(typeof(list))
    }

    nextColor: "red" // 这里, 增加了属性的值的确认.
    MouseArea {
        anchors.fill:parent
        onClicked: {
            if (value == 1) {
                nextColor = "yellow"
                value = 0
            } else {
                nextColor = "red"
                value = 1
            }
        }

    }
}

