// ScriptingExample.qml

import QtQuick 2.5

Rectangle {
    width: 240
    height: 120

    // M1>>
    Text {
        id: label

        x: 24; y: 24

        // custom counter property for space presses
        // 一个自定义的成员变量
        // 这并不是一个根对象, 也可以在里面增加属性. 只要逻辑自洽就可以了.
        // 这个小控件, 仅仅是在这个 QML 内部使用, 不会进行输出.
        // 相当于一个内部类. 继承自 Text.
        property int spacePresses: 0

        text: "Space pressed: " + spacePresses + " times"

        // (1) handler for text changes
        onTextChanged: console.log("text changed to:", text)

        // need focus to receive key events
        focus: true

        // (2) handler with some JS
        Keys.onSpacePressed: {
            increment()
        }

        // clear the text on escape
        Keys.onEscapePressed: {
            label.text = '' // 这里, 打断了 binding.
        }

        // (3) a JS function
        function increment() {
            //  spacePresses 改变了, text 也就跟着改变, text 改变了, 槽函数就会触发.
            spacePresses = spacePresses + 1
        }
    }
    // <<M1
}
