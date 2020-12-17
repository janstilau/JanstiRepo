import QtQuick 2.4

HandlerForm {
    // relay.messageReceived.connect(handler.getText)
    // 上面的连接可以通过, 这么看来, func 天然就是一个 property. 这是一个 readonly, 如果赋值的话会报错的.
    function getText(firstTxt, secondTxt) {
        console.log( "handler: " + firstTxt + secondTxt)
        console.log(this)
        console.log(age)
    }

    property int age: 200
    id: handlerItem
}
