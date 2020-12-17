import QtQuick 2.2

Rectangle {
    id: relay

    signal messageReceived(string person, string notice)
    Handler {
        id: handler
    }

    Component.onCompleted: {
        relay.messageReceived.connect(sendToPost)
        relay.messageReceived.connect(sendToTelegraph)
        messageReceived.connect(sendToEmail)
        // 上面, 一个信号连接了三个槽函数.
        // 下面, 发射了这个信号.
        // 在方法内部, this 不是 handler 对象, 但是可以使用 id 引用到属性, 也可以直接使用到属性.
        relay.messageReceived.connect(handler.getText)
    }



    MouseArea {
        anchors.fill: parent
        onClicked: {
            messageReceived("Tom", "Happy Birthday")
            // 这块代码报错, readonly.
//            handler.getText =  function(former, latter){
//                console.log(former + latter + "new")
//            }
        }
    }

    function sendToPost(person, notice) {
        console.log("Sending to post: " + person + ", " + notice)
    }
    function sendToTelegraph(person, notice) {
        console.log("Sending to telegraph: " + person + ", " + notice)
    }
    function sendToEmail(person, notice) {
        console.log("Sending to email: " + person + ", " + notice)
    }
}


