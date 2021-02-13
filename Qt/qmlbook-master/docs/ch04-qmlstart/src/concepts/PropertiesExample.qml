// properties.qml

import QtQuick 2.5

Rectangle {
    width: 240
    height: 120

    Text {
        // (1) identifier
        id: thisLabel

        // (2) set x- and y-position
        x: 24; y: 16

        // (3) bind height to 2 * width
        height: 2 * width

        // (4) custom property
        property int times: 24

        // (5) property alias
        property alias anotherTimes: thisLabel.times

        // (6) set text appended by value
        text: "Greetings " + times

        // (7) font is a grouped property
        font.family: "Ubuntu"
        font.pixelSize: 24

        // (8) KeyNavigation is an attached property
        KeyNavigation.tab: otherLabel

        // (9) signal handler for property changes
        // 最好, 统一的用 {} 进行包裹, 这样以后要修改的话, 也能够方便.
        // 再者,项目里面统一的用 {} 进行提示, 这是代码调用, 不是 property 设置.
        onHeightChanged: console.log('height:', height)

        // focus is need to receive key events
        focus: true

        // change color based on focus value
        color: focus?"red":"black"
    }
    // <<M1


    Text {
        // (1) identifier
        id: otherLabel
        x: 24
        y: 64
        text: "Other Label"

        // (6) font is a grouped property
        font.family: "Ubuntu"
        font.pixelSize: 24

        // (7) Keys is a attached property
        // 点击 tab 的下一个 focus 的对象.
        KeyNavigation.tab: thisLabel
        color: focus?"red":"black"
    }
}
