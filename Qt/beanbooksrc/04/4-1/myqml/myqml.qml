


// 告知 QML 文档, 必须引入的模块, JS 的资源.
// QML 文档, 默认可以加载同目录的对象类型, 其他的就需要 import 导入.
// Import 并不会把代码复制到当前文档, 仅仅是告诉引擎, 如何处理相应的类型.


import QtQuick 2.2


// 对象树模型. {} 之前的大写字母开头的, 就是类型名.
// 这里不是一个类型的定义, 里面的代码, 就是对象的代码
// 类似于, xib 文档里面, 定义了 class 的值, 然后后面的 property 定义了各个属性的值, 然后, 解析程序会生成该类型的对象, 然后使用文档中的属性值对于这个对象的各个属性进行赋值操作.
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

    // 绑定, 使用其他对象或者属性的引用, 做某些属性的值
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


