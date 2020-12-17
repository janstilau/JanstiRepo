// 告知 QML 文档, 必须引入的模块, JS 的资源.
// QML 文档, 默认可以加载同目录的对象类型, 其他的就需要 import 导入.
// Import 并不会把代码复制到当前文档, 仅仅是告诉引擎, 如何处理相应的类型.


// Rectangle, Img 都是 QtQuick 里面的部件, Item 也是 QtQuick 里面的部件.
import QtQuick 2.2

// QML 文档, 是把类的定义, 也就是成员变量, property 的定义 + 方法函数
// 类的初始化, 就是各种原有属性的赋值, 以及各个子控件的添加
// 放到了一个地方. 这样, 初始化的过程里面, 直接使用了定义好的方法. 可能会有些混乱, 但是更符合描述性语言的特色


Rectangle {

    // Rectangle 的属性定义
    width: 400
    height: 400
    color: "yellow"

    Image {
        source: "pics/logo.png"
        anchors.centerIn: parent
    }

    Text {
        text:"Hello world!"
        font.family: "Helvetica"
        font.pointSize:  24
    }

    // 只要使用了其他的属性, 或者其他对象的属性, 放到对应的表达式里面, 就形成了绑定. 当表达式的值改变的时候, 左值会跟着改变.
    // 先用 oc 的 kvo 来进行理解吧.
    Rectangle {
        id: topRect
        width: parent.width * 0.5
        height: parent.height * 0.5
        color: "red"
        anchors.bottom: parent
    }

    MouseArea {
        anchors.fill: parent
        onClicked: console.log(topRect.color)
    }
}


