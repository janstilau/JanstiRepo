import QtQuick 2.5

// The root element is the Rectangle
Rectangle {
    // name this element root. 这里就说的很明白, id 就是命名.
    id: root

    // properties: <name>: <value>
    width: 120; height: 240

    // color property
    color: "#4A4A4A"

    // Declare a nested element (child of root)
    // 声明就是定义.
    Image {
        id: triangle

        // reference the parent
        x: (parent.width - width)/2; y: 40

        source: 'assets/triangle_red.png'

        Rectangle {
            border.width: 1
            border.color: "red"
            anchors.fill: parent
            z:-1
        }
    }

    // Another child of root
    Text {
        // un-named element, 没有 id, 就是没有命名.
        id: textId

        // reference element by id
        y: triangle.y + triangle.height + 20

        // reference root element
        width: root.width

        color: 'green'
        horizontalAlignment: Text.AlignHCenter
        text: 'Triangle'

        Rectangle {
            border.width: 1
            border.color: "red"
            anchors.fill: parent
            z:-1
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    parent.destroy()
                }
            }
        }
    }

    /*
A Component definition contains a single top level item (which in the above example is a Rectangle) and cannot define any data outside of this item, with the exception of an id (which in the above example is redSquare).
Component 里面定义一个 Item, 和在文件里面定义一个 Item 没有区别.
Component 只会有两个元素, id, 这个 id 是指明这个 Component 的, 就像文件里面定义的 Item 是用文件名来指代.
一个顶层 Item. 这个顶层 Item, 就是这个 Component 里面的数据.
使用 Component 的时候,使用 id 来引用到这个 Component, 而实际上, 会生成 Component 所定义的顶层 Item.
      */

    Component {
        id: block
        Rectangle {
            color: red
            border.width: 2
            border.color: "lightgreen"
            width: 200
            height: 100
            y: 100 * index + 20 * (index - 1)
        }
    }

    Repeater {
        anchors.top: textId.anchors.bottom
        model: 10
        delegate: block
    }
}
// <<M1

