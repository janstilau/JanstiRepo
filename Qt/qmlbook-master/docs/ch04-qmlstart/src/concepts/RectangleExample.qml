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
        }
    }
}
// <<M1

