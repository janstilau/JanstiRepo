import QtQuick 2.2

// SquareButton 和 MyApplication 是同一目录, 所以没有 import 的必要.

// 默认情况下, 不需要 connect 的这个过程, 直接使用良好的命名来解决问题.
SquareButton {
    onActivated: console.log("Activated at "
                             + xPosition + "," + yPosition)
    onDeactivated: console.log("Deactivated!")
}


