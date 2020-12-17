import QtQuick 2.2
import "factorial.js" as MathFunctions
// 这里, 导入了一个JS 文件, 然后命名为 MathFunctions

Item {
    MouseArea {
        anchors.fill: parent
//        onClicked: console.log(MathFunctions.factorial(10))
        onClicked: {
            console.log(MathFunctions.factorial(20))
        }
    }
}



