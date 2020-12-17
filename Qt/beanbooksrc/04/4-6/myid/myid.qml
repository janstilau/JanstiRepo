import QtQuick 2.2

// 一个 id 在一个组件的作用域里必须是唯一的, 从下面看出, 子作用域没有太大作用.
// 实验也证明了, 在第二个 Text 里面设置的 id, 和第一个 Text 里面的重复了, 那么编译就通不过.
// 把 id 当做成员变量名来看待.

// 属性, 可以算作是 QML 类型里面的成员变量定义, public

Row {

    Text {
        id: text1
        text: "Hello World"
    }

    // 使用了 text1 的 text 初始化了 第二个 Text 的 text 属性.
    Text {
//        id: text1
        text: text1.text + "Another"
    }
}


