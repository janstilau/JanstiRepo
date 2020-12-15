import QtQuick.Controls 1.2
import QtQuick 2.2

// 定义了一个叫做 Column 的对象类型, 里面是三个 CheckBox.
// 三个 CheckBox 是系统原生的类型. 通过组装系统原生类型, 自定义了自己的类型.dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
Column {
    CheckBox {
        text: qsTr("Breakfast")
    }
    CheckBox {
        text: qsTr("Lunch")
    }
    CheckBox {
        text: qsTr("Dinner")
    }
}
