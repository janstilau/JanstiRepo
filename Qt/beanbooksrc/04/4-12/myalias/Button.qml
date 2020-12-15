import QtQuick 2.2

Rectangle {
    property alias buttonText: textItem.text
    width: 100; height: 30; color: "yellow"
    Text { id: textItem }
}

// 这里, 将 textItem 的 text 当做了 buttonText 进行输出, 然后外界使用的时候, 直接赋值 buttonText 也就是改变了 textItem 里面的 text 的值.
// 属性别名, 必须在整个组件初始化完毕之后才可以使用.
/*
Rectangle {
    Button { buttonText: "click Me" }
}
*/

