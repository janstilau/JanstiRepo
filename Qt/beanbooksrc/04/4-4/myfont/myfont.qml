import QtQuick 2.2

Text {
    onFontChanged: console.log("font changed")
    text: "hello Qt!"
    focus: true

    Text { id: otherText } // 定义了一个成员变量, otherText, 不显示, 仅仅做下面操作的引用存在.

    // 下面的操作都会调用onFontChanged信号处理器
    // 基本数据类型, 可以当做值类型来看, 当他的属性发生了改变的时候, 整个值都会被替换, 然后, 会触发上面的改变信号.
    Keys.onDigit1Pressed: font.pixelSize += 1
    Keys.onDigit2Pressed: font.italic = !font.italic
    Keys.onDigit3Pressed: font = otherText.font
}

