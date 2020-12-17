import QtQuick 2.2

Column {
    Text {
        // 默认 auto, 会根据内容自动进行设置正确的格式.
        font.pointSize: 24
        text: "<b>Hello</b> <i>World!</i>"
    }
    Text {
        font.pointSize: 24; textFormat: Text.RichText
        text: "<b>Hello</b> <i>World!</i>"
    }
    Text {
        font.pointSize: 24; textFormat: Text.PlainText
        text: "<b>Hello</b> <i>World!</i>"
    }
}

