import QtQuick 2.2

// 这里, 并不是定义 SquareButton, 而是使用 SquareButton 生成一个对象.
// QML 这里比较混乱, QML 文件的名称, 是新的类的名称.
// 文件内第一个出现的类名, 是根对象的类型名.


// SquareButton 和 MyApplication 是同一目录, 所以没有 import 的必要.

SquareButton {
    onActivated: console.log("Activated at "
                             + xPosition + "," + yPosition)
    onDeactivated: console.log("Deactivated!")
}


