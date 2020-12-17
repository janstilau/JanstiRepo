import QtQuick 2.2

Row {
    Text {
        // 点标记
        font.pixelSize: 12
        font.bold: true
        text: "text1"
    }
    Text {
        // 组标记, 就算是组标记, 也应该按照良好的代码格式进行书写.
        // font : Font {}, 不能用这种类型进行创建.
        font  {
            pixelSize: 12;
            bold: true
        }
        text: "text2"
    }
}

