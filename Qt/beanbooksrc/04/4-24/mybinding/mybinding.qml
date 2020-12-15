import QtQuick 2.2

Rectangle {
    width: 200; height: 200

    // 当表达式的值改变的时候, 对应的属性会获取新的值.
    // 应该这样讲, 表达值会重新进行计算.
    // 只要表达式, 是合法的 JS 语句就可以.
    // 不要过分的使用绑定的机制.
    Rectangle {
        width: 100; height: parent.height
        color: "blue"
    }
}


