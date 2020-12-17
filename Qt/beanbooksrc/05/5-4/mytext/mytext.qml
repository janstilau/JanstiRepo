import QtQuick 2.2

Column {
    Text {
        text: "Hello World!";
        font.family: "Helvetica";
        font.pointSize: 59;
        color: "red"
    }
    Text {
        // text 属性, 自动判断, 是否是富文本显示.
        // 这个控件, 有着自动大小计算的功能
        text: "<b>Hello</b> <i>World!</i>"
    }
}
