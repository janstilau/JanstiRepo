import QtQuick 2.2

// 这个语法没太明白.
ListView {
    width: 240;
    height: 320;
    model: 20;
    focus: true
    delegate: Rectangle {
        width: 240; height: 30
        color: ListView.isCurrentItem ? "red" : "yellow"
        border.width: 1
        border.color: "black"
    }
}


