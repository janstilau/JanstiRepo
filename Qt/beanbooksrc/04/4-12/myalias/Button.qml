import QtQuick 2.2

Rectangle {
    property alias buttonText: textItem.text
    // 通过这种方式, 可以把构建在内部的子部件暴露出去. 这样, 就和常见的编程语言类似了.
    // 不然, 所有的子部件的属性, 都要父级进行中介, 父级对象的属性就太多了.
    property alias title: textItem
    width: 100; height: 30; color: "red"
    Text { id: textItem }
}

// 主要用途在于, 使用一个别名
// 属性别名, 必须在整个组件初始化完毕之后才可以使用.
/*
Rectangle {
    Button { buttonText: "click Me" }
}
*/

