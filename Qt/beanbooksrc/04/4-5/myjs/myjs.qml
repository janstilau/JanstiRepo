import QtQuick 2.2

Item {
    // 使用了 var 类型, 进行了 JS 类型的存储.
    property var theArray: new Array()
    property var theDate: new Date()

    // Component.onCompleted 这个到底怎么回事.
    Component.onCompleted: {
        for (var i = 0; i < 10; i++) {
            theArray.push("Item " + i)
        }
        console.log("There are", theArray.length, "items in the array")
        console.log("The time is", theDate.toUTCString())
    }
}

