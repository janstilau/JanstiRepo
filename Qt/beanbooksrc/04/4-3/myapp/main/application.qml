import "../mycomponents"
// 这句话, 就使得当前的 QML 文档, 可以使用 mycomponents 中定义的各个组件了.

DialogBox {
    CheckBox {
        // ...
    }
    Slider {
        x: 10; y:100
        // ...
    }
}


