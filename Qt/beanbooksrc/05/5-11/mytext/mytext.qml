import QtQuick 2.2

Item {
    width: 400
    height: 100
    Rectangle {
        color: "red"
        Text {
            textFormat: Text.RichText
            font.pointSize: 24
            text: "欢迎访问<a href=\"http://qter.org\">Qter开源社区</a>"
            onLinkActivated: {
                // 通过这个, 可以做回调处理.
                console.log(link + " link activated");
            }
        }
    }
}

