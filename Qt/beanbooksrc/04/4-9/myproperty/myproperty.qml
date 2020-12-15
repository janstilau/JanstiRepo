import QtQuick 2.2

Rectangle {
    // 右边的值, 要能够和左边的值类型匹配, 或者可以进行类型转化.
    // 使用静态值初始化
    width: 400
    height: 200
    color: "red" // QML 有着一系列的转化器, 可以将 string 转化成为对应的属性类型.
    Rectangle {
        // 使用绑定表达式初始化
        width: parent.width / 2
        height: parent.height
    }
}



