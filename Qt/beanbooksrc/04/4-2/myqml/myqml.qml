import QtQuick 2.2 as Quick
// import QtQuick 这句话, 导入了这个模块提供的所有的对象类型.
// 如果使用了一个没有导入的类型, 那么就会报错
// as Quick 使得, 想要使用 Rectangle 就得加上 Quick 的前缀才可以了.
// 用命名空间的概念去理解这件事.
// * 以上是模块导入的语法




Quick.Rectangle {
    width: 300
    height: 200
    color: "blue"
}


